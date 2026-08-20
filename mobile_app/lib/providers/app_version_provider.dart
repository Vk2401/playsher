import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api_client.dart';
import '../models/app_version_model.dart';

/// The version of the build actually installed on this device, e.g. "1.0.0".
///
/// Read from the platform package rather than a constant in the source, so it
/// can never drift from what the store actually shipped.
final installedVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Asks the API whether this build is still good.
///
/// Fails silent by design. An update nudge is not worth a red error screen on
/// launch, and a check that cannot complete — offline, server down, an
/// unexpected payload — must never be the reason someone can't open the app.
/// Every failure path resolves to [AppVersionCheck.none], which prompts nothing.
final appVersionCheckProvider = FutureProvider<AppVersionCheck>((ref) async {
  // Web and desktop have no store to send anyone to.
  if (!(Platform.isAndroid || Platform.isIOS)) return AppVersionCheck.none;

  try {
    final version = await ref.watch(installedVersionProvider.future);
    final res = await ApiClient.checkAppVersion(
      platform: Platform.isIOS ? 'ios' : 'android',
      version: version,
    );
    final data = res['data'];
    if (data is! Map<String, dynamic>) return AppVersionCheck.none;
    return AppVersionCheck.fromJson(data);
  } catch (_) {
    return AppVersionCheck.none;
  }
});
