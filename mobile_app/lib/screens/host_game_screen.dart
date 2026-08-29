import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/booking_model.dart';
import '../models/game_filters.dart';
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
  final _noteCtrl = TextEditingController();

  BookingModel? _booking;
  int _maxPlayers = 10;
  GameLevel _level = GameLevel.intermediate;
  bool _isPublic = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
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
      final note = _noteCtrl.text.trim();
      await ApiClient.createGame({
        'game_name': name,
        'booking_id': _booking!.id,
        'max_participants': _maxPlayers,
        'game_level': _level.query,
        'visibility': _isPublic ? 'public' : 'private',
        if (note.isNotEmpty) 'description': note,
      });

      ref.invalidate(gamesProvider);
      ref.invalidate(myGamesProvider);

      if (!mounted) return;
      // Replaced, not pushed — backing into a published form would let the
      // player submit the same booking twice.
      context.pushReplacement('/games');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(_isPublic
              ? '"$name" is live in Discover.'
              : '"$name" is ready — invite the players you want.'),
        ));
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
              const SizedBox(height: 4),
              Text(
                'Players filter Discover by this, so pitch it honestly.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 10),
              // Chips rather than a dropdown: six values that all matter to
              // who turns up, on a screen with the room to show them.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GameLevel.values
                    .map((l) => _LevelChip(
                          label: l.label,
                          selected: _level == l,
                          onTap: _submitting
                              ? null
                              : () => setState(() => _level = l),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              _Label('Anything players should know?', colors: colors),
              const SizedBox(height: 4),
              Text(
                'Optional — bring bibs, we play 7-a-side, parking is round the '
                'back.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Friendly game, all welcome.',
                ),
              ),
              const SizedBox(height: 8),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isPublic
                                ? 'Shows up in Discover — anyone can take a seat.'
                                : 'Hidden from Discover — only players you '
                                    'invite can join.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
              const SizedBox(height: 16),
              _SplitNote(booking: _booking, seats: _maxPlayers),
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

/// A selectable skill-level pill, 44px tall so it is hittable.
class _LevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Never state-by-colour alone.
              if (selected) ...[
                Icon(Icons.check_rounded, size: 15, color: colors.brandText),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.brandText : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What each player ends up paying, worked out from the booking the host
/// picked and the number of seats they opened.
///
/// Shown because the split is the whole reason a stranger joins, and a host
/// setting the seat count blind is choosing a price without being told. The
/// figure is the same arithmetic the API does on the way out — the server is
/// still the only thing that decides what anyone owes.
class _SplitNote extends StatelessWidget {
  final BookingModel? booking;
  final int seats;

  const _SplitNote({required this.booking, required this.seats});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final b = booking;
    if (b == null || seats <= 0) return const SizedBox.shrink();

    final total = b.totalAmount;
    final share = total > 0 ? total / seats : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.pie_chart_outline_rounded,
              size: 18, color: colors.brandText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              total > 0
                  ? '₹${total.toStringAsFixed(0)} split $seats ways — '
                      'about ₹${share.toStringAsFixed(0)} per player, '
                      'settled at the ground.'
                  : 'This booking has no price on it yet, so players will see '
                      '"price on request".',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
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
