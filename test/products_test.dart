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

  @override
  Future<void> deleteFamilyProduct(int id) async {
    deletedFamilyProductIds.add(id);
  }

  @override
  Future<void> deleteGlobalProduct(int id) async {
    deletedGlobalProductIds.add(id);
  }
}
