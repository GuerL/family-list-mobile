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

  Future<void> createList({
    required FamilyDto family,
    required String description,
  }) async {
    appLogger.debug('Lists: creating list with /api/families-list');
    await _dio.post<void>(
      '/api/families-list',
      data: {
        'description': description,
        'family': family.toJson(),
        'listItems': <Map<String, dynamic>>[],
      },
    );
    appLogger.debug('Lists: create request accepted by backend');
  }

  Future<List<ListItemDto>> getItems(int familyListId) async {
    appLogger.debug('List detail: fetching /api/list-items');
    final response = await _dio.get<List<dynamic>>(
      '/api/list-items',
      queryParameters: {'familyListId': familyListId},
    );
    final items = <ListItemDto>[];
    for (final entry in response.data ?? const []) {
      if (entry is! Map<String, dynamic>) {
        appLogger.debug('List detail: skipped unexpected item payload entry');
        continue;
      }

      try {
        items.add(ListItemDto.fromJson(entry));
      } catch (error) {
        appLogger.debug('List detail: failed to parse item payload: $error');
        rethrow;
      }
    }
    appLogger.debug('List detail: received ${items.length} items');
    return items;
  }

  Future<ListItemDto> togglePurchased({
    required int itemId,
    required bool purchased,
  }) async {
    appLogger.debug('List detail: toggling purchased for item $itemId');
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/list-items/$itemId/purchased',
      data: {'purchased': purchased},
    );
    return ListItemDto.fromJson(response.data ?? <String, dynamic>{});
  }

  List<ShoppingListDto> _parseListResponse(List<dynamic>? data) {
    final lists = <ShoppingListDto>[];
    for (final entry in data ?? const []) {
      if (entry is! Map<String, dynamic>) {
        appLogger.debug('Lists: skipped unexpected list payload entry');
        continue;
      }

      try {
        lists.add(ShoppingListDto.fromJson(entry));
      } catch (error) {
        appLogger.debug('Lists: failed to parse list payload: $error');
        rethrow;
      }
    }
    appLogger.debug('Lists: received ${lists.length} lists');
    return lists;
  }
}
