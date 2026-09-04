import 'package:dio/dio.dart';
import 'package:familylist/core/network/api_error.dart';
import 'package:familylist/features/families/data/family_models.dart';
import 'package:familylist/features/products/data/product_models.dart';
import 'package:familylist/features/products/data/products_api.dart';
import 'package:familylist/features/products/presentation/products_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('product parsing', () {
    test('parses category JSON and writes backend record shape', () {
      final category = ProductCategoryDto.fromJson({
        'id': 3,
        'name': 'Seafood',
        'linkedProducts': [
          {'id': 1, 'label': 'Saumon'},
          {'id': 2, 'label': 'Tuna'},
        ],
      });

      expect(category.id, 3);
      expect(category.name, 'Seafood');
      expect(category.linkedProductCount, 2);
      expect(category.toJson(), {
        'id': 3,
        'name': 'Seafood',
        'linkedProducts': null,
      });
    });

    test('parses global products with image and category', () {
      final product = GlobalProductDto.fromJson({
        'id': 1,
        'label': 'Saumon',
        'imageUrl': 'https://example.com/salmon.png',
        'productCategory': {'id': 3, 'name': 'Fish', 'linkedProducts': []},
      });

      expect(product.id, 1);
      expect(product.label, 'Saumon');
      expect(product.imageUrl, 'https://example.com/salmon.png');
      expect(product.productCategory?.name, 'Fish');
    });

    test('parses family products with description and family id', () {
      final product = FamilyProductDto.fromJson({
        'id': 2,
        'label': 'House cereal',
        'description': 'Low sugar',
        'familyId': 10,
      });

      expect(product.id, 2);
      expect(product.label, 'House cereal');
      expect(product.description, 'Low sugar');
      expect(product.familyId, 10);
    });
  });

  group('product filtering', () {
    test('displays category in global product metadata', () {
      final product = ProductEntry.global(
        const GlobalProductDto(
          id: 2,
          label: 'Saumon',
          productCategory: ProductCategoryDto(id: 3, name: 'Seafood'),
        ),
      );

      expect(product.categoryName, 'Seafood');
      expect(product.metadataLine, 'Seafood · Global');
      expect(
        ProductEntry.family(
          const FamilyProductDto(id: 1, label: 'House cereal'),
        ).metadataLine,
        'Family',
      );
    });

    test('filters all, family, and global products', () {
      final products = [
        ProductEntry.family(
          const FamilyProductDto(
            id: 1,
            label: 'House cereal',
            description: 'Low sugar',
            familyId: 10,
          ),
          family: _family,
        ),
        ProductEntry.global(
          const GlobalProductDto(
            id: 2,
            label: 'Saumon',
            productCategory: ProductCategoryDto(id: 3, name: 'Fish'),
          ),
        ),
      ];

      expect(
        filterProducts(
          products: products,
          scope: ProductScope.all,
          query: '',
        ).map((product) => product.name),
        ['House cereal', 'Saumon'],
      );
      expect(
        filterProducts(
          products: products,
          scope: ProductScope.family,
          query: '',
        ).single.name,
        'House cereal',
      );
      expect(
        filterProducts(
          products: products,
          scope: ProductScope.global,
          query: '',
        ).single.name,
        'Saumon',
      );
    });

    test('searches name and subtitle text', () {
      final products = [
        ProductEntry.family(
          const FamilyProductDto(
            id: 1,
            label: 'House cereal',
            description: 'Low sugar',
            familyId: 10,
          ),
        ),
        ProductEntry.global(
          const GlobalProductDto(
            id: 2,
            label: 'Saumon',
            productCategory: ProductCategoryDto(id: 3, name: 'Fish'),
          ),
        ),
      ];

      expect(
        filterProducts(
          products: products,
          scope: ProductScope.all,
          query: 'sugar',
        ).single.name,
        'House cereal',
      );
      expect(
        filterProducts(
          products: products,
          scope: ProductScope.all,
          query: 'fish',
        ).single.name,
        'Saumon',
      );
    });
  });

  group('family context and permissions', () {
    test('auto-selects one family and clears invalid selections', () {
      final otherFamily = _family.copyWith(id: 11, name: 'Other');

      expect(
        resolveProductsFamilySelection(
          families: [_family],
          selectedFamily: null,
        ),
        _family,
      );
      expect(
        resolveProductsFamilySelection(
          families: [_family, otherFamily],
          selectedFamily: _family.copyWith(id: 99, name: 'Deleted'),
        ),
        isNull,
      );
    });

    test('detects global product managers from auth roles', () {
      expect(canManageGlobalProducts(['ROLE_USER']), isFalse);
      expect(canManageGlobalProducts(['ROLE_ADMIN']), isTrue);
      expect(canManageGlobalProducts(['ROLE_SUPER_ADMIN']), isTrue);
    });

    test('uses the same admin gate for category management visibility', () {
      expect(canManageGlobalProducts(['ROLE_USER']), isFalse);
      expect(canManageGlobalProducts(['ROLE_ADMIN']), isTrue);
    });
  });

  group('category selector payloads', () {
    test('creating a global product sends selected category', () async {
      final api = _FakeProductsApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container
          .read(productManagementControllerProvider)
          .createGlobalProduct(
            label: 'Saumon',
            imageUrl: 'https://example.com/salmon.png',
            productCategory: const ProductCategoryDto(id: 3, name: 'Seafood'),
          );

      expect(api.createdGlobalProducts.single.label, 'Saumon');
      expect(api.createdGlobalProducts.single.productCategory?.id, 3);
      expect(api.createdGlobalProducts.single.productCategory?.name, 'Seafood');
    });

    test('editing a global product sends selected category', () async {
      final api = _FakeProductsApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container
          .read(productManagementControllerProvider)
          .updateGlobalProduct(
            id: 9,
            label: 'Saumon',
            productCategory: const ProductCategoryDto(id: 4, name: 'Fish'),
          );

      expect(api.updatedGlobalProducts.single.id, 9);
      expect(api.updatedGlobalProducts.single.productCategory?.id, 4);
    });
  });

  group('category management', () {
    test(
      'creates and updates categories through the category endpoints',
      () async {
        final api = _FakeProductsApi();
        final container = _containerWith(api);
        addTearDown(container.dispose);

        await container
            .read(productManagementControllerProvider)
            .createProductCategory(name: 'Seafood');
        await container
            .read(productManagementControllerProvider)
            .updateProductCategory(id: 3, name: 'Fresh fish');

        expect(api.createdCategoryNames, ['Seafood']);
        expect(api.updatedCategories.single.id, 3);
        expect(api.updatedCategories.single.name, 'Fresh fish');
      },
    );
  });

  group('delete behavior', () {
    test('deletes family products through the family endpoint', () async {
      final api = _FakeProductsApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container
          .read(productManagementControllerProvider)
          .deleteFamilyProduct(
            const FamilyProductDto(id: 7, label: 'House cereal'),
          );

      expect(api.deletedFamilyProductIds, [7]);
      expect(api.deletedGlobalProductIds, isEmpty);
    });

    test('deletes global products through the global endpoint', () async {
      final api = _FakeProductsApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await container
          .read(productManagementControllerProvider)
          .deleteGlobalProduct(const GlobalProductDto(id: 9, label: 'Saumon'));

      expect(api.deletedGlobalProductIds, [9]);
      expect(api.deletedFamilyProductIds, isEmpty);
    });

    test('keeps missing product ids away from the API', () async {
      final api = _FakeProductsApi();
      final container = _containerWith(api);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(productManagementControllerProvider)
            .deleteFamilyProduct(const FamilyProductDto(label: 'No id')),
        throwsA(isA<ApiError>()),
      );
      expect(api.deletedFamilyProductIds, isEmpty);
    });
  });
}

ProviderContainer _containerWith(_FakeProductsApi api) {
  return ProviderContainer(
    overrides: [productsApiProvider.overrideWithValue(api)],
  );
}

final _family = FamilyDto(
  id: 10,
  name: 'Home',
  description: 'Home',
  members: const [],
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

class _FakeProductsApi extends ProductsApi {
  _FakeProductsApi() : super(Dio());

  final deletedFamilyProductIds = <int>[];
  final deletedGlobalProductIds = <int>[];
  final createdGlobalProducts = <GlobalProductDto>[];
  final updatedGlobalProducts = <GlobalProductDto>[];
  final createdCategoryNames = <String>[];
  final updatedCategories = <ProductCategoryDto>[];

  @override
  Future<void> deleteFamilyProduct(int id) async {
    deletedFamilyProductIds.add(id);
  }

  @override
  Future<void> deleteGlobalProduct(int id) async {
    deletedGlobalProductIds.add(id);
  }

  @override
  Future<GlobalProductDto> createGlobalProduct({
    required String label,
    String? imageUrl,
    ProductCategoryDto? productCategory,
  }) async {
    final product = GlobalProductDto(
      id: 100,
      label: label,
      imageUrl: imageUrl,
      productCategory: productCategory,
    );
    createdGlobalProducts.add(product);
    return product;
  }

  @override
  Future<GlobalProductDto> updateGlobalProduct({
    required int id,
    required String label,
    String? imageUrl,
    ProductCategoryDto? productCategory,
  }) async {
    final product = GlobalProductDto(
      id: id,
      label: label,
      imageUrl: imageUrl,
      productCategory: productCategory,
    );
    updatedGlobalProducts.add(product);
    return product;
  }

  @override
  Future<ProductCategoryDto> createProductCategory({
    required String name,
  }) async {
    createdCategoryNames.add(name);
    return ProductCategoryDto(id: 200, name: name);
  }

  @override
  Future<ProductCategoryDto> updateProductCategory({
    required int id,
    required String name,
  }) async {
    final category = ProductCategoryDto(id: id, name: name);
    updatedCategories.add(category);
    return category;
  }
}
