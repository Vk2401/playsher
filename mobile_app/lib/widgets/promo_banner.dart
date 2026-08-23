import 'package:flutter/material.dart';
import '../core/animations.dart';
import '../core/app_colors.dart';

/// An offer strip, shaped like a torn-off ticket.
///
/// Presentational on purpose: it takes its copy and its code rather than
/// reading a provider, because the coupons endpoint is still a stub and the
/// caller is the only thing that knows which offer is live.
class PromoBanner extends StatelessWidget {
  /// The line before [highlight] — "Flat ".
  final String leading;

  /// The part that carries the offer — "10% OFF". Bolder than the rest.
  final String highlight;

  /// The line after [highlight] — " on first booking!".
  final String trailing;

  /// The coupon the user has to type at checkout.
  final String code;

  final String actionText;
  final VoidCallback onAction;

  const PromoBanner({
    super.key,
    required this.leading,
    required this.highlight,
    required this.trailing,
    required this.code,
    required this.onAction,
    this.actionText = 'Book Now',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = colors.successText;

    return Semantics(
      label: '$leading$highlight$trailing Use code $code. $actionText.',
      button: true,
      excludeSemantics: true,
      child: AppAnimations.tapScale(
        onTap: onAction,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.success.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              const _Perforation(),
              const SizedBox(width: 7),
              Container(
                width: 42,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.successDark,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.confirmation_number_rounded,
                    size: 19, color: AppColors.onImage),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textPrimary,
                          height: 1.25,
                        ),
                        children: [
                          TextSpan(text: leading),
                          TextSpan(
                            text: highlight,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: trailing),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 12.5, color: ink),
                        children: [
                          const TextSpan(text: 'Use code: '),
                          TextSpan(
                            text: code,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Its own tappable so the label is a real 44px target even though
              // the whole strip already answers a tap.
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(84, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: AppColors.successDark,
                    foregroundColor: AppColors.onImage,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    actionText,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dotted tear-line down the left edge. Purely the ticket metaphor, so it
/// carries no semantics of its own.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          6,
          (_) => Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.successDark.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
