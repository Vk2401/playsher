import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage.dart';

/// Holds the user's current city name (from reverse geocoding).
class CityNotifier extends StateNotifier<String?> {
  CityNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final city = await StorageService.getCity();
    // The read is asynchronous and this notifier is disposed on logout, so the
    // answer can arrive after it is gone — writing state then throws.
    if (!mounted) return;
    state = city;
  }

  Future<void> setCity(String city) async {
    state = city;
    await StorageService.setCity(city);
  }
}

final cityProvider = StateNotifierProvider<CityNotifier, String?>((ref) {
  return CityNotifier();
});
