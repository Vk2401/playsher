import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/user_model.dart';

final profileProvider = FutureProvider<UserModel>((ref) async {
  final res = await ApiClient.getProfile();
  final data = res['data'] as Map<String, dynamic>? ??
      res['user'] as Map<String, dynamic>? ??
      res;
  return UserModel.fromJson(data);
});
