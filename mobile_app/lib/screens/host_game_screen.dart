import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/booking_model.dart';
import '../providers/bookings_provider.dart';
import '../providers/games_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sticky_bottom_bar.dart';

/// Host a game on top of one of the player's own bookings.
///
/// This screen previously collected a free-text venue, date and time and then
/// showed a "Game published!" snackbar without calling anything — nothing was
/// ever created. `POST /games` requires a `booking_id`: a game is hosted on a
/// slot you have already booked, so the form now starts from the player's
/// bookings instead of inventing a venue.
class HostGameScreen extends ConsumerStatefulWidget {
  const HostGameScreen({super.key});

  @override
  ConsumerState<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends ConsumerState<HostGameScreen> {
  final _nameCtrl = TextEditingController();

  BookingModel? _booking;
  int _maxPlayers = 10;
  String _level = 'intermediate';
  bool _isPublic = true;
  bool _submitting = false;

  // Values the API accepts for `game_level`.
  static const _levels = <String, String>{
    'newbie': 'Newbie',
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
    'professional': 'Professional',
    'ultra_professional': 'Ultra professional',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _booking != null && _nameCtrl.text.trim().isNotEmpty && !_submitting;

  Future<void> _publish() async {
    if (_submitting || _booking == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ApiClient.createGame({
        'game_name': name,
        'booking_id': _booking!.id,
        'max_participants': _maxPlayers,
        'game_level': _level,
        'visibility': _isPublic ? 'public' : 'private',
      });

      ref.invalidate(gamesProvider);
      ref.invalidate(myGamesProvider);

      if (!mounted) return;
      // Replaced, not pushed — backing into a published form would let the
      // player submit the same booking twice.
      context.pushReplacement('/games');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('"$name" is live.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e,
                fallback: 'Could not publish your game. Please try again.')),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookings = ref.watch(bookingsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Host a Game')),
      body: bookings.when(
        loading: () => ShimmerList(
            count: 2, itemBuilder: () => const BookingCardShimmer()),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e, fallback: 'Could not load your bookings'),
          onRetry: () => ref.invalidate(bookingsProvider),
        ),
        data: (all) {
          final hostable = all.where((b) => b.isUpcoming).toList();
          if (hostable.isEmpty) return const _NoBookings();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Label('Which booking?', colors: colors),
              const SizedBox(height: 4),
              Text(
                'A game runs on a slot you have already booked.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...hostable.map((b) => _BookingOption(
                    booking: b,
                    selected: _booking?.id == b.id,
                    onTap: () => setState(() => _booking = b),
                  )),
              const SizedBox(height: 24),
              _Label('Game name', colors: colors),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                enabled: !_submitting,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Sunday 5-a-side',
                ),
              ),
              const SizedBox(height: 24),
              _Label('Max players', colors: colors),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CounterButton(
                    icon: Icons.remove,
                    semanticLabel: 'Decrease max players',
                    onTap: _maxPlayers > 2
                        ? () => setState(() => _maxPlayers--)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      '$_maxPlayers',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _CounterButton(
                    icon: Icons.add,
                    semanticLabel: 'Increase max players',
                    onTap: _maxPlayers < 30
                        ? () => setState(() => _maxPlayers++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Label('Skill level', colors: colors),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _level,
                dropdownColor: colors.card,
                items: _levels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) {
                        if (v != null) setState(() => _level = v);
                      },
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPublic ? 'Public game' : 'Private game',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _isPublic ? 'Anyone can join' : 'Invite only',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPublic,
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _isPublic = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
      bottomNavigationBar:
          bookings.hasValue && bookings.requireValue.any((b) => b.isUpcoming)
              ? StickyBottomBar(
                  buttonText: 'Publish game',
                  isLoading: _submitting,
                  onPressed: _canSubmit ? _publish : null,
                )
              : null,
    );
  }
}

class _NoBookings extends StatelessWidget {
  const _NoBookings();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer_rounded,
                size: 56, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Book a slot first',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'A game is hosted on a ground slot you have booked. '
              'Book one, then come back to invite players.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.go('/venues'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(200, 48)),
              child: const Text('Find a ground'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _Label(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _BookingOption extends StatelessWidget {
  final BookingModel booking;
  final bool selected;
  final VoidCallback onTap;

  const _BookingOption({
    required this.booking,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final when = [
      booking.bookingDate,
      if (booking.startTime != null) booking.startTime,
    ].whereType<String>().join(' · ');

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppColors.primary : colors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.groundName ?? 'Booked ground',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [booking.sportName, when]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _CounterButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.input,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                icon,
                size: 20,
                color: enabled ? colors.textPrimary : colors.border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
