import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/bookings_provider.dart';
import '../widgets/error_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookingAsync = ref.watch(
      bookingDetailProvider(int.parse(widget.bookingId)),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
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
                _Section(
                  title: 'Ground',
                  child: _InfoCard(
                    items: [
                      _InfoItem(
                        icon: Icons.stadium_rounded,
                        label: 'Ground',
                        value: booking.groundName ?? '\u2014',
                      ),
                      _InfoItem(
                        icon: Icons.sports_rounded,
                        label: 'Sport',
                        value: booking.sportName ?? '\u2014',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Booking Info',
                  child: _InfoCard(
                    items: [
                      _InfoItem(
                        icon: Icons.tag_rounded,
                        label: 'Booking ID',
                        value: '#${booking.id}',
                      ),
                      _InfoItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: booking.bookingDate,
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
                        label: 'Total Amount',
                        value: booking.formattedPrice,
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
                        const Spacer(),
                        Flexible(
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
  const _InfoItem(
      {required this.icon, required this.label, required this.value});
}
