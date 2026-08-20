import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../core/booking_share.dart';
import '../core/map_links.dart';
import '../models/booking_model.dart';
import '../providers/bookings_provider.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_view.dart';
import '../widgets/sport_glyph.dart';
import '../widgets/shimmer_loader.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _cancelling = false;

  Future<void> _cancelBooking() async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title:
            Text('Cancel Booking', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to cancel this booking?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel Booking',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ApiClient.cancelBooking(
          int.parse(widget.bookingId), 'User requested');
      if (mounted) {
        ref.invalidate(bookingsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _openDirections(BookingModel booking) async {
    final opened = await MapLinks.openDirections(
      latitude: booking.groundLatitude,
      longitude: booking.groundLongitude,
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open a maps app.')),
    );
  }

  Future<void> _share(BookingModel booking) async {
    final text = BookingShare.build(
      reference: booking.referenceLabel,
      groundName: booking.groundName,
      sportName: booking.sportName,
      date: booking.formattedDateLong,
      timeRange: booking.timeRange,
      duration: booking.durationLabel,
      total: booking.formattedPrice,
      amountPaid:
          booking.advanceAmount > 0 ? booking.formattedAdvance : null,
      balanceDue: booking.hasBalanceDue ? booking.formattedBalance : null,
      paymentMethod: booking.paymentMethodLabel,
      directionsUrl: booking.directionsUrl,
      address: booking.groundAddress,
    );

    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: 'My Playsher booking',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookingAsync = ref.watch(
      bookingDetailProvider(int.parse(widget.bookingId)),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        // A deep link straight to /bookings/:id has nothing to pop; fall back
        // to the list rather than trapping the user on the detail screen.
        leading: const AppBackButton(fallbackRoute: '/my-bookings'),
        title: const Text(
          'Booking Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Same text the confirmation screen sends, so a booking re-shared a
          // week later reads identically to the one shared at checkout.
          if (bookingAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              tooltip: 'Share booking details',
              onPressed: () => _share(bookingAsync.value!),
            ),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: BookingCardShimmer(),
        ),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e, fallback: 'Could not load this booking'),
          onRetry: () => ref.invalidate(
            bookingDetailProvider(int.parse(widget.bookingId)),
          ),
        ),
        data: (booking) {
          final canCancel = booking.isUpcoming && !booking.isCancelled;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBanner(status: booking.status),
                const SizedBox(height: 20),

                // The three facts that decide whether you can show up: where,
                // what day, and what time. Given their own card at the top
                // rather than buried among ids and money.
                _WhenWhereCard(booking: booking),
                if (booking.hasDirections) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _openDirections(booking),
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text('Get directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                _Section(
                  title: 'Booking Info',
                  child: _InfoCard(
                    items: [
                      _InfoItem(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Booking reference',
                        value: booking.referenceLabel,
                        copyable: true,
                      ),
                      _InfoItem(
                        icon: Icons.stadium_rounded,
                        label: 'Ground',
                        value: booking.groundName ?? 'Not available',
                      ),
                      _InfoItem(
                        icon: Icons.sports_rounded,
                        label: 'Sport',
                        value: booking.sportName ?? 'Not available',
                      ),
                      _InfoItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: booking.formattedDateLong,
                      ),
                      if (booking.timeRange != null)
                        _InfoItem(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: booking.timeRange!,
                        ),
                      if (booking.durationLabel != null)
                        _InfoItem(
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'Duration',
                          value: booking.slotCountLabel == null
                              ? booking.durationLabel!
                              : '${booking.durationLabel}  (${booking.slotCountLabel})',
                        ),
                      if (booking.createdAt != null)
                        _InfoItem(
                          icon: Icons.event_available_rounded,
                          label: 'Booked on',
                          value: _bookedOn(booking.createdAt!),
                        ),
                      if ((booking.cancellationReason ?? '').isNotEmpty)
                        _InfoItem(
                          icon: Icons.info_outline_rounded,
                          label: 'Cancellation reason',
                          value: booking.cancellationReason!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Payment',
                  child: _InfoCard(
                    items: [
                      _InfoItem(
                        icon: Icons.attach_money_rounded,
                        label: 'Booking total',
                        value: booking.formattedPrice,
                      ),
                      if (booking.advanceAmount > 0)
                        _InfoItem(
                          icon: Icons.check_circle_outline_rounded,
                          label:
                              booking.hasBalanceDue ? 'Advance paid' : 'Paid',
                          value: booking.formattedAdvance,
                        ),
                      if (booking.hasBalanceDue)
                        _InfoItem(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Due at the ground',
                          value: booking.formattedBalance,
                        ),
                      _InfoItem(
                        icon: Icons.payment_rounded,
                        label: 'Payment Method',
                        value: booking.paymentMethodLabel,
                      ),
                      _InfoItem(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Status',
                        value:
                            (booking.paymentStatus ?? 'pending').toUpperCase(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (canCancel)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _cancelling ? null : _cancelBooking,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: AppColors.error,
                      ),
                      icon: _cancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                        _cancelling ? 'Cancelling\u2026' : 'Cancel Booking',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg, fg;
    IconData icon;

    if (s == 'confirmed' || s == 'active') {
      bg = AppColors.primary.withValues(alpha: 0.12);
      fg = AppColors.primary;
      icon = Icons.check_circle_rounded;
    } else if (s == 'cancelled') {
      bg = AppColors.error.withValues(alpha: 0.12);
      fg = AppColors.error;
      icon = Icons.cancel_rounded;
    } else if (s == 'completed') {
      bg = AppColors.info.withValues(alpha: 0.12);
      fg = AppColors.info;
      icon = Icons.done_all_rounded;
    } else {
      bg = AppColors.warning.withValues(alpha: 0.12);
      fg = AppColors.warning;
      icon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: fg,
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Booking status',
                style:
                    TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});

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
        children: items
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    Row(
                      children: [
                        Icon(e.value.icon,
                            size: 16, color: colors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          e.value.label,
                          style: TextStyle(
                              fontSize: 13, color: colors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        if (e.value.copyable)
                          Semantics(
                            label: 'Copy ${e.value.label}',
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: e.value.value));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${e.value.label} copied'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(Icons.copy_rounded, size: 15),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (e.key < items.length - 1) ...[
                      const SizedBox(height: 10),
                      Container(height: 1, color: colors.border),
                      const SizedBox(height: 10),
                    ],
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  /// Offers a copy button. For the booking reference, which people read out or
  /// paste when contacting the venue.
  final bool copyable;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });
}

/// The at-a-glance answer: which sport at which ground, on what day, at what
/// time. Everything else on this screen is detail behind these three facts.
class _WhenWhereCard extends StatelessWidget {
  final BookingModel booking;

  const _WhenWhereCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: SportGlyph(name: booking.sportName ?? '', size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.groundName ?? 'Ground',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    if ((booking.sportName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        booking.sportName!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroFact(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: booking.formattedDateLong,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroFact(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  // Never a bare dash: say what is missing rather than showing
                  // a glyph the user has to interpret.
                  value: booking.timeRange ?? 'Not available',
                  subtitle: booking.durationLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _HeroFact({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: colors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            height: 1.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// "20 Aug 2026, 5:25 PM" — when the booking was made.
String _bookedOn(DateTime at) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = at.toLocal();
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, '
      '$h12:$minute $suffix';
}
