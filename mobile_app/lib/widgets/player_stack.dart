import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/participant_model.dart';

/// The players already in a game, as overlapping avatars.
///
/// A row of faces answers "is anyone actually going?" faster than a number
/// does, which is the question that decides whether a stranger taps Join. The
/// overflow count and the empty seats are drawn in the same rail so the whole
/// squad reads as one object rather than three.
///
/// The stack is decorative — the seat count beside it carries the same fact in
/// words — so it is wrapped in [Semantics] with a single label rather than
/// letting a screen reader walk N unlabelled circles.
class PlayerStack extends StatelessWidget {
  final List<ParticipantModel> players;

  /// Seats nobody has taken. Drawn as dashed-looking outlines after the faces,
  /// capped so a 30-player game does not push the row off screen.
  final int emptySlots;

  final double size;

  /// How many faces to draw before collapsing the rest into "+N".
  final int maxVisible;

  const PlayerStack({
    super.key,
    required this.players,
    this.emptySlots = 0,
    this.size = 32,
    this.maxVisible = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final seated = players
        .where((p) => p.status == 'joined' || p.status == 'accepted')
        .toList();

    final shown = seated.take(maxVisible).toList();
    final overflow = seated.length - shown.length;
    final empties = emptySlots.clamp(0, overflow > 0 ? 0 : 3);

    final overlap = size * 0.32;
    final tiles = <Widget>[
      ...shown.map((p) => _Face(player: p, size: size)),
      if (overflow > 0) _Pill(label: '+$overflow', size: size),
      ...List.generate(empties, (_) => _EmptySeat(size: size)),
    ];

    if (tiles.isEmpty) {
      return Text(
        'Be the first to join',
        style: TextStyle(fontSize: 12, color: colors.textSecondary),
      );
    }

    return Semantics(
      label: seated.isEmpty
          ? 'No players have joined yet'
          : '${seated.length} ${seated.length == 1 ? 'player has' : 'players have'} joined',
      child: ExcludeSemantics(
        child: SizedBox(
          height: size,
          width: tiles.length * (size - overlap) + overlap,
          child: Stack(
            children: [
              for (var i = 0; i < tiles.length; i++)
                Positioned(
                  left: i * (size - overlap),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // A ring in the card's own colour is what separates one
                      // face from the one behind it.
                      border: Border.all(color: colors.card, width: 2),
                    ),
                    child: tiles[i],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  final ParticipantModel player;
  final double size;

  const _Face({required this.player, required this.size});

  @override
  Widget build(BuildContext context) {
    final avatar = player.avatar;
    final hasPhoto = avatar != null && avatar.trim().isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: avatar,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Initials(player: player, size: size),
                errorWidget: (_, __, ___) =>
                    _Initials(player: player, size: size),
              )
            : _Initials(player: player, size: size),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final ParticipantModel player;
  final double size;

  const _Initials({required this.player, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      color: AppColors.primary.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        player.initials,
        style: TextStyle(
          color: colors.brandText,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final double size;

  const _Pill({required this.label, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.input),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  final double size;

  const _EmptySeat({required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.background,
        border: Border.all(color: colors.border),
      ),
      child: Icon(Icons.add_rounded, size: size * 0.44, color: colors.textSecondary),
    );
  }
}
