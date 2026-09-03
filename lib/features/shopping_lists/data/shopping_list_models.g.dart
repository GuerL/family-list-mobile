// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoppingListDto _$ShoppingListDtoFromJson(Map<String, dynamic> json) =>
    ShoppingListDto(
      id: (json['id'] as num?)?.toInt(),
      description: json['description'] as String,
      family: FamilyDto.fromJson(json['family'] as Map<String, dynamic>),
      listItems:
          (json['listItems'] as List<dynamic>?)
              ?.map(
                (e) => ShoppingListItemSummaryDto.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ShoppingListDtoToJson(ShoppingListDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'description': instance.description,
      'family': instance.family,
      'listItems': instance.listItems,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

ShoppingListItemSummaryDto _$ShoppingListItemSummaryDtoFromJson(
  Map<String, dynamic> json,
) => ShoppingListItemSummaryDto(
  id: (json['id'] as num?)?.toInt(),
  description: json['description'] as String?,
  quantity: (json['quantity'] as num?)?.toInt(),
  purchased: json['purchased'] as bool?,
  purchasedAt: json['purchasedAt'] == null
      ? null
      : DateTime.parse(json['purchasedAt'] as String),
);

Map<String, dynamic> _$ShoppingListItemSummaryDtoToJson(
  ShoppingListItemSummaryDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'quantity': instance.quantity,
  'purchased': instance.purchased,
  'purchasedAt': instance.purchasedAt?.toIso8601String(),
};

ListItemDto _$ListItemDtoFromJson(Map<String, dynamic> json) => ListItemDto(
  id: (json['id'] as num?)?.toInt(),
  description: json['description'] as String?,
  quantity: (json['quantity'] as num?)?.toInt(),
  product: json['product'] == null
      ? null
      : ProductDto.fromJson(json['product'] as Map<String, dynamic>),
  familyProduct: json['familyProduct'] == null
      ? null
      : FamilyProductDto.fromJson(
          json['familyProduct'] as Map<String, dynamic>,
        ),
  familyList: json['familyList'] == null
      ? null
      : ShoppingListReferenceDto.fromJson(
          json['familyList'] as Map<String, dynamic>,
        ),
  purchased: json['purchased'] as bool?,
  purchasedAt: json['purchasedAt'] == null
      ? null
      : DateTime.parse(json['purchasedAt'] as String),
  purchasedBy: json['purchasedBy'] == null
      ? null
      : PurchasedByDto.fromJson(json['purchasedBy'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ListItemDtoToJson(ListItemDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'description': instance.description,
      'quantity': instance.quantity,
      'product': instance.product,
      'familyProduct': instance.familyProduct,
      'familyList': instance.familyList,
      'purchased': instance.purchased,
      'purchasedAt': instance.purchasedAt?.toIso8601String(),
      'purchasedBy': instance.purchasedBy,
    };

ProductDto _$ProductDtoFromJson(Map<String, dynamic> json) => ProductDto(
  id: (json['id'] as num?)?.toInt(),
  label: json['label'] as String?,
  imageUrl: json['imageUrl'] as String?,
);

Map<String, dynamic> _$ProductDtoToJson(ProductDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'imageUrl': instance.imageUrl,
    };

FamilyProductDto _$FamilyProductDtoFromJson(Map<String, dynamic> json) =>
    FamilyProductDto(
      id: (json['id'] as num?)?.toInt(),
      label: json['label'] as String?,
      description: json['description'] as String?,
      familyId: (json['familyId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FamilyProductDtoToJson(FamilyProductDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'description': instance.description,
      'familyId': instance.familyId,
    };

ShoppingListReferenceDto _$ShoppingListReferenceDtoFromJson(
  Map<String, dynamic> json,
) => ShoppingListReferenceDto(
  id: (json['id'] as num?)?.toInt(),
  description: json['description'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ShoppingListReferenceDtoToJson(
  ShoppingListReferenceDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'createdAt': instance.createdAt?.toIso8601String(),
};

PurchasedByDto _$PurchasedByDtoFromJson(Map<String, dynamic> json) =>
    PurchasedByDto(
      id: (json['id'] as num?)?.toInt(),
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
    );

Map<String, dynamic> _$PurchasedByDtoToJson(PurchasedByDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
    };
