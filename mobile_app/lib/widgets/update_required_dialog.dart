import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../models/app_version_model.dart';

/// The "please update" prompt.
///
/// Two shapes from one widget, because the difference is one of degree:
/// * [AppVersionCheck.updateRequired] — the build is retired. No dismiss, no
///   back button, no barrier tap. The user updates or leaves.
/// * [AppVersionCheck.updateAvailable] — a nudge. "Later" closes it, and the
///   caller remembers not to ask again this session.
///
/// Returns true when the user asked to update, false when they dismissed.
class UpdateRequiredDialog extends StatelessWidget {
  final AppVersionCheck check;

  const UpdateRequiredDialog({super.key, required this.check});

  /// Shows the dialog. Forced updates are non-dismissible in all three ways a
  /// Flutter dialog can be dismissed: barrier tap, system back, and the absence
  /// of a close control.
  static Future<bool> show(BuildContext context, AppVersionCheck check) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !check.updateRequired,
      builder: (_) => UpdateRequiredDialog(check: check),
    );
    return result ?? false;
  }

  Future<void> _openStore(BuildContext context) async {
    final url = check.updateUrl;
    if (url == null || url.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Navigator.of(context).pop(true);
      return;
    }

    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;

    // A forced dialog must stay up: the user has left for the store but has not
    // updated yet, and closing here would hand them the retired app again.
    if (!check.updateRequired && launched) Navigator.of(context).pop(true);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store. Please update manually.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final forced = check.updateRequired;
    final notes = check.releaseNotes?.trim();

    return PopScope(
      // Blocks the Android system back button on a forced update — without
      // this the dialog is dismissible whatever barrierDismissible says.
      canPop: !forced,
      child: AlertDialog(
        backgroundColor: colors.card,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppColors.onPrimary,
                size: 22,
                semanticLabel: 'App update',
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                forced ? 'Update required' : 'Update available',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              forced
                  ? 'This version of Playsher is no longer supported. Update to keep booking.'
                  : 'A newer version of Playsher is available with the latest improvements.',
              style: TextStyle(color: colors.textSecondary, height: 1.45),
            ),
            if (check.latestVersion != null) ...[
              const SizedBox(height: 12),
              Text(
                'Version ${check.latestVersion}',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.input,
                  borderRadius: BorderRadius.circular(12),
                ),
                // Release notes are admin-authored and can run long; cap the
                // height and scroll rather than overflowing the dialog.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: Text(
                      notes,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          // Only an optional update offers a way out.
          if (!forced)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 44),
                foregroundColor: colors.textSecondary,
              ),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () => _openStore(context),
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Update now'),
          ),
        ],
      ),
    );
  }
}
