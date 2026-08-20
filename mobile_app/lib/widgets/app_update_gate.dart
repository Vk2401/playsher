import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version_model.dart';
import '../providers/app_version_provider.dart';
import 'update_required_dialog.dart';

/// Runs the version check once per launch and shows the update prompt over
/// whatever screen the user landed on.
///
/// It wraps the router rather than living in a screen because a retired build
/// must be blocked everywhere — including the login screen, which a user with
/// an expired token sees first.
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

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  /// An optional update is offered once per launch. Re-prompting on every
  /// rebuild would make the app unusable, and re-prompting after "Later"
  /// ignores an answer the user already gave.
  bool _handled = false;
  bool _showing = false;

  Future<void> _maybePrompt(AppVersionCheck check) async {
    if (_handled || _showing || !check.shouldPrompt) return;
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
    // A forced prompt is never "handled" — if it somehow closes, the next
    // rebuild puts it straight back up.
    if (!check.updateRequired) _handled = true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppVersionCheck>>(appVersionCheckProvider,
        (_, next) {
      final check = next.valueOrNull;
      if (check != null) _maybePrompt(check);
    });

    // Covers the case where the check resolved before this widget mounted.
    final check = ref.watch(appVersionCheckProvider).valueOrNull;
    if (check != null && check.shouldPrompt) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybePrompt(check));
    }

    return widget.child;
  }
}
