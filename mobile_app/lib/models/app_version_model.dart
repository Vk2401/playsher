/// What the API says about the build the user is running.
///
/// Two independent outcomes, and the difference matters:
///   [updateAvailable] — a newer build exists; nudge, but let it be dismissed.
///   [updateRequired]  — this build is below the minimum the platform supports
///                       and must be blocked.
///
/// Every field defaults to the harmless value, so a malformed or partial
/// payload produces "nothing to do" rather than locking someone out of a
/// working app.
class AppVersionCheck {
  final bool updateAvailable;
  final bool updateRequired;
  final String? latestVersion;
  final String? minSupportedVersion;
  final String? updateUrl;
  final String? releaseNotes;

  const AppVersionCheck({
    this.updateAvailable = false,
    this.updateRequired = false,
    this.latestVersion,
    this.minSupportedVersion,
    this.updateUrl,
    this.releaseNotes,
  });

  /// The state to fall back to whenever the check cannot be trusted — offline,
  /// a server error, an unreadable payload. Never prompts.
  static const none = AppVersionCheck();

  factory AppVersionCheck.fromJson(Map<String, dynamic> json) =>
      AppVersionCheck(
        updateAvailable: json['update_available'] as bool? ?? false,
        updateRequired: json['update_required'] as bool? ?? false,
        latestVersion: json['latest_version'] as String?,
        minSupportedVersion: json['min_supported_version'] as String?,
        updateUrl: json['update_url'] as String?,
        releaseNotes: json['release_notes'] as String?,
      );

  /// True when the user should be shown something at all.
  bool get shouldPrompt => updateRequired || updateAvailable;
}
