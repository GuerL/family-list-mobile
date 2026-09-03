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

  Future<void> togglePurchased(ListItemDto item) async {
    final itemId = item.id;
    if (itemId == null) {
      return;
    }

    final previousItems = state.value ?? const <ListItemDto>[];
    final nextPurchased = item.purchased != true;
    state = AsyncData(
      previousItems
          .map(
            (current) => current.id == itemId
                ? current.copyWithPurchased(nextPurchased)
                : current,
          )
          .toList(),
    );

    try {
      final updated = await ref
          .read(shoppingListsApiProvider)
          .togglePurchased(itemId: itemId, purchased: nextPurchased);
      state = AsyncData(
        (state.value ?? previousItems)
            .map((current) => current.id == itemId ? updated : current)
            .toList(),
      );
    } catch (error) {
      state = AsyncData(previousItems);
      throw ApiError.fromObject(error);
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
