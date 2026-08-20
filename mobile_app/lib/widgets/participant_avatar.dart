import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/participant_model.dart';

class ParticipantAvatar extends StatelessWidget {
  final ParticipantModel? participant;
  final double size;

  const ParticipantAvatar({
    super.key,
    this.participant,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Empty slot
    if (participant == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.border,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: size * 0.4,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: participant!.avatar != null
                  ? NetworkImage(participant!.avatar!)
                  : null,
              child: participant!.avatar == null
                  ? Text(
                      participant!.initials,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: size * 0.35,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            if (participant!.isHost)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'HOST',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.card, width: 2),
                  ),
                  child: const Icon(Icons.check,
                      size: 10, color: AppColors.onPrimary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size + 8,
          child: Text(
            participant!.name.split(' ').first,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
