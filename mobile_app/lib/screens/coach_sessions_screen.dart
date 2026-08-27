import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/coach_booking_model.dart';
import '../providers/coach_bookings_provider.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/status_badge.dart';

/// The player's coaching sessions, newest first.
class CoachSessionsScreen extends ConsumerWidget {
  const CoachSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sessionsAsync = ref.watch(coachBookingsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        // Reached with context.go from the session screen, which leaves nothing
        // to pop — without an explicit fallback the arrow never appears and
        // system back closes the app. Same fix as My Bookings.
        leading: const AppBackButton(),
        title: const Text('My coaching'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.card,
        onRefresh: () async => ref.invalidate(coachBookingsProvider),
        child: sessionsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              ShimmerBox(width: double.infinity, height: 108, radius: 16),
              SizedBox(height: 12),
              ShimmerBox(width: double.infinity, height: 108, radius: 16),
              SizedBox(height: 12),
              ShimmerBox(width: double.infinity, height: 108, radius: 16),
            ],
          ),
          error: (e, _) => ErrorView(
            message: apiErrorMessage(e, fallback: 'Could not load your sessions'),
            onRetry: () => ref.invalidate(coachBookingsProvider),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              // Still scrollable, or pull-to-refresh does nothing on the one
              // screen where a player is most likely to try it.
              return ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 80),
                children: [
                  Icon(Icons.sports_rounded,
                      size: 56, color: colors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No coaching sessions yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find a coach and book a slot — they confirm it from their end.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go('/coaching'),
                        child: const Text('Browse coaches'),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _SessionCard(session: sessions[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final CoachBookingModel session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: '${session.coachName}, ${session.formattedDate}, '
          '${session.timeRange}, ${session.statusLabel}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/coach-sessions/${session.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(session: session),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.coachName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${session.formattedDate} · ${session.timeRange}',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12)),
                    if (session.groundName != null) ...[
                      const SizedBox(height: 2),
                      Text(session.groundName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    StatusBadge(
                      label: session.statusLabel,
                      color: _tone(session.status).withValues(alpha: 0.15),
                      textColor: _tone(session.status),
                      icon: _glyph(session.status),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(session.formattedAmount,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Color _tone(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.primary;
      case 'completed':
        return AppColors.info;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  IconData _glyph(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'completed':
        return Icons.done_all_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }
}

class _Avatar extends StatelessWidget {
  final CoachBookingModel session;
  const _Avatar({required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fallback = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          session.coachName.isNotEmpty
              ? session.coachName[0].toUpperCase()
              : '?',
          style: TextStyle(
              color: colors.textSecondary,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
      ),
    );

    final photo = session.coachPhoto;
    if (photo == null || photo.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: photo,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
