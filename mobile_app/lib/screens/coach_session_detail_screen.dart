import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/coach_booking_model.dart';
import '../providers/coach_bookings_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/status_badge.dart';

/// One coaching session, from the player's side.
///
/// This is also where the booking flow lands, so it opens by saying what
/// happens next rather than only what was booked: the coach still has to
/// accept, and a screen that just says "Booked" would be a lie until they do.
class CoachSessionDetailScreen extends ConsumerWidget {
  final String sessionId;
  const CoachSessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final id = int.tryParse(sessionId);
    if (id == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Session')),
        body: const ErrorView(message: 'That session link is not valid'),
      );
    }

    final sessionAsync = ref.watch(coachBookingDetailProvider(id));
    final state = ref.watch(coachBookingNotifierProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Coaching session'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          // The flow reaches here with pushReplacement, so there is nothing
          // behind it to pop to — go, not pop.
          onPressed: () => context.go('/my-sessions'),
        ),
      ),
      body: sessionAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ShimmerBox(width: double.infinity, height: 220, radius: 16),
        ),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e, fallback: 'Could not load this session'),
          onRetry: () => ref.invalidate(coachBookingDetailProvider(id)),
        ),
        data: (session) => _Body(session: session),
      ),
      bottomNavigationBar: sessionAsync.maybeWhen(
        data: (session) => session.isCancellable
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _confirmCancel(context, ref, session),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.error),
                            )
                          : const Text('Cancel session'),
                    ),
                  ),
                ),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, CoachBookingModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: Text(
          'Your ${session.formattedDate} session at ${session.timeRange} will '
          'be cancelled and the time released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok =
        await ref.read(coachBookingNotifierProvider.notifier).cancel(session.id);
    if (!context.mounted) return;

    final message = ok
        ? 'Session cancelled.'
        : ref.read(coachBookingNotifierProvider).error ??
            'Could not cancel this session';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Body extends StatelessWidget {
  final CoachBookingModel session;
  const _Body({required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.coachName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: session.statusLabel,
                    color: _toneColor(session.status).withValues(alpha: 0.15),
                    textColor: _toneColor(session.status),
                    icon: _toneIcon(session.status),
                  ),
                ],
              ),
              if (session.sportName != null) ...[
                const SizedBox(height: 4),
                Text(session.sportName!,
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              _Row(icon: Icons.event, label: session.formattedDate),
              _Row(icon: Icons.schedule, label: session.timeRange),
              _Row(
                icon: Icons.location_on,
                label: session.groundName ?? 'Venue to be agreed with the coach',
              ),
              _Row(
                icon: Icons.payments,
                label: '${session.formattedAmount} · paid at the venue',
              ),
              if (session.bookingReference != null)
                _Row(icon: Icons.tag, label: session.bookingReference!),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // What happens next, said in words rather than left to a colour.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _toneColor(session.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _toneColor(session.status).withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_toneIcon(session.status),
                  color: _toneColor(session.status), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusExplanation(session),
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        if (session.customerNote != null && session.customerNote!.isNotEmpty)
          _Note(title: 'Your note', body: session.customerNote!),
        if (session.coachNote != null && session.coachNote!.isNotEmpty)
          _Note(title: 'From your coach', body: session.coachNote!),
        if (session.cancellationReason != null &&
            session.cancellationReason!.isNotEmpty)
          _Note(title: 'Reason', body: session.cancellationReason!),
      ],
    );
  }

  String _statusExplanation(CoachBookingModel session) {
    switch (session.status) {
      case 'pending':
        return 'Your time is held. ${session.coachName} still has to accept — '
            'you will get a notification either way.';
      case 'confirmed':
        return 'Confirmed by your coach. Turn up a few minutes early.';
      case 'completed':
        return 'This session is done. You can review your coach from your '
            'session list.';
      case 'rejected':
        return 'Your coach could not take this session, and the time has been '
            'released.';
      case 'cancelled':
        return 'This session was cancelled and the time released.';
      default:
        return session.statusLabel;
    }
  }

  Color _toneColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return AppColors.primary;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  IconData _toneIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.done_all_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Row({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(color: colors.textPrimary, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String title;
  final String body;
  const _Note({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
