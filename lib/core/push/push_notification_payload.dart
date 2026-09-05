class PushNotificationPayload {
  const PushNotificationPayload({
    required this.type,
    this.familyId,
    this.listId,
    this.itemId,
  });

  final String type;
  final int? familyId;
  final int? listId;
  final int? itemId;

  static const listItemCreated = 'LIST_ITEM_CREATED';

  bool get canOpenShoppingList =>
      type == listItemCreated && familyId != null && listId != null;

  factory PushNotificationPayload.fromData(Map<String, dynamic> data) {
    return PushNotificationPayload(
      type: data['type']?.toString() ?? '',
      familyId: _parseInt(data['familyId']),
      listId: _parseInt(data['listId']),
      itemId: _parseInt(data['itemId']),
    );
  }

  static int? _parseInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}
