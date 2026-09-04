import '../../families/data/family_models.dart';

enum ProductScope { all, family, global }

enum ProductKind { family, global }

class ProductCategoryDto {
  const ProductCategoryDto({this.id, this.name, this.linkedProductCount = 0});

  final int? id;
  final String? name;
  final int linkedProductCount;

  factory ProductCategoryDto.fromJson(Map<String, dynamic> json) {
    final linkedProducts = json['linkedProducts'];
    return ProductCategoryDto(
      id: json['id'] as int?,
      name: json['name'] as String?,
      linkedProductCount: linkedProducts is List ? linkedProducts.length : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'linkedProducts': null,
  };
}

class GlobalProductDto {
  const GlobalProductDto({
    this.id,
    this.label,
    this.imageUrl,
    this.productCategory,
  });

  final int? id;
  final String? label;
  final String? imageUrl;
  final ProductCategoryDto? productCategory;

  factory GlobalProductDto.fromJson(Map<String, dynamic> json) {
    return GlobalProductDto(
      id: json['id'] as int?,
      label: json['label'] as String?,
      imageUrl: json['imageUrl'] as String?,
      productCategory: json['productCategory'] is Map<String, dynamic>
          ? ProductCategoryDto.fromJson(
              json['productCategory'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'imageUrl': imageUrl,
    'productCategory': productCategory?.toJson(),
  };
}

class FamilyProductDto {
  const FamilyProductDto({
    this.id,
    this.label,
    this.description,
    this.familyId,
  });

  final int? id;
  final String? label;
  final String? description;
  final int? familyId;

  factory FamilyProductDto.fromJson(Map<String, dynamic> json) {
    return FamilyProductDto(
      id: json['id'] as int?,
      label: json['label'] as String?,
      description: json['description'] as String?,
      familyId: json['familyId'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'description': description,
    'familyId': familyId,
  };
}

class ProductEntry {
  const ProductEntry.family(this.familyProduct, {this.family})
    : globalProduct = null,
      kind = ProductKind.family;

  const ProductEntry.global(this.globalProduct)
    : familyProduct = null,
      family = null,
      kind = ProductKind.global;

  final ProductKind kind;
  final GlobalProductDto? globalProduct;
  final FamilyProductDto? familyProduct;
  final FamilyDto? family;

  int? get id => switch (kind) {
    ProductKind.family => familyProduct?.id,
    ProductKind.global => globalProduct?.id,
  };

  String get name {
    final value = switch (kind) {
      ProductKind.family => familyProduct?.label,
      ProductKind.global => globalProduct?.label,
    };
    return _displayText(value, fallback: 'Unnamed product');
  }

  String? get subtitle {
    final value = switch (kind) {
      ProductKind.family => familyProduct?.description,
      ProductKind.global => globalProduct?.productCategory?.name,
    };
    return _displayTextOrNull(value);
  }

  String? get categoryName =>
      _displayTextOrNull(globalProduct?.productCategory?.name);

  String get metadataLine {
    final category = categoryName;
    if (category == null) {
      return scopeLabel;
    }
    return '$category · $scopeLabel';
  }

  String? get imageUrl => globalProduct?.imageUrl;

  String get scopeLabel => kind == ProductKind.family ? 'Family' : 'Global';

  bool get isFamily => kind == ProductKind.family;

  bool get isGlobal => kind == ProductKind.global;
}

List<ProductEntry> filterProducts({
  required List<ProductEntry> products,
  required ProductScope scope,
  required String query,
}) {
  final normalizedQuery = _normalize(query);
  return products.where((product) {
    final scopeMatches = switch (scope) {
      ProductScope.all => true,
      ProductScope.family => product.isFamily,
      ProductScope.global => product.isGlobal,
    };
    if (!scopeMatches) {
      return false;
    }

    if (normalizedQuery.isEmpty) {
      return true;
    }

    return _normalize(product.name).contains(normalizedQuery) ||
        _normalize(product.subtitle ?? '').contains(normalizedQuery) ||
        _normalize(product.categoryName ?? '').contains(normalizedQuery);
  }).toList();
}

FamilyDto? resolveProductsFamilySelection({
  required List<FamilyDto> families,
  required FamilyDto? selectedFamily,
}) {
  if (families.isEmpty) {
    return null;
  }

  if (selectedFamily != null &&
      families.any((family) => family.id == selectedFamily.id)) {
    return selectedFamily;
  }

  return families.length == 1 ? families.first : null;
}

bool canManageGlobalProducts(Iterable<String> roles) {
  return roles.any(
    (role) => role.contains('ROLE_SUPER_ADMIN') || role.contains('ROLE_ADMIN'),
  );
}

String _normalize(String value) => value.trim().toLowerCase();

String _displayText(String? value, {required String fallback}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallback;
  }
  return trimmed;
}

String? _displayTextOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
