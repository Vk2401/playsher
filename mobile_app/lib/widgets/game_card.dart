import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/game_model.dart';
import 'progress_bar.dart';
import 'status_badge.dart';

class GameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const GameCard({
    super.key,
    required this.game,
    this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: host + sport tag
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: game.hostAvatar != null
                      ? NetworkImage(game.hostAvatar!)
                      : null,
                  child: game.hostAvatar == null
                      ? Text(
                          (game.hostName ?? 'H')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.gameName ?? game.groundName ?? 'Game',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'by ${game.hostName ?? 'Unknown'}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (game.sportName != null)
                  StatusBadge(
                    label: game.sportName!,
                    color: AppColors.accent.withValues(alpha: 0.15),
                    textColor: AppColors.accent,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Date/time + level
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  game.date,
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time,
                    size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  game.time,
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 12),
                ),
                const Spacer(),
                if (game.skillLevel.isNotEmpty)
                  StatusBadge.gameLevel(game.skillLevel),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ProgressBar(
              value: game.fillRate,
              label:
                  '${game.currentPlayers}/${game.maxPlayers} players joined',
            ),
            const SizedBox(height: 12),
            // Bottom: price + join
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  game.formattedFee,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: game.isFull ? null : onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      game.isFull ? 'Full' : 'Join',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
