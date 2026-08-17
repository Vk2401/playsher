import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/amenity_model.dart';

final amenitiesProvider = FutureProvider<List<AmenityModel>>((ref) async {
  final res = await ApiClient.getAmenities();
  final list = res['data'] as List<dynamic>? ?? [];
  return AmenityModel.listFromJson(list);
});
