import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../core/animations.dart';
import '../core/app_colors.dart';
import '../models/booking_model.dart';
import 'sport_glyph.dart';
import 'status_badge.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;

  const BookingCard({super.key, required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppAnimations.tapScale(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumbnail(booking: booking),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                booking.groundName ?? 'Ground',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (booking.isUpcoming && onCancel != null)
                              // 44px target, small glyph — the guideline shape.
                              Semantics(
                                label: 'Cancel this booking',
                                button: true,
                                child: GestureDetector(
                                  onTap: onCancel,
                                  behavior: HitTestBehavior.opaque,
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(Icons.cancel_outlined,
                                        color: AppColors.error, size: 20),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        if ((booking.sportName ?? '').isNotEmpty)
                          Text(
                            booking.sportName!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),

                        const SizedBox(height: 8),
                        StatusBadge.bookingStatus(booking.status),
                        const SizedBox(height: 10),

                        // When — the two facts someone scanning this list wants.
                        _MetaRow(
                          icon: Icons.calendar_today_rounded,
                          text: booking.formattedDate,
                        ),
                        if (booking.timeRange != null) ...[
                          const SizedBox(height: 5),
                          _MetaRow(
                            icon: Icons.access_time_rounded,
                            text: booking.durationLabel == null
                                ? booking.timeRange!
                                : '${booking.timeRange!}  ·  ${booking.durationLabel}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom strip ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: 0.04),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      // What is still owed beats a generic tip: it is the thing
                      // that changes what the user does when they arrive.
                      booking.hasBalanceDue
                          ? '${booking.formattedBalance} due at venue'
                          : booking.formattedPrice,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: booking.hasBalanceDue
                            ? AppColors.warning
                            : colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    booking.isPast ? 'Review' : 'View Ticket',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ground photo, or the booked sport's own glyph.
///
/// Previously every card fell back to a football, so a cricket ground and a
/// basketball court both advertised the wrong sport.
class _Thumbnail extends StatelessWidget {
  final BookingModel booking;

  const _Thumbnail({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final image = booking.groundImage;

    Widget fallback() => Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SportGlyph(name: booking.sportName ?? '', size: 30),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: image == null || image.isEmpty
          ? fallback()
          : CachedNetworkImage(
              imageUrl: image,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback(),
              errorWidget: (_, __, ___) => fallback(),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 13, color: colors.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
