import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/app_version_model.dart';
import '../providers/app_version_provider.dart';
import '../router.dart';
import 'update_required_dialog.dart';

/// Shows the update prompt when the app is opened.
///
/// It wraps the router rather than living in a screen because a retired build
/// must be blocked everywhere — including the login screen, which a user with
/// an expired token sees first. The check itself is warmed on the splash screen
/// so the answer is usually already in hand by the time a real screen mounts.
///
/// Deliberately does not gate rendering on the check: the app draws
/// immediately and the dialog arrives when the answer does. Holding the first
/// frame behind a network call would turn a slow connection into a blank
/// screen, which is a worse failure than a late prompt.
///
/// ── How often each kind prompts ─────────────────────────────────────────────
///
/// An **optional** nudge shows **once per launch, on the home screen only**.
/// It used to fire from a router listener, so every navigation re-raised it and
/// "Later" bought nothing — the nag was constant. [_optionalPromptedThisLaunch]
/// is static on purpose: a cold start is a new isolate and resets it, while
/// resuming from the recents list keeps it, which is exactly the rule asked for
/// — dismiss it and it stays gone until the app is genuinely closed and
/// reopened. Home is the only place it appears, so it never lands on top of a
/// booking or a payment.
///
/// A **required** update is not a nudge and is not rate-limited. The build is
/// retired; it is blocked on whatever screen the user reaches, and re-checked on
/// every resume in case an admin raises the minimum while the app sits in the
/// background.
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  /// Clears the once-per-launch memory of the optional nudge.
  ///
  /// A cold start does this for free by starting a new isolate. Tests run many
  /// "launches" inside one isolate, so they need to say it explicitly.
  @visibleForTesting
  static void resetLaunchState() =>
      _AppUpdateGateState._optionalPromptedThisLaunch = false;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _showing = false;
  DateTime? _lastPromptClosed;

  /// Whether the optional nudge has already been shown in this process.
  ///
  /// Static, so it survives this widget being rebuilt or remounted but dies
  /// with the isolate — which makes "until the app is fully closed and
  /// reopened" the natural lifetime, with no storage to write or migrate.
  static bool _optionalPromptedThisLaunch = false;

  /// Tapping "Update now" sends the user to the store, which backgrounds the
  /// app; coming straight back would otherwise fire the prompt again and read
  /// as a loop. Long enough to absorb that round trip, short enough that
  /// genuinely reopening the app still prompts.
  static const _reprompCooldown = Duration(seconds: 20);

  GoRouter? _router;

  void _onRouteChanged() {
    if (!mounted || _showing) return;
    final check = ref.read(appVersionCheckProvider).valueOrNull;
    if (check != null && check.shouldPrompt) _maybePrompt(check);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Landing on home is the cue to prompt, for a check that resolved while
    // splash was still on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = ref.read(routerProvider);
      router.routerDelegate.addListener(_onRouteChanged);
      _router = router;
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_showing) return;

    final closed = _lastPromptClosed;
    if (closed != null && DateTime.now().difference(closed) < _reprompCooldown) {
      return;
    }

    // Re-ask the API rather than replaying a cached answer: the thresholds may
    // have been raised by an admin while the app sat in the background.
    ref.invalidate(appVersionCheckProvider);
  }

  /// Routes that are on their way somewhere else. A dialog raised over any of
  /// these is torn down with the route a moment later — which is exactly what
  /// made the prompt flash during splash and disappear.
  static const _transientRoutes = {
    '/splash',
    '/onboarding',
    '/location',
  };

  /// The only screen an optional nudge is allowed to appear on.
  static const _homeRoute = '/home';

  String get _currentPath => ref
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  bool get _onASettledScreen => !_transientRoutes.contains(_currentPath);

  /// Gives back the once-per-launch claim when a prompt was set up but never
  /// actually reached the screen. Without this, a nudge that lost its navigator
  /// would count as shown and never appear again this launch.
  void _abandon(AppVersionCheck check) {
    _showing = false;
    if (!check.updateRequired) _optionalPromptedThisLaunch = false;
  }

  Future<void> _maybePrompt(AppVersionCheck check) async {
    if (_showing || !check.shouldPrompt) return;

    // Splash resolves the check before it navigates away, so without this the
    // dialog opens over splash and dies with it. The router listener below
    // brings us back the moment the app lands on a real screen.
    if (!_onASettledScreen) return;

    // A nudge is once per launch, and only on home. A required update ignores
    // both rules: the build is retired wherever the user happens to be.
    if (!check.updateRequired) {
      if (_optionalPromptedThisLaunch) return;
      if (_currentPath != _homeRoute) return;
      // Claimed before the await below, so two callbacks landing in the same
      // frame — the router listener and the provider listener both fire on
      // arrival at home — cannot each open a dialog.
      _optionalPromptedThisLaunch = true;
    }

    _showing = true;

    // Wait for the first frame so the router's navigator exists.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _abandon(check);
      return;
    }

    // This widget's own context is above the router's Navigator — showing a
    // dialog with it throws. Host the dialog on the root navigator instead.
    final navigator = rootNavigatorKey.currentContext;
    if (navigator == null || !navigator.mounted) {
      // No navigator yet; the next check (or an app resume) will retry.
      _abandon(check);
      return;
    }

    await UpdateRequiredDialog.show(navigator, check);
    if (!mounted) return;

    _showing = false;
    _lastPromptClosed = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppVersionCheck>>(appVersionCheckProvider,
        (_, next) {
      final check = next.valueOrNull;
      if (check != null) _maybePrompt(check);
    });

    // Covers the case where the check resolved before this widget mounted —
    // which is the norm now that the splash screen warms it.
    final check = ref.watch(appVersionCheckProvider).valueOrNull;
    if (check != null && check.shouldPrompt) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybePrompt(check));
    }

    return widget.child;
  }
}
