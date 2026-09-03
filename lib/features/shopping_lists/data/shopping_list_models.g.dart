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
