import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/debug/app_logger.dart';
import 'family_models.dart';

final familiesApiProvider = Provider<FamiliesApi>((ref) {
  return FamiliesApi(ref.watch(dioProvider));
});

class FamiliesApi {
  const FamiliesApi(this._dio);

  final Dio _dio;

  Future<List<FamilyDto>> getFamilies() async {
    appLogger.debug('Families: fetching /api/families');
    final response = await _dio.get<List<dynamic>>('/api/families');
    final data = response.data ?? const [];

    final families = data
        .whereType<Map<String, dynamic>>()
        .map(FamilyDto.fromJson)
        .toList();
    appLogger.debug('Families: received ${families.length} families');
    return families;
  }
}
