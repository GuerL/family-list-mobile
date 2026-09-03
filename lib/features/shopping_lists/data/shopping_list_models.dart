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
