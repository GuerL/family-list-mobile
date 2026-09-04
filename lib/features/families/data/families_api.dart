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

  Future<FamilyDto> getFamily(int familyId) async {
    appLogger.debug('Families: fetching /api/families/$familyId');
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/families/$familyId',
    );
    return FamilyDto.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<FamilyDto> createFamily({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    appLogger.debug('Families: creating /api/families');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/families',
      data: {
        'name': name,
        'description': description,
        'members': <Map<String, dynamic>>[],
        'imageUrl': imageUrl,
      },
    );
    return FamilyDto.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<FamilyDto> updateFamily(FamilyDto family) async {
    appLogger.debug('Families: updating /api/families');
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/families',
      data: family.toJson(),
    );
    return FamilyDto.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteFamily(int familyId) async {
    appLogger.debug('Families: deleting /api/families/$familyId');
    await _dio.delete<void>('/api/families/$familyId');
  }

  Future<FamilyDto> joinFamily(String inviteCode) async {
    appLogger.debug('Families: accepting invitation');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/families/accept-invitation/${Uri.encodeComponent(inviteCode)}',
    );
    return FamilyDto.fromJson(response.data ?? <String, dynamic>{});
  }
}
