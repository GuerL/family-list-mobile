import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../families/presentation/selected_family_provider.dart';
import '../data/product_models.dart';
import '../data/products_api.dart';

final productsScopeProvider =
    NotifierProvider<ProductsScopeController, ProductScope>(
      ProductsScopeController.new,
    );

final productsSearchProvider =
    NotifierProvider<ProductsSearchController, String>(
      ProductsSearchController.new,
    );

final productsControllerProvider =
    FutureProvider.autoDispose<List<ProductEntry>>((ref) async {
      final selectedFamily = ref.watch(selectedFamilyProvider);
      final selectedFamilyId = selectedFamily?.id;

      try {
        final api = ref.read(productsApiProvider);
        final globalFuture = api.getGlobalProducts();
        final familyFuture = selectedFamilyId == null
            ? Future.value(const <FamilyProductDto>[])
            : api.getFamilyProducts(selectedFamilyId);
        final results = await Future.wait([globalFuture, familyFuture]);
        final globalProducts = results[0] as List<GlobalProductDto>;
        final familyProducts = results[1] as List<FamilyProductDto>;

        return [
          ...familyProducts.map(
            (product) => ProductEntry.family(product, family: selectedFamily),
          ),
          ...globalProducts.map(ProductEntry.global),
        ];
      } catch (error) {
        throw ApiError.fromObject(error);
      }
    });

final filteredProductsProvider = Provider.autoDispose<List<ProductEntry>>((
  ref,
) {
  final products = ref.watch(productsControllerProvider).value ?? const [];
  return filterProducts(
    products: products,
    scope: ref.watch(productsScopeProvider),
    query: ref.watch(productsSearchProvider),
  );
});

final productCategoriesProvider =
    FutureProvider.autoDispose<List<ProductCategoryDto>>((ref) async {
      try {
        return await ref.read(productsApiProvider).getProductCategories();
      } catch (error) {
        throw ApiError.fromObject(error);
      }
    });

final productManagementControllerProvider =
    Provider<ProductManagementController>(ProductManagementController.new);

class ProductsScopeController extends Notifier<ProductScope> {
  @override
  ProductScope build() => ProductScope.all;

  void setScope(ProductScope scope) {
    state = scope;
  }
}

class ProductsSearchController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

class ProductManagementController {
  const ProductManagementController(this._ref);

  final Ref _ref;

  Future<void> createFamilyProduct({
    required int familyId,
    required String label,
    String? description,
  }) async {
    try {
      await _ref
          .read(productsApiProvider)
          .createFamilyProduct(
            familyId: familyId,
            label: label,
            description: description,
          );
      _ref.invalidate(productsControllerProvider);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }

  Future<void> updateFamilyProduct({
    required int id,
    required String label,
    String? description,
  }) async {
    try {
      await _ref
          .read(productsApiProvider)
          .updateFamilyProduct(id: id, label: label, description: description);
      _ref.invalidate(productsControllerProvider);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }

  Future<void> deleteFamilyProduct(FamilyProductDto product) async {
    final id = product.id;
    if (id == null) {
      throw const ApiError(message: 'Product id is missing.');
    }

    try {
      await _ref.read(productsApiProvider).deleteFamilyProduct(id);
      _ref.invalidate(productsControllerProvider);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }

  Future<void> createGlobalProduct({
    required String label,
    String? imageUrl,
    ProductCategoryDto? productCategory,
  }) async {
    try {
      await _ref
          .read(productsApiProvider)
          .createGlobalProduct(
            label: label,
            imageUrl: imageUrl,
            productCategory: productCategory,
          );
      _ref.invalidate(productsControllerProvider);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }

  Future<void> updateGlobalProduct({
    required int id,
    required String label,
    String? imageUrl,
    ProductCategoryDto? productCategory,
  }) async {
    try {
      await _ref
          .read(productsApiProvider)
          .updateGlobalProduct(
            id: id,
            label: label,
            imageUrl: imageUrl,
            productCategory: productCategory,
          );
      _ref.invalidate(productsControllerProvider);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }

  Future<void> deleteGlobalProduct(GlobalProductDto product) async {
    final id = product.id;
    if (id == null) {
      throw const ApiError(message: 'Product id is missing.');
    }

    try {
      await _ref.read(productsApiProvider).deleteGlobalProduct(id);
      _ref.invalidate(productsControllerProvider);
    } catch (error) {
      throw ApiError.fromObject(error);
    }
  }
}
