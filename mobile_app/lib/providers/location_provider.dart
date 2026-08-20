import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../core/api_client.dart';
import '../core/geo.dart';
import '../core/storage.dart';
import 'city_provider.dart';

/// Why we do or don't have a fix, in the terms the UI needs to answer
/// "should I offer an Enable button, or send them to system settings?".
enum LocationPermissionState {
  /// Not asked yet, or still working it out.
  unknown,

  /// Granted, whether or not a fix has landed yet.
  granted,

  /// Refused once — asking again is allowed.
  denied,

  /// Refused permanently; only app settings can undo it.
  deniedForever,

  /// Permission is fine, the device's location service is switched off.
  serviceDisabled,
}

/// The user's position as far as the app knows it.
class UserLocation {
  final double? latitude;
  final double? longitude;
  final LocationPermissionState permission;

  /// A read is in flight. Kept separate from [hasFix] so the UI can show a
  /// cached distance while a fresher one is on its way.
  final bool resolving;

  const UserLocation({
    this.latitude,
    this.longitude,
    this.permission = LocationPermissionState.unknown,
    this.resolving = false,
  });

  bool get hasFix => Geo.usable(latitude, longitude);

  /// Whether the UI should offer a way to switch location on.
  ///
  /// [LocationPermissionState.unknown] is excluded so the home screen does not
  /// flash a nudge for the frame before the first permission check answers.
  bool get needsPrompt =>
      !hasFix &&
      permission != LocationPermissionState.unknown &&
      permission != LocationPermissionState.granted;

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    LocationPermissionState? permission,
    bool? resolving,
  }) =>
      UserLocation(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        permission: permission ?? this.permission,
        resolving: resolving ?? this.resolving,
      );
}

/// Owns the single location read for the whole app.
///
/// Two entry points, deliberately separate:
///  * [refresh] never prompts. It runs on start-up and on pull-to-refresh, so
///    a user who already granted permission gets distances without being
///    nagged, and one who never granted it is not ambushed by a system dialog
///    on the home screen.
///  * [requestPermission] prompts, and is only ever called from a control the
///    user tapped.
class UserLocationNotifier extends StateNotifier<UserLocation> {
  UserLocationNotifier(this._ref) : super(const UserLocation()) {
    _restoreThenRefresh();
  }

  final Ref _ref;

  static const _readSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    timeLimit: Duration(seconds: 12),
  );

  Future<void> _restoreThenRefresh() async {
    final cached = await StorageService.getLastLatLng();
    if (!mounted) return;
    if (cached != null && Geo.usable(cached.$1, cached.$2)) {
      state = state.copyWith(latitude: cached.$1, longitude: cached.$2);
    }
    await refresh();
  }

  /// Re-reads the position **without** showing a permission dialog.
  Future<void> refresh() async {
    if (state.resolving) return;

    final permission = await Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.denied) {
      state = state.copyWith(permission: LocationPermissionState.denied);
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(permission: LocationPermissionState.deniedForever);
      return;
    }

    await _locate();
  }

  /// Asks for permission and then reads the position.
  ///
  /// Returns true only when a usable fix landed, so the caller can tell the
  /// user what happened instead of leaving a button that appears to do nothing.
  Future<bool> requestPermission() async {
    if (state.resolving) return state.hasFix;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return false;

    if (permission == LocationPermission.denied) {
      state = state.copyWith(permission: LocationPermissionState.denied);
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(permission: LocationPermissionState.deniedForever);
      return false;
    }

    await _locate(shareWithBackend: true, resolveCity: true);
    return mounted && state.hasFix;
  }

  /// Opens the app's OS settings page, where a permanent denial can be undone.
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the device's location settings, for when the service itself is off.
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> _locate({
    bool shareWithBackend = false,
    bool resolveCity = false,
  }) async {
    state = state.copyWith(
      permission: LocationPermissionState.granted,
      resolving: true,
    );

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        state = state.copyWith(
          permission: LocationPermissionState.serviceDisabled,
          resolving: false,
        );
        return;
      }

      // The last known fix is instant and usually good enough for a "3.2 km
      // away" label, so paint it first rather than holding the list blank
      // while the GPS warms up.
      final cached = await Geolocator.getLastKnownPosition();
      if (!mounted) return;
      if (cached != null && Geo.usable(cached.latitude, cached.longitude)) {
        state = state.copyWith(
          latitude: cached.latitude,
          longitude: cached.longitude,
        );
      }

      final position =
          await Geolocator.getCurrentPosition(locationSettings: _readSettings);
      if (!mounted) return;

      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        resolving: false,
      );
      await StorageService.setLastLatLng(position.latitude, position.longitude);

      if (shareWithBackend) {
        // Fire-and-forget: a signed-out user 401s here and that is fine, the
        // distances are computed on the device either way.
        ApiClient.updateLocation(position.latitude, position.longitude)
            .catchError((_) {});
      }
      if (resolveCity || _ref.read(cityProvider) == null) {
        await _resolveCity(position.latitude, position.longitude);
      }
    } catch (_) {
      // A timeout or a platform error leaves whatever fix we already had;
      // distances simply keep using the cached one.
      if (!mounted) return;
      state = state.copyWith(resolving: false);
    }
  }

  Future<void> _resolveCity(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (!mounted || placemarks.isEmpty) return;
      final place = placemarks.first;
      final city = place.locality ??
          place.subAdministrativeArea ??
          place.administrativeArea ??
          '';
      if (city.isNotEmpty) {
        await _ref.read(cityProvider.notifier).setCity(city);
      }
    } catch (_) {
      // Reverse geocoding is a nicety — the header falls back to the saved
      // city or "Near You".
    }
  }
}

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserLocation>(
  (ref) => UserLocationNotifier(ref),
);
