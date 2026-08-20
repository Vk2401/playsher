import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version_model.dart';
import '../providers/app_version_provider.dart';
import 'update_required_dialog.dart';

/// Shows the update prompt whenever the app is opened.
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
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _showing = false;
  DateTime? _lastPromptClosed;

  /// Tapping "Update now" sends the user to the store, which backgrounds the
  /// app; coming straight back would otherwise fire the prompt again and read
  /// as a loop. Long enough to absorb that round trip, short enough that
  /// genuinely reopening the app still prompts.
  static const _reprompCooldown = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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

  Future<void> _maybePrompt(AppVersionCheck check) async {
    if (_showing || !check.shouldPrompt) return;
    _showing = true;

    // Wait for the first frame so there is a Navigator to host the dialog.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _showing = false;
      return;
    }

    await UpdateRequiredDialog.show(context, check);
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
