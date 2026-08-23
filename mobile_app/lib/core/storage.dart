import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Tokens ────────────────────────────────────────────────────────────────
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(
        key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  static Future<void> updateAccessToken(String token) =>
      _storage.write(key: AppConstants.accessTokenKey, value: token);

  // ── User ──────────────────────────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: AppConstants.userKey, value: jsonEncode(user));

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: AppConstants.userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Onboarding ────────────────────────────────────────────────────────────
  static Future<bool> isOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_seen') ?? false;
  }

  static Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
  }

  // ── Theme Mode ────────────────────────────────────────────────────────────
  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to `system` so a first launch honours the device setting
    // instead of forcing dark on a light-mode phone.
    final value = prefs.getString('theme_mode') ?? 'system';
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  // ── City / Location ──────────────────────────────────────────────────────
  static Future<String?> getCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_city');
  }

  static Future<void> setCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_city', city);
  }

  /// Last fix we managed to read, cached so a cold start can show distances
  /// immediately instead of blank-then-pop once the GPS answers.
  static Future<void> setLastLatLng(double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_latitude', latitude);
    await prefs.setDouble('last_longitude', longitude);
  }

  static Future<(double, double)?> getLastLatLng() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble('last_latitude');
    final longitude = prefs.getDouble('last_longitude');
    if (latitude == null || longitude == null) return null;
    return (latitude, longitude);
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  /// The preference keys that belong to the *account*, not the device.
  ///
  /// The rest of the prefs — `onboarding_seen`, `theme_mode` — are the phone's
  /// own settings and survive a logout on purpose: whoever signs in next is
  /// still using the same handset, and re-running onboarding or resetting
  /// their theme is not part of switching accounts.
  static const _accountPrefKeys = <String>[
    'user_city',
    'last_latitude',
    'last_longitude',
  ];

  /// Erase everything the signed-in account left on the device.
  ///
  /// Secure storage holds the tokens and the cached profile; the account's
  /// city and last known position live in SharedPreferences and used to
  /// survive a logout, so the next user inherited the previous one's city.
  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    for (final key in _accountPrefKeys) {
      await prefs.remove(key);
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
