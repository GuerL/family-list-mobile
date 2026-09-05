import '../data/shopping_list_models.dart';

const listItemPurchasedUpdatedType = 'LIST_ITEM_PURCHASED_UPDATED';

class ListItemPurchasedEvent {
  const ListItemPurchasedEvent({
    required this.type,
    required this.familyListId,
    required this.itemId,
    required this.purchased,
    this.purchasedAt,
    this.purchasedBy,
  });

  final String type;
  final int familyListId;
  final int itemId;
  final bool purchased;
  final DateTime? purchasedAt;
  final PurchasedByDto? purchasedBy;

  factory ListItemPurchasedEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final familyListId = json['familyListId'];
    final itemId = json['itemId'];
    final purchased = json['purchased'];
    final purchasedAt = json['purchasedAt'];
    final purchasedBy = json['purchasedBy'];

    if (type is! String ||
        familyListId is! int ||
        itemId is! int ||
        purchased is! bool) {
      throw const FormatException('Malformed purchased item event.');
    }

    return ListItemPurchasedEvent(
      type: type,
      familyListId: familyListId,
      itemId: itemId,
      purchased: purchased,
      purchasedAt: purchasedAt is String
          ? DateTime.tryParse(purchasedAt)
          : null,
      purchasedBy: purchasedBy is Map<String, dynamic>
          ? PurchasedByDto.fromJson(purchasedBy)
          : null,
    );
  }

  bool appliesToList(int listId) {
    return type == listItemPurchasedUpdatedType && familyListId == listId;
  }
}

String purchasedTopicForList(int listId) {
  return '/topic/family-lists/$listId/purchased';
}

String websocketUrlForApiBaseUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  final scheme = switch (uri.scheme) {
    'https' => 'wss',
    'http' => 'ws',
    'wss' || 'ws' => uri.scheme,
    _ => 'wss',
  };
  return uri.replace(scheme: scheme, path: '/ws', query: null).toString();
}
