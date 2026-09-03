import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/shopping_list_models.dart';
import '../data/shopping_lists_api.dart';

final shoppingListItemsControllerProvider =
    AsyncNotifierProvider.family<
      ShoppingListItemsController,
      List<ListItemDto>,
      int
    >(ShoppingListItemsController.new);

class ShoppingListItemsController extends AsyncNotifier<List<ListItemDto>> {
  ShoppingListItemsController(this._familyListId);

  final int _familyListId;

  @override
  Future<List<ListItemDto>> build() async {
    return _loadItems(_familyListId);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadItems(_familyListId));
  }

  Future<void> createItem({
    required int familyId,
    required String name,
    required int quantity,
    String? description,
  }) async {
    final previousItems = state.value ?? const <ListItemDto>[];

    try {
      final api = ref.read(shoppingListsApiProvider);
      final familyProduct = await api.createFamilyProduct(
        familyId: familyId,
        label: name,
        description: description,
      );
      final familyProductId = familyProduct.id;
      if (familyProductId == null) {
        throw const ApiError(message: 'Created product has no id.');
      }

      final created = await api.createItem(
        familyListId: _familyListId,
        familyProductId: familyProductId,
        quantity: quantity,
        description: description,
      );
      state = AsyncData([...previousItems, created]);
    } catch (error, stackTrace) {
      final apiError = ApiError.fromObject(error);
      state = AsyncError(apiError, stackTrace);
      throw apiError;
    }
  }

  Future<void> updateItem({
    required ListItemDto item,
    required int quantity,
    String? description,
  }) async {
    final itemId = item.id;
    if (itemId == null) {
      return;
    }

    final previousItems = state.value ?? const <ListItemDto>[];

    try {
      final updated = await ref
          .read(shoppingListsApiProvider)
          .updateItem(
            itemId: itemId,
            quantity: quantity,
            productId: item.product?.id,
            familyProductId: item.familyProduct?.id,
            description: description,
          );
      state = AsyncData(
        previousItems
            .map((current) => current.id == itemId ? updated : current)
            .toList(),
      );
    } catch (error, stackTrace) {
      state = AsyncData(previousItems);
      final apiError = ApiError.fromObject(error);
      state = AsyncError(apiError, stackTrace);
      throw apiError;
    }
  }

  Future<void> deleteItem(ListItemDto item) async {
    final itemId = item.id;
    if (itemId == null) {
      return;
    }

    final previousItems = state.value ?? const <ListItemDto>[];
    state = AsyncData(
      previousItems.where((current) => current.id != itemId).toList(),
    );

    try {
      await ref.read(shoppingListsApiProvider).deleteItem(itemId);
    } catch (error, stackTrace) {
      state = AsyncData(previousItems);
      final apiError = ApiError.fromObject(error);
      state = AsyncError(apiError, stackTrace);
      throw apiError;
    }
  }

  Future<List<ListItemDto>> _loadItems(int familyListId) async {
    try {
      return await ref.read(shoppingListsApiProvider).getItems(familyListId);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }
}
