import 'shopping_list_models.dart';

enum AddableProductKind { global, family, custom }

class AddableProduct {
  const AddableProduct._({
    required this.kind,
    required this.label,
    this.product,
    this.familyProduct,
    this.description,
  });

  factory AddableProduct.global(ProductDto product) {
    return AddableProduct._(
      kind: AddableProductKind.global,
      label: product.label ?? 'Unnamed product',
      product: product,
    );
  }

  factory AddableProduct.family(FamilyProductDto product) {
    return AddableProduct._(
      kind: AddableProductKind.family,
      label: product.label ?? 'Unnamed product',
      familyProduct: product,
      description: product.description,
    );
  }

  factory AddableProduct.custom(String label) {
    return AddableProduct._(
      kind: AddableProductKind.custom,
      label: label.trim(),
    );
  }

  final AddableProductKind kind;
  final String label;
  final ProductDto? product;
  final FamilyProductDto? familyProduct;
  final String? description;

  String get sourceLabel {
    return switch (kind) {
      AddableProductKind.global => 'Global',
      AddableProductKind.family => 'Family',
      AddableProductKind.custom => 'Custom',
    };
  }

  int? get productId => product?.id;

  int? get familyProductId => familyProduct?.id;
}

class AddableProductCatalog {
  const AddableProductCatalog({
    required this.globalProducts,
    required this.familyProducts,
  });

  final List<ProductDto> globalProducts;
  final List<FamilyProductDto> familyProducts;

  List<AddableProduct> search(String query, {int limit = 8}) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final matches = [
      ...familyProducts.map(AddableProduct.family),
      ...globalProducts.map(AddableProduct.global),
    ].where((product) => _normalize(product.label).contains(normalizedQuery));

    return matches.take(limit).toList();
  }

  bool hasExactMatch(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return false;
    }

    return [
      ...familyProducts.map((product) => product.label),
      ...globalProducts.map((product) => product.label),
    ].whereType<String>().any((label) => _normalize(label) == normalizedQuery);
  }
}

String _normalize(String value) => value.trim().toLowerCase();
