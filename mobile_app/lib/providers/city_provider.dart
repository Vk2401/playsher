import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage.dart';

/// Holds the user's current city name (from reverse geocoding).
class CityNotifier extends StateNotifier<String?> {
  CityNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.getCity();
  }

  Future<void> setCity(String city) async {
    state = city;
    await StorageService.setCity(city);
  }
}

final cityProvider = StateNotifierProvider<CityNotifier, String?>((ref) {
  return CityNotifier();
});
