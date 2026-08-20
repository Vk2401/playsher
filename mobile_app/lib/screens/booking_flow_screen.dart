import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../models/ground_sport_model.dart';

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
    _razorpay.clear();
    super.dispose();
  }

  // Stores booking response for use after Razorpay callback
  Map<String, dynamic>? _pendingBookingResult;

  Future<void> _confirmBooking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Step 1: Create booking via playsher-api
      final groundSportId = _groundSport?.id ?? widget.groundId;
      final rawResult = await ApiClient.createBooking(
        groundSportId: groundSportId,
        slotDate: _date,
        slotIds: _slotIds,
        paymentMethod: _paymentMethod == 'online' ? 'online' : 'pay_at_ground',
      );

      if (!mounted) return;

      // playsher-api wraps response: { success, data: { id, requires_payment, ... } }
      final result = rawResult['data'] as Map<String, dynamic>? ?? rawResult;

      // Step 2: If pay at ground, go directly to confirmation
      if (_paymentMethod == 'pay_at_ground') {
        context.go('/booking-confirm', extra: {
          ...result,
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
          'payment_method': 'Online',
        });
        return;
      }

      // Save booking result for use after Razorpay callback
      _pendingBookingResult = result;

      // Step 4: Create Razorpay order using booking ID
      final rawOrder = await ApiClient.createRazorpayOrder(
        bookingId is int ? bookingId : int.parse(bookingId.toString()),
      );

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
        'prefill': {
          'contact': '',
          'email': '',
        },
        'theme': {
          'color': '#00D261',
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
    // External wallet selected — payment flow continues via wallet app
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
          onPressed: _loading ? null : () => context.pop(),
        ),
        title: const Text(
          'Confirm Booking',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            _SummaryCard(
              groundSport: gs,
              date: _date,
              slotCount: _slotIds.length,
              totalPrice: _totalPrice,
            ),
            const SizedBox(height: 20),

            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _PaymentOption(
              icon: Icons.credit_card_rounded,
              label: 'Pay Online',
              subtitle: 'UPI, Cards, Net Banking',
              selected: _paymentMethod == 'online',
              onTap: _loading
                  ? null
                  : () => setState(() => _paymentMethod = 'online'),
            ),
            const SizedBox(height: 8),
            _PaymentOption(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Pay at Ground',
              subtitle: 'Pay when you arrive',
              selected: _paymentMethod == 'pay_at_ground',
              onTap: _loading
                  ? null
                  : () => setState(() => _paymentMethod = 'pay_at_ground'),
            ),

            const SizedBox(height: 24),

            // Online payment info
            if (_paymentMethod == 'online')
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Secure payment powered by Razorpay. Your slot is instantly confirmed after payment.',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

            // Warning banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cancellations must be made at least 2 hours before the slot. No-shows may affect future bookings.',
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Security disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 14, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment info is secure and encrypted',
                      style:
                          TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),

      // Bottom bar
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL AMOUNT',
                  style: TextStyle(
                      fontSize: 10,
                      color: colors.textSecondary,
                      letterSpacing: 1),
                ),
                Text(
                  '\u20b9$_totalPrice',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.onPrimary),
                      )
                    : Text(_paymentMethod == 'online'
                        ? 'Pay \u20b9$_totalPrice'
                        : 'Confirm & Book'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final GroundSportModel? groundSport;
  final String date;
  final int slotCount;
  final int totalPrice;

  const _SummaryCard({
    required this.groundSport,
    required this.date,
    required this.slotCount,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groundSport?.sport?.name ?? 'Sport',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '\u20b9${groundSport?.pricePerSlot.toStringAsFixed(0) ?? 0} / slot',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 16),
          Text(
            'SELECTED TIME',
            style: TextStyle(
                fontSize: 10, color: colors.textSecondary, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Row(
                icon: Icons.access_time_rounded,
                label: 'Slots',
                value: '$slotCount slot${slotCount > 1 ? 's' : ''}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRICE',
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                      letterSpacing: 1),
                ),
                Text(
                  '\u20b9$totalPrice',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
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

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : colors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey('check'),
                      color: AppColors.primary,
                      size: 22)
                  : Icon(Icons.radio_button_unchecked_rounded,
                      key: const ValueKey('uncheck'),
                      color: colors.border,
                      size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
