import 'package:dio/dio.dart';
import 'package:familylist/features/families/data/family_models.dart';
import 'package:familylist/features/shopping_lists/data/product_search.dart';
import 'package:familylist/features/shopping_lists/data/shopping_list_models.dart';
import 'package:familylist/features/shopping_lists/data/shopping_lists_api.dart';
import 'package:familylist/features/shopping_lists/presentation/shopping_list_items_controller.dart';
import 'package:familylist/features/shopping_lists/presentation/shopping_lists_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddableProductCatalog', () {
    test('filters and maps family products before global products', () {
      final catalog = AddableProductCatalog(
        familyProducts: const [
          FamilyProductDto(id: 1, label: 'Family Saumon', familyId: 10),
        ],
        globalProducts: const [
          ProductDto(id: 2, label: 'Saumon'),
          ProductDto(id: 3, label: 'Bread'),
        ],
      );

      final results = catalog.search('s');

      expect(results, hasLength(2));
      expect(results.first.kind, AddableProductKind.family);
      expect(results.first.familyProductId, 1);
      expect(results.last.kind, AddableProductKind.global);
      expect(results.last.productId, 2);
    });

    test('detects exact matches for custom fallback decisions', () {
      final catalog = AddableProductCatalog(
        familyProducts: const [FamilyProductDto(id: 1, label: 'Milk')],
        globalProducts: const [ProductDto(id: 2, label: 'Saumon')],
      );

      expect(catalog.hasExactMatch(' saumon '), isTrue);
      expect(catalog.hasExactMatch('Chocolate'), isFalse);
    });
  });

  group('ShoppingListItemsController createItem', () {
    test('selecting a global product sends productId', () async {
      final api = _FakeShoppingListsApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container.read(shoppingListItemsControllerProvider(100).future);
      await container
          .read(shoppingListItemsControllerProvider(100).notifier)
          .createItem(
            familyId: 10,
            product: AddableProduct.global(
              const ProductDto(id: 2, label: 'Saumon'),
            ),
            quantity: 3,
            description: 'fresh',
          );

      expect(api.createdFamilyProducts, isEmpty);
      expect(api.createdItems.single.productId, 2);
      expect(api.createdItems.single.familyProductId, isNull);
      expect(api.createdItems.single.quantity, 3);
      expect(api.createdItems.single.description, 'fresh');
    });

    test('selecting a family product sends familyProductId', () async {
      final api = _FakeShoppingListsApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container.read(shoppingListItemsControllerProvider(100).future);
      await container
          .read(shoppingListItemsControllerProvider(100).notifier)
          .createItem(
            familyId: 10,
            product: AddableProduct.family(
              const FamilyProductDto(id: 7, label: 'House milk', familyId: 10),
            ),
            quantity: 2,
          );

      expect(api.createdFamilyProducts, isEmpty);
      expect(api.createdItems.single.productId, isNull);
      expect(api.createdItems.single.familyProductId, 7);
      expect(api.createdItems.single.quantity, 2);
    });

    test(
      'custom product creates a family product before the list item',
      () async {
        final api = _FakeShoppingListsApi();
        final container = _containerWith(api);
        addTearDown(container.dispose);

        await container.read(shoppingListItemsControllerProvider(100).future);
        await container
            .read(shoppingListItemsControllerProvider(100).notifier)
            .createItem(
              familyId: 10,
              product: AddableProduct.custom('Chocolate'),
              quantity: 1,
              description: 'dark',
            );

        expect(api.createdFamilyProducts.single.familyId, 10);
        expect(api.createdFamilyProducts.single.label, 'Chocolate');
        expect(api.createdItems.single.productId, isNull);
        expect(api.createdItems.single.familyProductId, 900);
        expect(api.createdItems.single.description, 'dark');
      },
    );
  });

  test('deleting a list clears selectedShoppingListProvider', () async {
    final api = _FakeShoppingListsApi();
    final container = _containerWith(api);
    addTearDown(container.dispose);

    final list = ShoppingListDto(
      id: 42,
      description: 'First List of the app',
      family: _family,
      listItems: const [],
    );
    container.read(selectedShoppingListProvider.notifier).select(list);

    await container.read(deleteShoppingListControllerProvider).delete(list);

    expect(api.deletedListIds, [42]);
    expect(container.read(selectedShoppingListProvider), isNull);
  });
}

ProviderContainer _containerWith(_FakeShoppingListsApi api) {
  return ProviderContainer(
    overrides: [shoppingListsApiProvider.overrideWithValue(api)],
  );
}

const _family = FamilyDto(
  id: 10,
  name: 'Default',
  description: 'Default family',
  members: [],
);

class _CreatedItemCall {
  const _CreatedItemCall({
    required this.familyListId,
    required this.quantity,
    this.productId,
    this.familyProductId,
    this.description,
  });

  final int familyListId;
  final int quantity;
  final int? productId;
  final int? familyProductId;
  final String? description;
}

class _CreatedFamilyProductCall {
  const _CreatedFamilyProductCall({
    required this.familyId,
    required this.label,
    this.description,
  });

  final int familyId;
  final String label;
  final String? description;
}

class _FakeShoppingListsApi extends ShoppingListsApi {
  _FakeShoppingListsApi() : super(Dio());

  final createdItems = <_CreatedItemCall>[];
  final createdFamilyProducts = <_CreatedFamilyProductCall>[];
  final deletedListIds = <int>[];

  @override
  Future<void> createList({
    required FamilyDto family,
    required String description,
  }) async {}

  @override
  Future<FamilyProductDto> createFamilyProduct({
    required int familyId,
    required String label,
    String? description,
  }) async {
    createdFamilyProducts.add(
      _CreatedFamilyProductCall(
        familyId: familyId,
        label: label,
        description: description,
      ),
    );
    return FamilyProductDto(id: 900, label: label, familyId: familyId);
  }

  @override
  Future<ListItemDto> createItem({
    required int familyListId,
    required int quantity,
    int? productId,
    int? familyProductId,
    String? description,
  }) async {
    createdItems.add(
      _CreatedItemCall(
        familyListId: familyListId,
        quantity: quantity,
        productId: productId,
        familyProductId: familyProductId,
        description: description,
      ),
    );
    return ListItemDto(
      id: createdItems.length,
      quantity: quantity,
      description: description,
      product: productId == null
          ? null
          : ProductDto(id: productId, label: 'Global'),
      familyProduct: familyProductId == null
          ? null
          : FamilyProductDto(id: familyProductId, label: 'Family'),
    );
  }

  @override
  Future<void> deleteItem(int itemId) async {}

  @override
  Future<void> deleteList(int listId) async {
    deletedListIds.add(listId);
  }

  @override
  Future<List<FamilyProductDto>> getFamilyProducts(int familyId) async {
    return const [];
  }

  @override
  Future<List<ListItemDto>> getItems(int familyListId) async {
    return const [];
  }

  @override
  Future<List<ProductDto>> getGlobalProducts() async {
    return const [];
  }

  @override
  Future<List<ShoppingListDto>> getListsForFamily(FamilyDto family) async {
    return const [];
  }

  @override
  Future<ListItemDto> updateItem({
    required int itemId,
    required int quantity,
    int? productId,
    int? familyProductId,
    String? description,
  }) async {
    return ListItemDto(
      id: itemId,
      quantity: quantity,
      description: description,
    );
  }
}
