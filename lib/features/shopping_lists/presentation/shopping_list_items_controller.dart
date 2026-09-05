import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/product_search.dart';
import '../data/shopping_list_models.dart';
import '../data/shopping_lists_api.dart';
import '../realtime/list_item_purchased_event.dart';

final shoppingListItemsControllerProvider =
    AsyncNotifierProvider.family<
      ShoppingListItemsController,
      List<ListItemDto>,
      int
    >(ShoppingListItemsController.new);

final addableProductCatalogProvider = FutureProvider.autoDispose
    .family<AddableProductCatalog, int>((ref, familyId) async {
      try {
        final api = ref.read(shoppingListsApiProvider);
        final results = await Future.wait([
          api.getGlobalProducts(),
          api.getFamilyProducts(familyId),
        ]);
        return AddableProductCatalog(
          globalProducts: results[0] as List<ProductDto>,
          familyProducts: results[1] as List<FamilyProductDto>,
        );
      } catch (error) {
        throw ApiError.fromObject(error);
      }
    });

class ShoppingListItemsController extends AsyncNotifier<List<ListItemDto>> {
  ShoppingListItemsController(this._familyListId);

  final int _familyListId;
  final Set<int> _pendingPurchasedToggles = <int>{};

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
    required AddableProduct product,
    required int quantity,
    String? description,
  }) async {
    final previousItems = state.value ?? const <ListItemDto>[];

    try {
      final api = ref.read(shoppingListsApiProvider);
      var productId = product.productId;
      var familyProductId = product.familyProductId;

      if (product.kind == AddableProductKind.custom) {
        final familyProduct = await api.createFamilyProduct(
          familyId: familyId,
          label: product.label,
          description: description,
        );
        familyProductId = familyProduct.id;
        if (familyProductId == null) {
          throw const ApiError(message: 'Created product has no id.');
        }
      }

      final created = await api.createItem(
        familyListId: _familyListId,
        quantity: quantity,
        productId: productId,
        familyProductId: familyProductId,
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

  bool isPurchasedTogglePending(int itemId) {
    return _pendingPurchasedToggles.contains(itemId);
  }

  Future<void> togglePurchased({
    required ListItemDto item,
    required bool purchased,
  }) async {
    final itemId = item.id;
    if (itemId == null || _pendingPurchasedToggles.contains(itemId)) {
      return;
    }

    final previousItems = state.value ?? const <ListItemDto>[];
    _pendingPurchasedToggles.add(itemId);
    state = AsyncData(
      previousItems
          .map(
            (current) => current.id == itemId
                ? current.copyWith(
                    purchased: purchased,
                    clearPurchasedAt: !purchased,
                    clearPurchasedBy: !purchased,
                  )
                : current,
          )
          .toList(),
    );

    try {
      final updated = await ref
          .read(shoppingListsApiProvider)
          .togglePurchased(itemId: itemId, purchased: purchased);
      final currentItems = state.value ?? previousItems;
      state = AsyncData(
        currentItems
            .map((current) => current.id == itemId ? updated : current)
            .toList(),
      );
    } catch (error) {
      state = AsyncData(previousItems);
      throw ApiError.fromObject(error);
    } finally {
      _pendingPurchasedToggles.remove(itemId);
    }
  }

  void applyPurchasedEvent(ListItemPurchasedEvent event) {
    if (!event.appliesToList(_familyListId)) {
      return;
    }

    final currentItems = state.value;
    if (currentItems == null) {
      return;
    }

    final updatedItems = applyPurchasedEventToItems(
      items: currentItems,
      currentListId: _familyListId,
      event: event,
    );
    if (!identical(updatedItems, currentItems)) {
      state = AsyncData(updatedItems);
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

List<ListItemDto> applyPurchasedEventToItems({
  required List<ListItemDto> items,
  required int currentListId,
  required ListItemPurchasedEvent event,
}) {
  if (!event.appliesToList(currentListId)) {
    return items;
  }

  var found = false;
  final updated = items.map((item) {
    if (item.id != event.itemId) {
      return item;
    }

    found = true;
    return item.copyWith(
      purchased: event.purchased,
      purchasedAt: event.purchasedAt,
      purchasedBy: event.purchasedBy,
      clearPurchasedAt: !event.purchased,
      clearPurchasedBy: !event.purchased,
    );
  }).toList();

  return found ? updated : items;
}
