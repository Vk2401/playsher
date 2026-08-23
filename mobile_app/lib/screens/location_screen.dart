import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../providers/location_provider.dart';
import '../widgets/location_hero.dart';

/// The one thing the app asks for before it starts: where the user is.
///
/// It asks by showing what it buys — a ground on a map, then three plain
/// sentences — rather than by explaining a permission. Skipping is a first
/// class answer and sits under the CTA, not hidden behind it.
class LocationScreen extends ConsumerStatefulWidget {
  final bool fromRegister;
  const LocationScreen({super.key, this.fromRegister = false});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _loading = false;
  String? _error;

  /// Delegates to [userLocationProvider] rather than talking to the plugin
  /// here: the home screen reads the same notifier, so a grant made on this
  /// screen shows up as distances the moment the user lands back on Home.
  Future<void> _requestLocation() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final notifier = ref.read(userLocationProvider.notifier);
    final granted = await notifier.requestPermission();
    if (!mounted) return;

    if (granted) {
      context.go('/home');
      return;
    }

    setState(() {
      _loading = false;
      _error = switch (ref.read(userLocationProvider).permission) {
        LocationPermissionState.deniedForever =>
          'Location is blocked for ${AppConstants.appName}. Enable it in app settings.',
        LocationPermissionState.serviceDisabled =>
          'Location services are off. Please switch on GPS and try again.',
        LocationPermissionState.denied => 'Location permission denied.',
        _ => 'Could not get your location. Please try again.',
      };
    });
  }

  void _skip() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;

    return Scaffold(
      backgroundColor: frame.page,
      // The reasons scroll; the two answers do not. Everything in one scroll
      // view left the page top-aligned, so on a tall phone the slack fell
      // *below* the buttons and they floated in the middle of nothing. The
      // actions are the last child of a Column whose middle is Expanded, so
      // they sit on the bottom edge whatever the content above them does.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocationHero(),
                    const SizedBox(height: 16),

                    // The greeting only lands the first time; coming back to
                    // this screen later, it is a request and says so.
                    if (widget.fromRegister)
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                            color: frame.ink,
                          ),
                          children: [
                            const TextSpan(text: 'Welcome to '),
                            TextSpan(
                              text: AppConstants.appName,
                              style: TextStyle(color: colors.brandText),
                            ),
                            const TextSpan(text: '! 👋'),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Enable Location',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.5,
                          color: frame.ink,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'Allow ${AppConstants.appName} to use your location to '
                      'show nearby sports grounds, suggest fields in your '
                      'city, and give you better recommendations.',
                      style: TextStyle(
                          fontSize: 15, height: 1.45, color: frame.body),
                    ),
                    const SizedBox(height: 16),

                    const _Benefit(
                      icon: Icons.explore_rounded,
                      title: 'Find grounds near you',
                      detail: 'Discover the best turfs and courts closest to '
                          'your location.',
                    ),
                    const SizedBox(height: 10),
                    const _Benefit(
                      icon: Icons.sports_soccer_rounded,
                      title: 'Discover local games',
                      detail: 'Join matches and events happening around you.',
                    ),
                    const SizedBox(height: 10),
                    const _Benefit(
                      icon: Icons.thumb_up_rounded,
                      title: 'Get personalised suggestions',
                      detail: 'Receive recommendations tailored to your '
                          'favourite sports and time.',
                    ),
                  ],
                ),
              ),
            ),

            // Out here with the buttons rather than at the end of the scroll,
            // so a refusal is on screen even when the reasons above it are
            // scrolled away.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    _PermissionError(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  _AllowButton(loading: _loading, onPressed: _requestLocation),
                  const SizedBox(height: 2),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _skip,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: frame.body,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One reason the app is asking, as a title and the sentence behind it.
class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: frame.tile,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: Icon(icon, size: 17, color: AppColors.onPrimary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: frame.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style:
                      TextStyle(fontSize: 13.5, height: 1.4, color: frame.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the request did not land, in a sentence the user can act on.
class _PermissionError extends StatelessWidget {
  const _PermissionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllowButton extends StatelessWidget {
  const _AllowButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        // Disabled while the platform dialog is up: a second tap would queue
        // another request behind the one already on screen.
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.onPrimary),
              )
            else
              const Icon(Icons.my_location_rounded, size: 21),
            const SizedBox(width: 12),
            // Flexible: at a large text scale the label is wider than the
            // button, and a CTA that overflows is a bar across the page.
            Flexible(
              child: Text(
                loading ? 'Getting location…' : 'Allow Location Access',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
