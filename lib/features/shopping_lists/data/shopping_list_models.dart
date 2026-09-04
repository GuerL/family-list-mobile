import 'package:json_annotation/json_annotation.dart';

import '../../families/data/family_models.dart';

part 'shopping_list_models.g.dart';

@JsonSerializable()
class ShoppingListDto {
  const ShoppingListDto({
    this.id,
    required this.description,
    required this.family,
    required this.listItems,
    this.createdAt,
  });

  final int? id;
  final String description;
  final FamilyDto family;
  @JsonKey(defaultValue: <ShoppingListItemSummaryDto>[])
  final List<ShoppingListItemSummaryDto> listItems;
  final DateTime? createdAt;

  int get itemCount => listItems.length;

  int get remainingItemCount =>
      listItems.where((item) => item.purchased != true).length;

  factory ShoppingListDto.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoppingListDtoToJson(this);
}

@JsonSerializable()
class ShoppingListItemSummaryDto {
  const ShoppingListItemSummaryDto({
    this.id,
    this.description,
    this.quantity,
    this.purchased,
    this.purchasedAt,
  });

  final int? id;
  final String? description;
  final int? quantity;
  final bool? purchased;
  final DateTime? purchasedAt;

  factory ShoppingListItemSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListItemSummaryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoppingListItemSummaryDtoToJson(this);
}

@JsonSerializable()
class ListItemDto {
  const ListItemDto({
    this.id,
    this.description,
    this.quantity,
    this.product,
    this.familyProduct,
    this.familyList,
    this.purchased,
    this.purchasedAt,
    this.purchasedBy,
  });

  final int? id;
  final String? description;
  final int? quantity;
  final ProductDto? product;
  final FamilyProductDto? familyProduct;
  final ShoppingListReferenceDto? familyList;
  final bool? purchased;
  final DateTime? purchasedAt;
  final PurchasedByDto? purchasedBy;

  String get productName =>
      product?.label ?? familyProduct?.label ?? description ?? 'Unnamed item';

  ListItemDto copyWith({
    int? id,
    String? description,
    int? quantity,
    ProductDto? product,
    FamilyProductDto? familyProduct,
    ShoppingListReferenceDto? familyList,
    bool? purchased,
    DateTime? purchasedAt,
    PurchasedByDto? purchasedBy,
    bool clearPurchasedAt = false,
    bool clearPurchasedBy = false,
  }) {
    return ListItemDto(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      product: product ?? this.product,
      familyProduct: familyProduct ?? this.familyProduct,
      familyList: familyList ?? this.familyList,
      purchased: purchased ?? this.purchased,
      purchasedAt: clearPurchasedAt ? null : purchasedAt ?? this.purchasedAt,
      purchasedBy: clearPurchasedBy ? null : purchasedBy ?? this.purchasedBy,
    );
  }

  factory ListItemDto.fromJson(Map<String, dynamic> json) =>
      _$ListItemDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ListItemDtoToJson(this);
}

@JsonSerializable()
class ProductDto {
  const ProductDto({this.id, this.label, this.imageUrl});

  final int? id;
  final String? label;
  final String? imageUrl;

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProductDtoToJson(this);
}

@JsonSerializable()
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

  factory FamilyProductDto.fromJson(Map<String, dynamic> json) =>
      _$FamilyProductDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyProductDtoToJson(this);
}

@JsonSerializable()
class ShoppingListReferenceDto {
  const ShoppingListReferenceDto({this.id, this.description, this.createdAt});

  final int? id;
  final String? description;
  final DateTime? createdAt;

  factory ShoppingListReferenceDto.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListReferenceDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ShoppingListReferenceDtoToJson(this);
}

@JsonSerializable()
class PurchasedByDto {
  const PurchasedByDto({this.id, this.firstName, this.lastName});

  final int? id;
  final String? firstName;
  final String? lastName;

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ');
    return name.isEmpty ? 'Someone' : name;
  }

  factory PurchasedByDto.fromJson(Map<String, dynamic> json) =>
      _$PurchasedByDtoFromJson(json);

  Map<String, dynamic> toJson() => _$PurchasedByDtoToJson(this);
}
