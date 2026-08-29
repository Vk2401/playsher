import 'package:flutter/material.dart';
import '../core/animations.dart';
import '../core/app_colors.dart';
import '../models/game_model.dart';
import 'player_stack.dart';
import 'sport_glyph.dart';

/// One open game in the Discover feed.
///
/// The card is built around the three questions a player asks in order — *what
/// sport and when*, *where*, *is there still room and what does it cost* — so
/// the layout is a sport-tinted header rail, a venue line, the squad, and a
/// price/CTA footer. The sport's own hue carries the header, which is what
/// makes a cricket game scannable from a football one without reading a word.
///
/// [compact] drops the squad rail and the fill bar for a narrower context (the
/// home screen's horizontal strip); everything else is shared, so the two never
/// drift apart. Extending rather than copying is the rule — see `GroundCard`'s
/// `wide` flag.
class GameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback? onTap;

  /// The join action. When null the footer shows the game's state instead of a
  /// button — a card in "My games" has nothing to join.
  final VoidCallback? onJoin;

  /// Spins the join button and disables it. Bound to the notifier's in-flight
  /// flag, never to a local bool.
  final bool isJoining;

  final bool compact;

  const GameCard({
    super.key,
    required this.game,
    this.onTap,
    this.onJoin,
    this.isJoining = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = AppColors.sportTint(game.sportName ?? '');

    return AppAnimations.tapScale(
      onTap: onTap,
      child: Opacity(
        // A played or cancelled game stays legible but stops competing with
        // the ones you can still join.
        opacity: game.isPast ? 0.72 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: game.isFillingFast
                  ? AppColors.warning.withValues(alpha: 0.55)
                  : colors.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One spoken summary for the whole card rather than a dozen
              // fragments — but only over the descriptive half. The join
              // button below stays its own focusable node, so an exclusion
              // here would put it out of a screen reader's reach.
              Semantics(
                button: onTap != null,
                label: '${game.displayTitle}. ${game.sportName ?? 'Game'}, '
                    '${game.levelLabel.isEmpty ? 'any level' : game.levelLabel}. '
                    '${game.whenLabel}. '
                    '${game.groundName ?? 'Venue to be confirmed'}. '
                    '${game.spotsLabel}.',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(game: game, tint: tint),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MetaLine(
                            icon: Icons.place_outlined,
                            text: [game.groundName, game.locationLabel]
                                .whereType<String>()
                                .where((s) => s.trim().isNotEmpty)
                                .join(' · '),
                          ),
                          const SizedBox(height: 4),
                          _MetaLine(
                            icon: Icons.schedule_rounded,
                            text: '${game.dayLabel} · ${game.timeLabel}',
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 12),
                            _Squad(game: game),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: 12),
                    _Footer(
                      game: game,
                      onJoin: onJoin,
                      isJoining: isJoining,
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

/// The sport-tinted strip: sport, level, and whatever is urgent about this game.
class _Header extends StatelessWidget {
  final GameModel game;
  final Color tint;

  const _Header({required this.game, required this.tint});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final urgency = _urgency(game);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tint.withValues(alpha: 0.16),
            tint.withValues(alpha: 0.02),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          SportGlyph(name: game.sportName ?? '', size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              game.sportName ?? 'Game',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (game.levelLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            _Dot(color: colors.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                game.levelLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (urgency != null) _UrgencyPill(urgency: urgency),
        ],
      ),
    );
  }
}

/// What is worth shouting about this game, if anything.
///
/// One pill, not three: a game that is both nearly full and starting soon still
/// only gets the more actionable of the two, because a header carrying three
/// competing badges carries none.
({String label, IconData icon, Color color})? _urgency(GameModel game) {
  if (game.isCancelled) {
    return (label: 'Cancelled', icon: Icons.cancel_rounded, color: AppColors.error);
  }
  if (game.isCompleted) {
    return (label: 'Played', icon: Icons.done_all_rounded, color: AppColors.neutral);
  }
  if (game.isInProgress) {
    return (label: 'Playing now', icon: Icons.sports_rounded, color: AppColors.info);
  }
  if (game.isFull) {
    return (label: 'Full', icon: Icons.group_rounded, color: AppColors.neutral);
  }
  if (game.isFillingFast) {
    // The seat line below already spells out "Last spot"; the pill counts
    // rather than repeating it word for word.
    return (
      label: '${game.spotsLeft} left',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.warning,
    );
  }
  final countdown = game.countdownLabel;
  if (countdown != null && countdown.startsWith('Starts in') &&
      !countdown.contains('days')) {
    return (label: countdown, icon: Icons.bolt_rounded, color: AppColors.info);
  }
  if (game.isPrivate) {
    return (label: 'Invite only', icon: Icons.lock_outline_rounded, color: AppColors.neutral);
  }
  return null;
}

class _UrgencyPill extends StatelessWidget {
  final ({String label, IconData icon, Color color}) urgency;

  const _UrgencyPill({required this.urgency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: urgency.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The glyph is what makes the state readable without colour.
          Icon(urgency.icon, size: 12, color: urgency.color),
          const SizedBox(width: 4),
          Text(
            urgency.label,
            style: TextStyle(
              color: urgency.color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// Who is going, and how much room is left.
class _Squad extends StatelessWidget {
  final GameModel game;

  const _Squad({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tight = game.isFillingFast;

    return Row(
      children: [
        PlayerStack(
          players: game.participants,
          emptySlots: game.spotsLeft,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                game.spotsLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tight ? AppColors.warning : colors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: game.fillRate.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation(
                    tight ? AppColors.warning : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${game.currentPlayers}/${game.maxPlayers}',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Price on the left, the one action on the right.
class _Footer extends StatelessWidget {
  final GameModel game;
  final VoidCallback? onJoin;
  final bool isJoining;

  const _Footer({
    required this.game,
    required this.onJoin,
    required this.isJoining,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                game.formattedFee,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                game.entryFee == null ? 'Price on request' : 'per player',
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _Action(game: game, onJoin: onJoin, isJoining: isJoining),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final GameModel game;
  final VoidCallback? onJoin;
  final bool isJoining;

  const _Action({
    required this.game,
    required this.onJoin,
    required this.isJoining,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Already in it, hosting it, or it is over: state, not a button. A disabled
    // button here would invite a tap that can never succeed.
    if (game.isHost || game.isJoined || onJoin == null || !game.isOpen) {
      final label = game.isHost
          ? "You're hosting"
          : game.isJoined
              ? "You're in"
              : game.statusLabel;
      final icon = game.isHost
          ? Icons.workspace_premium_rounded
          : game.isJoined
              ? Icons.check_circle_rounded
              : Icons.info_outline_rounded;
      final tone = game.isHost || game.isJoined
          ? colors.successText
          : colors.textSecondary;

      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tone),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: tone,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton(
        // Disabled while the request is in flight — this is the double-submit
        // guard, not just a spinner.
        onPressed: isJoining ? null : onJoin,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          minimumSize: const Size(88, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isJoining
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              )
            : const Text('Join'),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
