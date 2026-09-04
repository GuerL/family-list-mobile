import 'dart:async';

import 'package:dio/dio.dart';
import 'package:familylist/core/network/api_error.dart';
import 'package:familylist/features/families/data/family_models.dart';
import 'package:familylist/features/shopping/presentation/shopping_screen.dart';
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

  group('Shopping filtering and selection', () {
    test('filters remaining, all, and purchased items', () {
      const items = [
        ListItemDto(id: 1, description: 'Milk', purchased: false),
        ListItemDto(id: 2, description: 'Bread', purchased: true),
        ListItemDto(id: 3, description: 'Apples'),
      ];

      expect(
        filterShoppingItems(
          items,
          ShoppingItemFilter.remaining,
        ).map((item) => item.id),
        [1, 3],
      );
      expect(
        filterShoppingItems(
          items,
          ShoppingItemFilter.all,
        ).map((item) => item.id),
        [1, 2, 3],
      );
      expect(
        filterShoppingItems(
          items,
          ShoppingItemFilter.purchased,
        ).map((item) => item.id),
        [2],
      );
    });

    test('auto-selects one family and clears invalid family selection', () {
      final firstFamily = _family;
      final secondFamily = _family.copyWith(id: 11, name: 'Other');

      expect(
        resolveShoppingFamilySelection(
          families: [firstFamily],
          selectedFamily: null,
        ),
        firstFamily,
      );
      expect(
        resolveShoppingFamilySelection(
          families: [firstFamily, secondFamily],
          selectedFamily: _family.copyWith(id: 99, name: 'Deleted'),
        ),
        isNull,
      );
    });

    test('list selection validates family and restores remembered list', () {
      final firstList = _list(id: 1, family: _family, description: 'First');
      final secondList = _list(id: 2, family: _family, description: 'Second');
      final otherFamilyList = _list(
        id: 3,
        family: _family.copyWith(id: 11, name: 'Other'),
        description: 'Other',
      );

      expect(
        resolveShoppingListSelection(
          familyId: _family.id,
          lists: [firstList, secondList],
          selectedList: otherFamilyList,
          rememberedListId: 2,
        )?.id,
        2,
      );
      expect(
        resolveShoppingListSelection(
          familyId: _family.id,
          lists: [firstList],
          selectedList: null,
          rememberedListId: null,
        ),
        firstList,
      );
      expect(
        resolveShoppingListSelection(
          familyId: 11,
          lists: [otherFamilyList],
          selectedList: firstList,
          rememberedListId: null,
        )?.id,
        3,
      );
      expect(
        resolveShoppingListSelection(
          familyId: _family.id,
          lists: [firstList, secondList],
          selectedList: otherFamilyList,
          rememberedListId: null,
        ),
        isNull,
      );
    });
  });

  group('ShoppingListItemsController purchased toggle', () {
    test(
      'optimistically toggles purchased and keeps backend response',
      () async {
        final api = _FakeShoppingListsApi(
          initialItems: const [
            ListItemDto(id: 1, description: 'Milk', purchased: false),
          ],
        );
        final container = _containerWith(api);
        addTearDown(container.dispose);

        await container.read(shoppingListItemsControllerProvider(100).future);
        final future = container
            .read(shoppingListItemsControllerProvider(100).notifier)
            .togglePurchased(
              item: const ListItemDto(
                id: 1,
                description: 'Milk',
                purchased: false,
              ),
              purchased: true,
            );

        expect(
          container
              .read(shoppingListItemsControllerProvider(100))
              .value
              ?.single
              .purchased,
          isTrue,
        );

        api.toggleCompleter.complete(
          const ListItemDto(
            id: 1,
            description: 'Milk',
            purchased: true,
            purchasedBy: PurchasedByDto(firstName: 'Buyer'),
          ),
        );
        await future;

        final item = container
            .read(shoppingListItemsControllerProvider(100))
            .value!
            .single;
        expect(api.toggleCalls, const [
          _ToggleCall(itemId: 1, purchased: true),
        ]);
        expect(item.purchased, isTrue);
        expect(item.purchasedBy?.displayName, 'Buyer');
      },
    );

    test('rolls back optimistic purchased toggle after an error', () async {
      final api = _FakeShoppingListsApi(
        initialItems: const [
          ListItemDto(id: 1, description: 'Milk', purchased: false),
        ],
      );
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container.read(shoppingListItemsControllerProvider(100).future);
      final future = container
          .read(shoppingListItemsControllerProvider(100).notifier)
          .togglePurchased(
            item: const ListItemDto(
              id: 1,
              description: 'Milk',
              purchased: false,
            ),
            purchased: true,
          );
      final expectation = expectLater(future, throwsA(isA<ApiError>()));
      api.toggleCompleter.completeError(Exception('No connection'));

      await expectation;
      expect(
        container
            .read(shoppingListItemsControllerProvider(100))
            .value
            ?.single
            .purchased,
        isFalse,
      );
    });

    test('ignores repeated taps while a purchased toggle is pending', () async {
      final api = _FakeShoppingListsApi(
        initialItems: const [
          ListItemDto(id: 1, description: 'Milk', purchased: false),
        ],
      );
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container.read(shoppingListItemsControllerProvider(100).future);
      final notifier = container.read(
        shoppingListItemsControllerProvider(100).notifier,
      );
      final first = notifier.togglePurchased(
        item: const ListItemDto(id: 1, description: 'Milk', purchased: false),
        purchased: true,
      );
      final second = notifier.togglePurchased(
        item: const ListItemDto(id: 1, description: 'Milk', purchased: false),
        purchased: true,
      );

      expect(api.toggleCalls, hasLength(1));
      api.toggleCompleter.complete(
        const ListItemDto(id: 1, description: 'Milk', purchased: true),
      );
      await Future.wait([first, second]);
    });
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

extension on FamilyDto {
  FamilyDto copyWith({int? id, String? name}) {
    return FamilyDto(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description,
      members: members,
      creator: creator,
      imageUrl: imageUrl,
      inviteCode: inviteCode,
      isActive: isActive,
    );
  }
}

ShoppingListDto _list({
  required int id,
  required FamilyDto family,
  required String description,
}) {
  return ShoppingListDto(
    id: id,
    description: description,
    family: family,
    listItems: const [],
  );
}

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

class _ToggleCall {
  const _ToggleCall({required this.itemId, required this.purchased});

  final int itemId;
  final bool purchased;

  @override
  bool operator ==(Object other) {
    return other is _ToggleCall &&
        other.itemId == itemId &&
        other.purchased == purchased;
  }

  @override
  int get hashCode => Object.hash(itemId, purchased);
}

class _FakeShoppingListsApi extends ShoppingListsApi {
  _FakeShoppingListsApi({this.initialItems = const []}) : super(Dio());

  final List<ListItemDto> initialItems;
  final createdItems = <_CreatedItemCall>[];
  final createdFamilyProducts = <_CreatedFamilyProductCall>[];
  final deletedListIds = <int>[];
  final toggleCalls = <_ToggleCall>[];
  var toggleCompleter = Completer<ListItemDto>();

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
    return initialItems;
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

  @override
  Future<ListItemDto> togglePurchased({
    required int itemId,
    required bool purchased,
  }) {
    toggleCalls.add(_ToggleCall(itemId: itemId, purchased: purchased));
    return toggleCompleter.future;
  }
}
