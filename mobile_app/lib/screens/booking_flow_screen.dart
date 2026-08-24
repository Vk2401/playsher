import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../models/ground_sport_model.dart';
import '../models/slot_model.dart';
import '../providers/auth_provider.dart';
import '../providers/grounds_provider.dart';
import '../widgets/sport_glyph.dart';
import '../widgets/sticky_bottom_bar.dart';

class BookingFlowScreen extends ConsumerStatefulWidget {
  final int groundId;
  final Map<String, dynamic> extra;

  const BookingFlowScreen({
    super.key,
    required this.groundId,
    required this.extra,
  });

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  bool _loading = false;
  String? _error;
  String _paymentMethod = 'pay_at_ground'; // 'pay_at_ground' or 'online'
  late Razorpay _razorpay;

  GroundSportModel? get _groundSport =>
      widget.extra['groundSport'] as GroundSportModel?;
  String get _date => widget.extra['date'] as String? ?? '';
  List<int> get _slotIds =>
      (widget.extra['slotIds'] as List?)?.cast<int>() ?? [];
  int get _totalPrice => widget.extra['totalPrice'] as int? ?? 0;

  /// The venue's per-slot price, carried through from the detail screen.
  double get _pricePerSlot =>
      (widget.extra['pricePerSlot'] as num?)?.toDouble() ?? 0;

  /// Share of the total taken online when paying at the ground. Mirrors
  /// backend-api/src/utils/pricing.js; the server remains the authority and
  /// recomputes it on create, this only makes the CTA honest before the tap.
  static const _advanceRate = 0.10;
  static const _minAdvance = 10;

  bool get _isOnline => _paymentMethod == 'online';

  /// What the gateway charges now.
  int get _payableNow {
    if (_isOnline) return _totalPrice;
    if (_totalPrice <= 0) return 0;
    final tenth = (_totalPrice * _advanceRate).ceil();
    return tenth < _minAdvance
        ? (_minAdvance > _totalPrice ? _totalPrice : _minAdvance)
        : tenth;
  }

  /// What is collected at the venue.
  int get _balanceAtGround => _isOnline ? 0 : _totalPrice - _payableNow;
  String? get _groundName => widget.extra['groundName'] as String?;
  String? get _groundLocality => widget.extra['groundLocality'] as String?;
  String? get _groundImage => widget.extra['groundImage'] as String?;

  /// The slots this booking covers, resolved from the same provider the picker
  /// used. Watched rather than passed through `extra` so the times survive a
  /// rebuild and the screen never has to be handed data it can look up.
  List<SlotModel> get _selectedSlots {
    final gs = _groundSport;
    if (gs == null || _date.isEmpty) return const [];
    final all = ref
        .watch(slotsProvider(SlotQuery(groundSportId: gs.id, date: _date)))
        .valueOrNull;
    if (all == null) return const [];

    final chosen = all.where((s) => _slotIds.contains(s.id)).toList()
      ..sort((a, b) => a.slotStartTime.compareTo(b.slotStartTime));
    return chosen;
  }

  /// "6:30 PM - 7:30 PM" across every selected slot, or null until they load.
  String? get _selectedTimeRange {
    final slots = _selectedSlots;
    if (slots.isEmpty) return null;
    return '${slots.first.formattedStart} - ${slots.last.formattedEnd}';
  }

  String? get _selectedDuration {
    final slots = _selectedSlots;
    if (slots.isEmpty) return null;
    final total = slots.length * 30;
    final hours = total ~/ 60;
    final mins = total % 60;
    if (hours == 0) return '$mins mins';
    if (mins == 0) return '$hours hr${hours == 1 ? '' : 's'}';
    return '$hours hr${hours == 1 ? '' : 's'} $mins mins';
  }

  /// "Thu, 20 Aug 2026" — the raw ISO date was being shown to the user.
  String get _formattedDate {
    final d = DateTime.tryParse(_date);
    if (d == null) return _date;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Fields the confirmation screen needs that the API's booking row does not
  /// carry. Merged over the row so the screen never has to guess at aliases.
  Map<String, dynamic> get _displayFields => {
        if (_groundName != null) 'ground_name': _groundName,
        if (_groundSport?.sport?.name != null)
          'sport_name': _groundSport!.sport!.name,
      };

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _holdTicker?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  // ── Pending-attempt state ─────────────────────────────────────────────────
  // A booking is created once, then paid for — possibly across several
  // attempts. Holding the created booking here is what makes a retry *resume*
  // that booking rather than create another one for the same slots.
  Map<String, dynamic>? _pendingBookingResult;
  int? _pendingBookingId;

  /// Server-side deadline for the slot hold on a pending online booking.
  /// Taken from the create response, never computed here: the device clock can
  /// be minutes off, and the server is the one that will reclaim the slots.
  DateTime? _holdExpiresAt;
  Timer? _holdTicker;

  Duration? get _holdRemaining {
    final deadline = _holdExpiresAt;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get _holdLapsed =>
      _holdExpiresAt != null && _holdRemaining == Duration.zero;

  /// Shown once and only once when the hold runs out.
  bool _expiryAnnounced = false;

  /// The slots are gone — the server released them. Anything the user does on
  /// this screen now would fail, so block it outright and send them back to
  /// pick again rather than leaving a dead Pay button on screen.
  Future<void> _announceExpiry() async {
    if (_expiryAnnounced || !mounted) return;
    _expiryAnnounced = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        // Back must not dismiss it either: there is nothing behind it to use.
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.timer_off_rounded,
              size: 34, color: AppColors.error),
          title: const Text('Session expired'),
          content: const Text(
            'Your slots were only held for 5 minutes and have been released '
            'so others can book them.\n\nPick your slots again to continue.',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Book again'),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    // Back to the ground so the slot grid reloads with current availability.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/grounds/${widget.groundId}');
    }
  }

  void _startHoldTicker(DateTime deadline) {
    _holdTicker?.cancel();
    setState(() => _holdExpiresAt = deadline);
    _holdTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (_holdRemaining == Duration.zero) {
        timer.cancel();
        _announceExpiry();
      }
    });
  }

  /// True once a booking exists server-side for this attempt.
  bool get _hasPendingBooking => _pendingBookingResult != null;

  Future<void> _confirmBooking() async {
    // The CTA is disabled while loading, but guard re-entry here too: this is
    // the path that creates a booking and takes a payment, and a second call
    // in flight would double-book the slot.
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = ref.read(authProvider).user;

    try {
      // Step 1: Create the booking — but only once. A previous attempt that
      // reached Razorpay and failed there already holds a booking for these
      // slots; creating another would double-book the player against their
      // own orphaned attempt and surface as "slots already booked".
      final Map<String, dynamic> result;
      if (_pendingBookingResult != null) {
        result = _pendingBookingResult!;
      } else {
        final groundSportId = _groundSport?.id ?? widget.groundId;
        final rawResult = await ApiClient.createBooking(
          groundSportId: groundSportId,
          slotDate: _date,
          slotIds: _slotIds,
          paymentMethod:
              _paymentMethod == 'online' ? 'online' : 'pay_at_ground',
        );

        if (!mounted) return;

        // playsher-api wraps response: { success, data: { id, requires_payment, ... } }
        result = rawResult['data'] as Map<String, dynamic>? ?? rawResult;
      }

      // Step 2: If pay at ground, go directly to confirmation
      if (_paymentMethod == 'pay_at_ground') {
        context.go('/booking-confirm', extra: {
          ...result,
          ..._displayFields,
          'payment_method': 'Pay at Ground',
        });
        return;
      }

      // Step 3: Online payment — create Razorpay order
      final requiresPayment = result['requires_payment'] == true;
      final bookingId = result['id'];

      if (!requiresPayment || bookingId == null) {
        // Booking was created but doesn't need payment (unlikely path)
        context.go('/booking-confirm', extra: {
          ...result,
          ..._displayFields,
          'payment_method': 'Online',
        });
        return;
      }

      // Remember the attempt so a retry resumes it instead of re-booking.
      _pendingBookingResult = result;
      final holdRaw = result['hold_expires_at']?.toString();
      final hold =
          holdRaw == null ? null : DateTime.tryParse(holdRaw)?.toLocal();
      if (hold != null) _startHoldTicker(hold);
      _pendingBookingId =
          bookingId is int ? bookingId : int.tryParse(bookingId.toString());

      // Step 4: Create a Razorpay order for the pending booking. On a retry
      // this runs again against the *same* booking id, which is the point:
      // a fresh order against an existing booking, not a fresh booking.
      final payableBookingId = _pendingBookingId;
      if (payableBookingId == null) {
        throw StateError('Booking was created without a usable id');
      }
      final rawOrder = await ApiClient.createRazorpayOrder(payableBookingId);

      if (!mounted) return;

      // playsher-api wraps: { success, data: { order_id, amount, currency, key_id, payment_id } }
      final orderData = rawOrder['data'] as Map<String, dynamic>? ?? rawOrder;
      final orderId = orderData['order_id'] as String;
      final amountInPaise = orderData['amount'];
      final keyId =
          orderData['key_id'] as String? ?? AppConstants.razorpayKeyId;

      // Step 5: Open Razorpay checkout
      _razorpay.open({
        'key': keyId,
        'amount': amountInPaise,
        'currency': 'INR',
        'order_id': orderId,
        'name': AppConstants.appName,
        'description':
            '${_groundSport?.sport?.name ?? 'Sport'} Booking - ${_slotIds.length} slot${_slotIds.length > 1 ? 's' : ''}',
        // The player verified this mobile via OTP to get here; making them
        // retype it into Razorpay's sheet is pure friction.
        'prefill': {
          'contact': user?.mobile ?? '',
          'email': user?.email ?? '',
          'name': user?.name ?? '',
        },
        'theme': {
          'color': AppColors.primaryHex,
        },
        'modal': {
          'confirm_close': true,
        },
      });

      // Loading stays true — Razorpay callbacks will handle the rest
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _parseError(e);
          _loading = false;
        });
      }
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;

    try {
      // Verify payment with backend (playsher-api)
      final verifyResult = await ApiClient.verifyRazorpayPayment(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );

      if (!mounted) return;

      final verifyData = verifyResult['data'] as Map<String, dynamic>? ?? {};
      context.go('/booking-confirm', extra: {
        ...?_pendingBookingResult,
        ...?verifyData['booking'] as Map<String, dynamic>?,
        ..._displayFields,
        'payment_method': 'Online',
        'razorpay_payment_id': response.paymentId,
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Payment was successful but verification failed. Contact support.';
          _loading = false;
        });
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _error = response.message ?? 'Payment failed. Please try again.';
      _loading = false;
    });
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // The wallet app takes over from here and Razorpay reports the outcome
    // through the success/error callbacks. If it never does, the screen would
    // otherwise sit on a non-cancelable loader forever, so hand control back
    // and tell the player where the payment stands.
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error =
          'Complete the payment in ${response.walletName ?? 'your wallet app'}, '
          'then check My Bookings to confirm it went through.';
    });
  }

  /// Back from the booking screen.
  ///
  /// Back used to be disabled outright whenever `_loading` was set — which is
  /// most of the payment flow — so it read as "back does nothing". Leaving is
  /// safe now that an unpaid booking's slots are held on a deadline rather than
  /// forever, so back always works; it only asks first when a payment is
  /// genuinely in flight.
  Future<void> _handleBack() async {
    if (!_loading) {
      context.pop();
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave payment?'),
        content: Text(
          _hasPendingBooking
              ? 'Your slots stay held for a few more minutes. You can come back '
                  'and finish paying from My Bookings.'
              : 'Your booking has not been created yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (leave == true && mounted) context.pop();
  }

  static String _formatHold(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _parseError(Object e) {
    final msg = apiErrorMessage(e);
    final lower = msg.toLowerCase();
    if (lower.contains('already booked')) {
      return 'One or more slots are already booked.';
    }
    if (lower.contains('inactive')) {
      return 'This ground is currently inactive.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gs = _groundSport;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _handleBack,
        ),
        title: const Text(
          'Confirm Booking',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          // The countdown that matters most lives where the eye already is on
          // the way in — the banner further down repeats it for the moment
          // attention has moved to the payment method instead.
          if (_holdRemaining != null && !_holdLapsed)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _HoldPill(remaining: _formatHold(_holdRemaining!)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            _SummaryCard(
              groundSport: gs,
              date: _formattedDate,
              slotCount: _slotIds.length,
              totalPrice: _totalPrice,
              pricePerSlot: _pricePerSlot,
              timeRange: _selectedTimeRange,
              duration: _selectedDuration,
              groundName: _groundName,
              groundLocality: _groundLocality,
              groundImage: _groundImage,
            ),
            const SizedBox(height: 24),

            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _PaymentOption(
              icon: Icons.credit_card_rounded,
              label: 'Pay Online',
              badge: 'Recommended',
              subtitle: 'UPI, Cards, Net Banking',
              footer: 'Powered by Razorpay',
              selected: _paymentMethod == 'online',
              onTap: _loading || _hasPendingBooking
                  ? null
                  : () => setState(() => _paymentMethod = 'online'),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Pay at Ground',
              subtitle: 'Pay 10% advance now, rest at the venue',
              selected: _paymentMethod == 'pay_at_ground',
              onTap: _loading || _hasPendingBooking
                  ? null
                  : () => setState(() => _paymentMethod = 'pay_at_ground'),
            ),

            const SizedBox(height: 24),

            Text(
              'Price Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // What is charged now versus at the venue. Without this the
            // pay-at-ground CTA quotes a number smaller than the booking and
            // reads like the price changed.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  _MoneyRow(
                    label:
                        'Booking Total (${_slotIds.length} slot${_slotIds.length == 1 ? '' : 's'})',
                    value: '₹$_totalPrice',
                    colors: colors,
                  ),
                  const SizedBox(height: 10),
                  _MoneyRow(
                    label: 'Platform Fee',
                    value: '₹0',
                    colors: colors,
                    trailingIcon: Tooltip(
                      message: 'No platform fee is charged on this booking.',
                      child: Icon(Icons.info_outline_rounded,
                          size: 14, color: colors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DashedDivider(color: colors.border),
                  const SizedBox(height: 14),
                  _MoneyRow(
                    label: 'Total Amount',
                    value: '₹$_totalPrice',
                    colors: colors,
                    emphasise: true,
                  ),
                  // The advance/balance split only means anything once it's
                  // not the whole amount — paying online, "due at the
                  // ground" would just repeat "₹0" beside the total above.
                  if (!_isOnline) ...[
                    const SizedBox(height: 10),
                    _MoneyRow(
                      label: 'Due at the ground',
                      value: '₹$_balanceAtGround',
                      colors: colors,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _isOnline
                                ? 'Pay Now (100% online)'
                                : 'Pay Now (10% advance)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹$_payableNow',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Online payment reassurance — only relevant to the method that
            // is actually selected.
            if (_isOnline)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InfoBanner(
                  icon: Icons.verified_user_rounded,
                  iconColor: AppColors.success,
                  title: 'Secure Payment',
                  titleColor: colors.textPrimary,
                  subtitle:
                      'Your payment is processed securely by Razorpay.\n'
                      'Your slot will be instantly confirmed after payment.',
                ),
              ),

            // The server releases these slots when the hold lapses, so the
            // countdown has to be visible — otherwise the booking silently
            // stops working mid-payment.
            if (_holdRemaining != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InfoBanner(
                  icon: _holdLapsed
                      ? Icons.timer_off_rounded
                      : Icons.timer_outlined,
                  iconColor: _holdLapsed ? AppColors.error : AppColors.warning,
                  title: _holdLapsed
                      ? 'Slots released'
                      : 'Slots held for ${_formatHold(_holdRemaining!)}',
                  titleColor: _holdLapsed ? AppColors.error : AppColors.warning,
                  subtitle: _holdLapsed
                      ? 'Go back and pick them again to continue.'
                      : 'Complete the payment before the timer runs out.',
                ),
              ),

            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _InfoBanner(
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.info,
                title: 'Cancellation Policy',
                titleColor: AppColors.info,
                subtitle:
                    'Cancellations must be made at least 2 hours before the slot.\n'
                    'No-shows may affect future bookings.',
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.error),
                            ),
                            if (_hasPendingBooking) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Your slots are still held under this booking — '
                                'retrying settles its payment rather than '
                                'booking again.',
                                style: TextStyle(
                                    fontSize: 12, color: colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),

      // Bottom bar — the shared widget, not a hand-rolled copy: it already
      // owns the safe-area inset and the double-submit guard.
      bottomNavigationBar: StickyBottomBar(
        priceLabel: 'Pay Now',
        price: '₹$_payableNow',
        priceCaption: _isOnline ? 'Total Amount' : 'Advance amount',
        secureNote: _isOnline
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: colors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Secure by Razorpay',
                    style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                  ),
                ],
              )
            : null,
        buttonText: _holdLapsed
            ? 'Slots released'
            : _hasPendingBooking
                // The booking already exists; this attempt only settles payment.
                ? 'Retry payment'
                : 'Pay ₹$_payableNow',
        footnote: _isOnline && !_holdLapsed
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 13, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Instant Confirmation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.successText,
                    ),
                  ),
                ],
              )
            : null,
        isLoading: _loading,
        onPressed: _holdLapsed ? null : _confirmBooking,
      ),
    );
  }
}

/// "Hold for 04:56" — the countdown pinned to the app bar, so it stays
/// visible even once the page has scrolled the banner further down out of
/// view.
class _HoldPill extends StatelessWidget {
  const _HoldPill({required this.remaining});

  final String remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            'Hold for $remaining',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashed rule between the line items and the total — thin enough to read
/// as a break in the list rather than another row.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor();
        return SizedBox(
          height: 1,
          child: Row(
            children: List.generate(
              count,
              (_) => Padding(
                padding: const EdgeInsets.only(right: gap),
                child: Container(width: dashWidth, height: 1, color: color),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The shared shape behind Secure Payment, the hold countdown and the
/// cancellation policy: an icon in a tinted circle, a coloured title, and a
/// muted body — three facts the checkout screen states rather than asks.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  final bool emphasise;

  /// A small glyph after the label — the Platform Fee's info tooltip.
  final Widget? trailingIcon;

  const _MoneyRow({
    required this.label,
    required this.value,
    required this.colors,
    this.emphasise = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: emphasise ? 14.5 : 13,
                    color: emphasise ? colors.textPrimary : colors.textSecondary,
                    fontWeight: emphasise ? FontWeight.w700 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 5),
                trailingIcon!,
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasise ? 16 : 14,
            fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
            color: emphasise ? AppColors.primary : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final GroundSportModel? groundSport;
  final String date;
  final int slotCount;
  final int totalPrice;
  /// The venue's per-slot price. Passed in rather than read off groundSport,
  /// which no longer carries the price it used to.
  final double pricePerSlot;
  final String? timeRange;
  final String? duration;
  final String? groundName;
  final String? groundLocality;
  final String? groundImage;

  const _SummaryCard({
    required this.groundSport,
    required this.date,
    required this.slotCount,
    required this.totalPrice,
    required this.pricePerSlot,
    this.timeRange,
    this.duration,
    this.groundName,
    this.groundLocality,
    this.groundImage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SportGlyph(
                    name: groundSport?.sport?.name ?? '',
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groundSport?.sport?.name ?? 'Sport',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${pricePerSlot.toStringAsFixed(0)} per slot • 30 mins',
                      style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (groundImage != null) ...[
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: groundImage!,
                    width: 64,
                    height: 46,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(width: 64, height: 46, color: colors.card),
                    errorWidget: (_, __, ___) =>
                        Container(width: 64, height: 46, color: colors.card),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 14),
          _Row(icon: Icons.calendar_today_rounded, label: 'Date', value: date),
          if (timeRange != null) ...[
            const SizedBox(height: 10),
            _Row(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: timeRange!,
            ),
          ],
          const SizedBox(height: 10),
          _Row(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Duration',
            value: duration == null
                ? '$slotCount slot${slotCount > 1 ? 's' : ''}'
                : '$duration ($slotCount slot${slotCount > 1 ? 's' : ''})',
          ),
          if (groundName != null) ...[
            const SizedBox(height: 10),
            _Row(
              icon: Icons.stadium_rounded,
              label: 'Venue',
              value: groundName!,
              caption: groundLocality,
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.brandText.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Price',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  '₹$totalPrice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.brandText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// A second, muted line under [value] — the venue's locality under its name.
  final String? caption;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;

  /// "Recommended" beside the label — only Pay Online carries one.
  final String? badge;
  final String subtitle;

  /// A second, muted subtitle line — "Powered by Razorpay".
  final String? footer;
  final bool selected;
  final VoidCallback? onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    this.badge,
    required this.subtitle,
    this.footer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label${badge == null ? '' : ', $badge'}, $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.input,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '($badge)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: colors.textSecondary)),
                    if (footer != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              size: 11, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              footer!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : colors.border,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
