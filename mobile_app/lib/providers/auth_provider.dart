import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/storage.dart';
import '../models/user_model.dart';
import 'session_scope.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    // Register 401 callback so interceptor can force logout
    ApiClient.onSessionExpired = _forceLogout;
    _loadUser();
  }

  final Ref _ref;

  Future<void> _loadUser() async {
    final token = await StorageService.getAccessToken();
    final data = await StorageService.getUser();
    // Only restore session if we have BOTH a real token and user data
    if (data != null &&
        token != null &&
        token.isNotEmpty &&
        !token.startsWith('mock_')) {
      state = state.copyWith(user: UserModel.fromJson(data));
    } else if (data != null && token == null) {
      // Stale user data without token — clear it
      await StorageService.clearAll();
    }
  }

  /// Called by ApiClient interceptor when a 401 is received.
  ///
  /// The guard is load-bearing, not tidiness: clearing the caches makes
  /// whatever is still on screen refetch, those refetches now have no token
  /// and come back 401, and each one calls this again. Returning early once
  /// the session is already gone is what stops that from looping.
  void _forceLogout() {
    if (!state.isAuthenticated) return;
    if (kDebugMode) debugPrint('[Auth] Session expired — forcing logout');
    state = const AuthState();
    invalidateUserScopedProviders(_ref);
  }

  /// Sends OTP. Navigates to OTP screen regardless of API result.
  Future<void> sendOtp(String mobile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiClient.sendOtp(mobile);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] sendOtp error: $e');
      // Proceed anyway — user still goes to OTP screen
    }
    state = state.copyWith(isLoading: false);
  }

  /// Returns true = existing user (go home), false = new user (go register).
  /// Throws on real API errors (does NOT silently mock).
  Future<bool> verifyOtp(String mobile, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.verifyOtp(mobile, otp);
      // playsher-api returns: { success, message, data: { ... } }
      if (kDebugMode) {
        debugPrint('[Auth] verifyOtp response keys: ${res.keys.toList()}');
      }

      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) {
        state = state.copyWith(
          isLoading: false,
          error:
              res['message']?.toString() ?? 'Unexpected response from server',
        );
        return false;
      }

      // New user: { data: { new_user: true, mobile: "..." } }
      if (data['new_user'] == true) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      // Existing user: { data: { access_token, refresh_token, user } }
      final accessToken = data['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No token received from server',
        );
        return false;
      }

      await _saveSession(data);
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final errorMsg = _extractError(e);
      if (kDebugMode) debugPrint('[Auth] verifyOtp DioException: $errorMsg');
      state = state.copyWith(isLoading: false, error: errorMsg);
      // Re-throw so OTP screen can show the error
      throw Exception(errorMsg);
    } catch (e) {
      final errorMsg = apiErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMsg);
      throw Exception(errorMsg);
    }
  }

  Future<void> completeRegistration(String name, String mobile,
      {String? email}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res =
          await ApiClient.completeRegistration(name, mobile, email: email);
      // playsher-api returns: { success, data: { access_token, refresh_token, user } }
      final data = res['data'] as Map<String, dynamic>?;

      if (data != null) {
        await _saveSession(data);
      }

      // If no user in response data, build one from the inputs
      if (data?['user'] == null) {
        final stored = await StorageService.getUser();
        final userJson = {
          ...?stored,
          'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          'mobile': mobile,
        };
        await StorageService.saveUser(userJson);
        state = state.copyWith(
          user: UserModel.fromJson(userJson),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      final errorMsg = _extractError(e);
      if (kDebugMode) {
        debugPrint('[Auth] completeRegistration error: $errorMsg');
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: apiErrorMessage(e));
      rethrow;
    }
  }

  /// Re-read the profile from the API and refresh cached user state.
  ///
  /// Called after an edit so every screen watching `authProvider` — the home
  /// header, the profile tab, Razorpay's prefill — shows the new values without
  /// needing a sign-out.
  Future<void> refreshUser() async {
    try {
      final res = await ApiClient.getProfile();
      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) return;
      await StorageService.saveUser(data);
      state = state.copyWith(user: UserModel.fromJson(data));
    } catch (e) {
      // A failed refresh must not clear a valid session; the edit already
      // succeeded server-side and the next load will pick it up.
      if (kDebugMode) debugPrint('[Auth] refreshUser failed: $e');
    }
  }

  /// Sign out, and leave nothing of this account behind.
  ///
  /// Dropping the tokens is only half of it. Every provider that answered a
  /// personalised request still holds that answer, so a logout that stops at
  /// storage lets the next sign-in — with a different number — open onto the
  /// previous user's name, bookings and favourites. The state is cleared
  /// before the caches so that any refetch a live screen kicks off finds an
  /// unauthenticated session and stops, rather than bouncing through
  /// [_forceLogout] again.
  Future<void> logout() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      await ApiClient.logout(refreshToken ?? '');
    } catch (_) {}
    state = const AuthState();
    await StorageService.clearAll();
    invalidateUserScopedProviders(_ref);
  }

  /// Save tokens and user from playsher-api response data.
  /// Expects: { access_token, refresh_token, user: { id, name, mobile, email } }
  Future<void> _saveSession(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final userJson = data['user'] as Map<String, dynamic>?;

    if (accessToken != null && accessToken.isNotEmpty) {
      await StorageService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? accessToken,
      );
      if (kDebugMode) debugPrint('[Auth] Session tokens stored');
    }
    if (userJson != null) {
      await StorageService.saveUser(userJson);
      state = state.copyWith(user: UserModel.fromJson(userJson));
      if (kDebugMode) debugPrint('[Auth] User profile stored');
    }
  }

  /// Extract a human-readable error from a DioException
  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          'Request failed';
    }
    if (data is String && data.isNotEmpty) return data;
    if (e.response?.statusCode == 401) return 'Invalid OTP or session expired';
    if (e.response?.statusCode == 422) {
      return 'Validation failed — please check your input';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    ApiClient.onSessionExpired = null;
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
