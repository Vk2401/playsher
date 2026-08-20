import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../models/booking_model.dart';
import 'status_badge.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;

  const BookingCard({super.key, required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
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
                children: [
                  // Ground image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: booking.groundImage != null
                        ? CachedNetworkImage(
                            imageUrl: booking.groundImage!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _placeholder(colors),
                            errorWidget: (_, __, ___) => _placeholder(colors),
                          )
                        : _placeholder(colors),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.groundName ?? 'Ground',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        StatusBadge.bookingStatus(booking.status),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 12, color: colors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              booking.bookingDate,
                              style: TextStyle(
                                  fontSize: 11, color: colors.textSecondary),
                            ),
                            if ((booking.sportName ?? '').isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.sports_rounded,
                                  size: 12, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                booking.sportName!,
                                style: TextStyle(
                                    fontSize: 11, color: colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (booking.isUpcoming && onCancel != null)
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppColors.error, size: 20),
                      onPressed: onCancel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            // Bottom strip
            Container(
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: 0.04),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Arrive 15 mins early',
                    style: TextStyle(fontSize: 10, color: colors.textSecondary),
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
                      size: 14, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(AppColors colors) => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.sports_soccer, color: AppColors.primary, size: 32),
      );
}
