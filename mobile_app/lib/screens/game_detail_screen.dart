import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../core/map_links.dart';
import '../models/game_model.dart';
import '../models/participant_model.dart';
import '../providers/games_provider.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sport_glyph.dart';

/// One game, and the single decision it exists for: take a seat, or don't.
///
/// Everything above the bottom bar answers a question a stranger has before
/// committing — who is hosting, who else is going, where it is, what a seat
/// costs and why. The bar itself carries exactly one action, and which action
/// depends on where the viewer already stands: join, leave, or (for the host)
/// call it off.
class GameDetailScreen extends ConsumerWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  int get _id => int.tryParse(gameId) ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final gameAsync = ref.watch(gameDetailProvider(_id));

    return Scaffold(
      backgroundColor: colors.background,
      body: gameAsync.when(
        loading: () => const _DetailShimmer(),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(fallbackRoute: '/games'),
              ),
              Expanded(
                child: ErrorView(
                  message: apiErrorMessage(e,
                      fallback: 'Could not load this game'),
                  onRetry: () => ref.invalidate(gameDetailProvider(_id)),
                ),
              ),
            ],
          ),
        ),
        data: (game) => CustomScrollView(
          slivers: [
            _Hero(game: game),
            SliverToBoxAdapter(child: _Body(game: game)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: gameAsync.maybeWhen(
        data: (game) => _GameBottomBar(game: game),
        // No bar until the data that fills it exists — a price and a verb that
        // arrive a frame apart read as the screen changing its mind.
        orElse: () => null,
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

/// A sport-tinted panel rather than a photo.
///
/// A game has no image of its own — the venue's photos belong to the venue —
/// so the header is built from what the game *is*: its sport's colour, its
/// state, and when it kicks off.
class _Hero extends StatelessWidget {
  final GameModel game;

  const _Hero({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = AppColors.sportTint(game.sportName ?? '');

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      leading: const AppBackButton(fallbackRoute: '/games'),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tint.withValues(alpha: 0.32),
                colors.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Decorative watermark; the sport is named in words below.
              Positioned(
                right: -10,
                bottom: -10,
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0.16,
                    child: SportGlyph(name: game.sportName ?? '', size: 140),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _Tag(
                          label: game.sportName ?? 'Game',
                          color: tint,
                          icon: Icons.sports_rounded,
                        ),
                        if (game.levelLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _Tag(
                            label: game.levelLabel,
                            color: AppColors.info,
                            icon: Icons.trending_up_rounded,
                          ),
                        ],
                        if (game.isPrivate) ...[
                          const SizedBox(width: 8),
                          const _Tag(
                            label: 'Invite only',
                            color: AppColors.neutral,
                            icon: Icons.lock_outline_rounded,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      game.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: colors.textPrimary,
                      ),
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

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Tag({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final GameModel game;

  const _Body({required this.game});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (game.isCancelled || game.isCompleted || game.isInProgress)
            _StateBanner(game: game),
          _WhenWhere(game: game),
          const SizedBox(height: 18),
          _HostRow(game: game),
          const SizedBox(height: 22),
          _Squad(game: game),
          const SizedBox(height: 22),
          _Venue(game: game),
          if (game.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 22),
            const _Section(title: 'From the host'),
            const SizedBox(height: 8),
            Text(
              game.description!.trim(),
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: context.colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 22),
          _HowItWorks(game: game),
        ],
      ),
    );
  }
}

/// The one thing that overrides everything else on the page.
class _StateBanner extends StatelessWidget {
  final GameModel game;

  const _StateBanner({required this.game});

  @override
  Widget build(BuildContext context) {
    final (Color tone, IconData icon, String text) = switch (game.status) {
      'cancelled' => (
          AppColors.error,
          Icons.cancel_rounded,
          'The host called this game off.'
        ),
      'completed' => (
          AppColors.neutral,
          Icons.done_all_rounded,
          'This game has already been played.'
        ),
      _ => (
          AppColors.info,
          Icons.sports_rounded,
          'This game is being played right now.'
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two facts a player checks before anything else.
class _WhenWhere extends StatelessWidget {
  final GameModel game;

  const _WhenWhere({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final countdown = game.countdownLabel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _Line(
            icon: Icons.event_rounded,
            title: game.dayLabel,
            subtitle: game.timeLabel,
            trailing: countdown == null
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      countdown,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.info,
                      ),
                    ),
                  ),
          ),
          Divider(height: 22, color: colors.border),
          _Line(
            icon: Icons.groups_rounded,
            title: '${game.currentPlayers} of ${game.maxPlayers} players in',
            subtitle: game.spotsLabel,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _Line({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: colors.brandText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _HostRow extends StatelessWidget {
  final GameModel game;

  const _HostRow({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = game.hostName ?? 'A Playsher player';

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withValues(alpha: 0.14),
          backgroundImage: game.hostAvatar?.trim().isNotEmpty == true
              ? NetworkImage(game.hostAvatar!)
              : null,
          child: game.hostAvatar?.trim().isNotEmpty == true
              ? null
              : Text(
                  name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                  style: TextStyle(
                    color: colors.brandText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game.isHost ? 'You' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Hosting this game',
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Who is going, seat by seat.
class _Squad extends StatelessWidget {
  final GameModel game;

  const _Squad({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final seated = game.participants
        .where((p) => p.status == 'joined' || p.status == 'accepted')
        .toList();
    // Six empty chairs at most: a 30-player game should not render 28 circles.
    final empties = game.spotsLeft.clamp(0, 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Squad',
          trailing: '${game.currentPlayers}/${game.maxPlayers}',
        ),
        const SizedBox(height: 12),
        if (seated.isEmpty && empties == 0)
          Text(
            'Nobody has joined yet.',
            style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
          )
        else
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              ...seated.map((p) => _Seat(player: p, isHost: p.isHost)),
              ...List.generate(empties, (_) => const _Seat()),
            ],
          ),
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  final ParticipantModel? player;
  final bool isHost;

  const _Seat({this.player, this.isHost = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = player;

    if (p == null) {
      return SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.border, width: 1.5),
              ),
              child: Icon(Icons.add_rounded,
                  size: 20, color: colors.textSecondary),
            ),
            const SizedBox(height: 5),
            Text(
              'Open',
              style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                backgroundImage: p.avatar?.trim().isNotEmpty == true
                    ? NetworkImage(p.avatar!)
                    : null,
                child: p.avatar?.trim().isNotEmpty == true
                    ? null
                    : Text(
                        p.initials,
                        style: TextStyle(
                          color: colors.brandText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (isHost)
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.background, width: 1.5),
                    ),
                    child: const Text(
                      'HOST',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            p.name.trim().isEmpty ? 'Player' : p.name.trim().split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Venue extends StatelessWidget {
  final GameModel game;

  const _Venue({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (game.groundName == null) return const SizedBox.shrink();

    final canRoute = MapLinks.directionsUrl(
          latitude: game.groundLatitude,
          longitude: game.groundLongitude,
        ) !=
        null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(title: 'Where'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_rounded, size: 20, color: colors.brandText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.groundName!,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        if ((game.groundAddress ?? game.locationLabel)
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            game.groundAddress ?? game.locationLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (canRoute || game.groundId != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (canRoute)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => MapLinks.openDirections(
                            latitude: game.groundLatitude,
                            longitude: game.groundLongitude,
                          ),
                          icon: const Icon(Icons.directions_rounded, size: 17),
                          label: const Text('Directions'),
                        ),
                      ),
                    if (canRoute && game.groundId != null)
                      const SizedBox(width: 10),
                    if (game.groundId != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/grounds/${game.groundId}'),
                          icon: const Icon(Icons.storefront_rounded, size: 17),
                          label: const Text('Venue'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Why this is not just a booking.
///
/// A stranger about to pay a share of somebody else's slot needs to be told,
/// once, how the money and the seat actually work — it is the part of the
/// product nobody arrives already understanding.
class _HowItWorks extends StatelessWidget {
  final GameModel game;

  const _HowItWorks({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 17, color: colors.brandText),
              const SizedBox(width: 8),
              Text(
                'How an open game works',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Point(
            icon: Icons.event_available_rounded,
            text: '${game.hostName ?? 'The host'} has already booked the slot. '
                'Joining takes one of the open seats.',
          ),
          _Point(
            icon: Icons.currency_rupee_rounded,
            text: game.entryFee == null
                ? 'The host has not set a price for this slot yet.'
                : 'The booking total is split across '
                    '${game.maxPlayers} seats — ${game.formattedFee} each, '
                    'settled with the host at the ground.',
          ),
          const _Point(
            icon: Icons.groups_2_rounded,
            text: 'Turn up on time. Dropping out frees your seat for someone '
                'else, so do it early if plans change.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool last;

  const _Point({required this.icon, required this.text, this.last = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: colors.textSecondary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? trailing;

  const _Section({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
      ],
    );
  }
}

// ── The one action ────────────────────────────────────────────────────────────

/// Price on the left, one verb on the right.
///
/// Which verb depends on where the viewer stands, and every one of them
/// disables itself while its request is in flight — a second tap on "Join"
/// would come back 409 and read to a player as the app losing their seat.
class _GameBottomBar extends ConsumerWidget {
  final GameModel game;

  const _GameBottomBar({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final busy = ref.watch(gameActionsProvider).isBusyFor(game.id);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  game.entryFee == null ? 'Your share' : 'Per player',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
                Text(
                  game.formattedFee,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  game.entryFee == null
                      ? 'Price on request'
                      : 'Pay the host at the ground',
                  style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _Cta(game: game, busy: busy),
        ],
      ),
    );
  }
}

class _Cta extends ConsumerWidget {
  final GameModel game;
  final bool busy;

  const _Cta({required this.game, required this.busy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (game.isHost) {
      if (game.isPast) return _Static(label: game.statusLabel);
      return SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: busy ? null : () => _cancel(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            minimumSize: const Size(140, 52),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.error),
                )
              : const Text('Cancel game'),
        ),
      );
    }

    if (game.isJoined) {
      if (game.isPast) return _Static(label: game.statusLabel);
      return SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: busy ? null : () => _leave(context, ref),
          style: OutlinedButton.styleFrom(minimumSize: const Size(150, 52)),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.check_circle_rounded,
                  size: 18, color: colors.successText),
          label: Text(busy ? 'Leaving…' : "You're in · Leave"),
        ),
      );
    }

    if (!game.isOpen) return _Static(label: game.statusLabel);

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: busy ? null : () => _join(context, ref),
        style: ElevatedButton.styleFrom(minimumSize: const Size(150, 52)),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.onPrimary),
              )
            : const Text('Join game'),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(gameActionsProvider).isBusy) return;
    try {
      await ref.read(gameActionsProvider.notifier).join(game.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text("You're in. See you at the ground.")));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e,
              fallback: 'Could not join this game. Please try again.')),
          backgroundColor: AppColors.error,
        ));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: 'Leave this game?',
      body: 'Your seat opens up for someone else. You can join again if it '
          'is still free.',
      confirmLabel: 'Leave game',
    );
    if (!confirmed || !context.mounted) return;
    if (ref.read(gameActionsProvider).isBusy) return;
    try {
      await ref.read(gameActionsProvider.notifier).leave(game.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('You left the game.')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e,
              fallback: 'Could not leave this game. Please try again.')),
          backgroundColor: AppColors.error,
        ));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: 'Call off this game?',
      body: 'Everyone who joined is told. Your booking stays — only the open '
          'game is closed.',
      confirmLabel: 'Cancel game',
    );
    if (!confirmed || !context.mounted) return;
    if (ref.read(gameActionsProvider).isBusy) return;
    try {
      await ref.read(gameActionsProvider.notifier).cancel(game.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Game cancelled. Players notified.')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e,
              fallback: 'Could not cancel this game. Please try again.')),
          backgroundColor: AppColors.error,
        ));
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// A state, not a button — a disabled CTA invites a tap that cannot succeed.
class _Static extends StatelessWidget {
  final String label;

  const _Static({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _DetailShimmer extends StatelessWidget {
  const _DetailShimmer();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppBackButton(fallbackRoute: '/games'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [GameCardShimmer(), GameCardShimmer()],
            ),
          ),
        ],
      ),
    );
  }
}
