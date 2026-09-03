import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/app_logger.dart';
import '../../../core/network/dio_provider.dart';
import '../../families/data/family_models.dart';
import 'shopping_list_models.dart';

final shoppingListsApiProvider = Provider<ShoppingListsApi>((ref) {
  return ShoppingListsApi(ref.watch(dioProvider));
});

class ShoppingListsApi {
  const ShoppingListsApi(this._dio);

  final Dio _dio;

  Future<List<ShoppingListDto>> getListsForFamily(FamilyDto family) async {
    appLogger.debug('Lists: fetching /api/families-list/search');
    final response = await _dio.post<List<dynamic>>(
      '/api/families-list/search',
      data: family.toJson(),
    );
    return _parseListResponse(response.data);
  }

  Future<ShoppingListDto> createList({
    required FamilyDto family,
    required String description,
  }) async {
    appLogger.debug('Lists: creating list with /api/families-list');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/families-list',
      data: {
        'description': description,
        'family': family.toJson(),
        'listItems': <Map<String, dynamic>>[],
      },
    );
    return ShoppingListDto.fromJson(response.data ?? <String, dynamic>{});
  }

  List<ShoppingListDto> _parseListResponse(List<dynamic>? data) {
    final lists = (data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ShoppingListDto.fromJson)
        .toList();
    appLogger.debug('Lists: received ${lists.length} lists');
    return lists;
  }
}
