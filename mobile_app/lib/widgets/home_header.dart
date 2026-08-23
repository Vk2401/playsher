import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../providers/venues_intent_provider.dart';

/// The home screen's hero: a venue photo, darkened, carrying the greeting, the
/// city, the bell, the avatar and the search field.
///
/// The backdrop is a real ground photo rather than an asset, because the app
/// ships no images of its own — [backdropUrl] is the first featured venue, and
/// the gradient underneath is what the header looks like before the list has
/// loaded or when no venue has a photo.
///
/// Everything in here paints with [AppColors.onImage] / [AppColors.brandOnImage]
/// rather than a theme surface: the scrim is dark in both themes, so a
/// brightness-dependent ink would disappear on one of them.
class HomeHeader extends StatelessWidget {
  /// Greeting line, already personalised — "Good afternoon, Vasanth".
  final String greeting;

  /// The city the listings are for.
  final String city;

  /// True while a fresh GPS fix is being resolved, so the chevron becomes a
  /// spinner instead of the row silently doing nothing.
  final bool resolvingCity;

  final int unreadCount;
  final String initials;

  /// Photo behind the header. Null falls back to the gradient alone.
  final String? backdropUrl;

  const HomeHeader({
    super.key,
    required this.greeting,
    required this.city,
    required this.unreadCount,
    required this.initials,
    this.resolvingCity = false,
    this.backdropUrl,
  });

  @override
  Widget build(BuildContext context) {
    // The scrim is dark in both themes, so the clock and battery above it need
    // light glyphs — including on the light theme, where the app-wide style
    // (AppBarTheme.systemOverlayStyle) asks for dark ones. The annotation only
    // applies while this header is the thing under the status bar, so scrolling
    // it away hands the glyphs back to the theme.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Stack(
        children: [
          Positioned.fill(child: _Backdrop(imageUrl: backdropUrl)),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    // Top-aligned: centring put the bell and the avatar between
                    // the two text lines, so neither of them looked attached to
                    // anything. Against the greeting they read as one row.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    greeting,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onImage,
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const _Wave(),
                              ],
                            ),
                            _LocationChip(
                                label: city, resolving: resolvingCity),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _NotificationBell(unread: unreadCount),
                      const SizedBox(width: 4),
                      _ProfileAvatar(initials: initials),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 22),
                child: _SearchField(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The photo, plus the two gradients that make white text safe on top of it:
/// a dark wash over the whole header and a heavier one at the very top where
/// the status-bar clock sits.
class _Backdrop extends StatelessWidget {
  final String? imageUrl;
  const _Backdrop({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Painted first so it also stands in while the photo is decoding.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF04173A), Color(0xFF0A3A72)],
            ),
          ),
        ),
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xE6000821),
                Color(0x99000821),
                Color(0xB3000821),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Not a text field: tapping it opens the venues screen, which owns the real
/// search and every filter. A live field here would have to duplicate them.
///
/// It states an intent before it navigates, so the venues screen arrives with
/// the keyboard already up. Without that, tapping search here only got the user
/// as far as the venues list, where they had to tap search a second time.
class _SearchField extends ConsumerWidget {
  const _SearchField();

  void _go(BuildContext context, WidgetRef ref, VenuesIntent intent) {
    ref.read(venuesIntentProvider.notifier).state = intent;
    context.go('/venues');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Semantics(
      label: 'Search for turfs, sports and venues',
      button: true,
      child: GestureDetector(
        onTap: () => _go(context, ref, VenuesIntent.focusSearch),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: colors.textSecondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search for turfs, sports, venues…',
                  style: TextStyle(fontSize: 14.5, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // The filters half of the field: same screen, but it arrives with
              // the filter sheet already open rather than the keyboard.
              Semantics(
                label: 'Filter venues',
                button: true,
                child: GestureDetector(
                  onTap: () => _go(context, ref, VenuesIntent.openFilters),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.tune_rounded,
                            size: 20, color: AppColors.onPrimary),
                      ),
                    ),
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

/// The city, as a control rather than a label — tapping it goes to the
/// location screen, which is the only way to change it.
class _LocationChip extends StatelessWidget {
  final String label;
  final bool resolving;

  const _LocationChip({required this.label, required this.resolving});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your location, $label. Change it.',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/location'),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 17, color: AppColors.brandOnImage),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onImage,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              if (resolving)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.6, color: AppColors.onImage),
                )
              else
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: AppColors.onImage),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unread;
  const _NotificationBell({required this.unread});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/notifications'),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(width: 46, height: 46),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.onImage.withValues(alpha: 0.18)),
              ),
              child: const Icon(Icons.notifications_outlined,
                  size: 21, color: AppColors.onImage),
            ),
            if (unread > 0)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.onImage, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: AppColors.onImage,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String initials;
  const _ProfileAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your profile',
      button: true,
      child: GestureDetector(
        onTap: () => context.go('/profile'),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.onImage,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A hand that waves once when the header appears.
///
/// Motion is a single 900ms gesture on mount rather than a loop: an emoji
/// waving forever in the corner of every screen is noise, and looping motion
/// is what makes an interface feel restless.
class _Wave extends StatefulWidget {
  const _Wave();

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Two waves out and back, easing to rest rather than snapping.
    _turns = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Respect a viewer who has asked the system for less motion: the hand is
    // still there, it simply does not move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RotationTransition(
        turns: _turns,
        // Rotate about the wrist, not the middle of the glyph.
        alignment: Alignment.bottomLeft,
        child: const Text('\u{1F44B}', style: TextStyle(fontSize: 19)),
      ),
    );
  }
}
