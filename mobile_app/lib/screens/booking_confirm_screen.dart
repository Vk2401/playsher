import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_colors.dart';
import '../core/booking_share.dart';
import '../widgets/sport_glyph.dart';
import '../widgets/status_badge.dart';

class BookingConfirmScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  const BookingConfirmScreen({super.key, this.bookingData});

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Reading the payload ────────────────────────────────────────────────────
  // Keys are the Booking row POST /bookings returns
  // (backend-api/src/models/Booking.js), plus the display fields the booking
  // flow carries in because the row has no ground or sport name.

  Map<String, dynamic> get _b => widget.bookingData ?? {};

  String? _str(String key) {
    final v = _b[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double _num(String key) => double.tryParse(_b[key]?.toString() ?? '') ?? 0;

  /// The flow passes a display label ('Online' / 'Pay at Ground'); the API row
  /// carries the wire value ('online' / 'pay_at_ground'). Accept either.
  bool get _isOnline {
    final raw = (_str('payment_method') ?? '').toLowerCase();
    return raw == 'online';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Thu, 20 Aug 2026" from "2026-08-20". Raw value if it will not parse.
  String? get _date {
    final raw = _str('slot_date');
    if (raw == null) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  static String? _hhmm(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    if (h == null) return null;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${parts[1].padLeft(2, '0')} $suffix';
  }

  /// "6:30 PM - 7:00 PM". The row carries both ends; the screen never showed
  /// either, so the ticket said which day but not when.
  String? get _timeRange {
    final from = _hhmm(_str('slot_time_from'));
    final to = _hhmm(_str('slot_time_to'));
    if (from == null) return null;
    return to == null ? from : '$from - $to';
  }

  String? get _duration {
    int? mins(String? raw) {
      if (raw == null) return null;
      final p = raw.split(':');
      if (p.length < 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      return (h == null || m == null) ? null : h * 60 + m;
    }

    final from = mins(_str('slot_time_from'));
    final to = mins(_str('slot_time_to'));
    if (from == null || to == null || to <= from) return null;
    final total = to - from;
    final hours = total ~/ 60;
    final rest = total % 60;
    if (hours == 0) return '$rest min';
    if (rest == 0) return '$hours hr';
    return '$hours hr $rest min';
  }

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    final text = BookingShare.build(
      reference: _str('booking_reference'),
      groundName: _str('ground_name'),
      sportName: _str('sport_name'),
      date: _date,
      timeRange: _timeRange,
      duration: _duration,
      total: _money(_num('total_amount')),
      amountPaid: _num('advance_amount') > 0
          ? _money(_num('advance_amount'))
          : null,
      balanceDue:
          _num('balance_due') > 0 ? _money(_num('balance_due')) : null,
      paymentMethod: _isOnline ? 'Paid online' : 'Pay at ground',
    );

    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: 'My Playsher booking',
      // iPad anchors the share sheet to a rect; without it the call throws
      // there rather than presenting.
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  void _copyReference() {
    final ref = _str('booking_reference');
    if (ref == null) return;
    Clipboard.setData(ClipboardData(text: ref));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking reference copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final total = _num('total_amount');
    final advance = _num('advance_amount');
    final balance = _num('balance_due');
    final ground = _str('ground_name');
    final sport = _str('sport_name');
    final groundImage = _str('ground_image');
    final reference = _str('booking_reference');
    final status = _str('status') ?? 'confirmed';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        // Scrollable: the card grew with time, duration and the money split,
        // and the old Spacer-based Column overflowed on a short screen.
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.onPrimary,
                            size: 40,
                            semanticLabel: 'Booking confirmed',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          Text(
                            _isOnline
                                ? 'Payment Successful!'
                                : 'Booking Confirmed!',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            balance > 0
                                ? 'Your slot is reserved.\nPay ${_money(balance)} at the ground.'
                                : 'Your slot is confirmed. Get ready to play!',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          _TicketCard(
                            ground: ground,
                            sport: sport,
                            groundImage: groundImage,
                            status: status,
                            reference: reference,
                            onCopyReference:
                                reference == null ? null : _copyReference,
                            rows: [
                              if (_date != null)
                                _Fact(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Date',
                                  value: _date!,
                                ),
                              if (_timeRange != null)
                                _Fact(
                                  icon: Icons.access_time_rounded,
                                  label: 'Time',
                                  value: _timeRange!,
                                  pill: _duration,
                                ),
                            ],
                            money: [
                              _Fact(
                                icon: Icons.receipt_long_rounded,
                                label: 'Booking Total',
                                value: _money(total),
                                emphasis: true,
                              ),
                              if (advance > 0)
                                _Fact(
                                  icon: Icons.check_circle_outline_rounded,
                                  label: balance > 0 ? 'Advance paid' : 'Paid',
                                  value: _money(advance),
                                ),
                              if (balance > 0)
                                _Fact(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Due at the ground',
                                  value: _money(balance),
                                  warn: true,
                                ),
                              _Fact(
                                icon: Icons.payment_rounded,
                                label: 'Payment Method',
                                value:
                                    _isOnline ? 'Paid online' : 'Pay at Ground',
                                valueColor: colors.brandText,
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          _ImportantNote(colors: colors),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Actions ────────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.ios_share_rounded, size: 19),
                        label: const Text(
                          'Share Booking Details',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => context.go('/home'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Home'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => context.go('/my-bookings'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('View My Bookings'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SecureBookingNote(colors: colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The booking rendered as a ticket: who and where at the top, the times in the
/// middle, money below a perforation.
class _TicketCard extends StatelessWidget {
  final String? ground;
  final String? sport;
  final String? groundImage;
  final String status;
  final String? reference;
  final VoidCallback? onCopyReference;
  final List<_Fact> rows;
  final List<_Fact> money;

  const _TicketCard({
    required this.ground,
    required this.sport,
    required this.groundImage,
    required this.status,
    required this.reference,
    required this.onCopyReference,
    required this.rows,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: groundImage == null
                      ? Container(
                          width: 46,
                          height: 46,
                          color: colors.card,
                          child: Center(
                            child: SportGlyph(name: sport ?? '', size: 24),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: groundImage!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(width: 46, height: 46, color: colors.card),
                          errorWidget: (_, __, ___) => Container(
                            width: 46,
                            height: 46,
                            color: colors.card,
                            child: Center(
                              child: SportGlyph(name: sport ?? '', size: 24),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ground ?? 'Your booking',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sport != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SportGlyph(name: sport!, size: 14),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                sport!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
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
                StatusBadge.bookingStatus(status),
              ],
            ),
          ),

          if (rows.isNotEmpty) ...[
            _Perforation(color: colors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(children: _spaced(rows)),
            ),
          ],

          _Perforation(color: colors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(children: _spaced(money)),
          ),

          if (reference != null) ...[
            _Perforation(color: colors.border),
            // The reference gets the footer to itself: it is the one string a
            // venue asks for, and people read it out or paste it.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Reference',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reference!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Copy booking reference',
                    button: true,
                    child: GestureDetector(
                      onTap: onCopyReference,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.copy_rounded,
                            size: 17, color: colors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Even 10px gaps between facts. The old screen hand-placed SizedBoxes and
  /// missed two, so "Paid" and "Payment" ran together.
  static List<Widget> _spaced(List<_Fact> facts) {
    final out = <Widget>[];
    for (var i = 0; i < facts.length; i++) {
      if (i > 0) out.add(const SizedBox(height: 10));
      out.add(facts[i]);
    }
    return out;
  }
}

class _Perforation extends StatelessWidget {
  final Color color;
  const _Perforation({required this.color});

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasis;
  final bool warn;

  /// An explicit value colour — the payment method's "Paid online" reads in
  /// the brand colour without being the larger, bolder [emphasis] size.
  final Color? valueColor;

  /// A small tinted pill after the value — the time range's "30 min".
  final String? pill;

  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.warn = false,
    this.valueColor,
    this.pill,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = warn
        ? AppColors.warning
        : valueColor ?? (emphasis ? colors.brandText : colors.textPrimary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(width: 12),
        // Expanded, not a bare Row child: a long ground name or a wide time
        // range would otherwise overflow the card.
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: emphasis ? 15 : 13,
                  fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
              if (pill != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pill!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.brandText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "**Important:** Arrive 15 minutes early…" — a single flowing sentence with
/// only its lead word emphasised, matched to the app's other info banners
/// (`_InfoBanner` in the booking flow) rather than a one-off style.
class _ImportantNote extends StatelessWidget {
  final AppColors colors;
  const _ImportantNote({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline_rounded,
                size: 15, color: AppColors.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Important: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const TextSpan(
                    text: 'Arrive 15 minutes early and show your booking '
                        'reference at the venue.',
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Secure booking. Enjoy your game!" — the reassurance the flow closes on,
/// pinned beside the actions rather than lost above the fold in the scroll.
class _SecureBookingNote extends StatelessWidget {
  final AppColors colors;
  const _SecureBookingNote({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_rounded,
              size: 15, color: AppColors.success),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Secure booking. Enjoy your game!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.successText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
