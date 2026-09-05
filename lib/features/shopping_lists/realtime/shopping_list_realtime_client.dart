import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/config/app_config.dart';
import '../../../core/debug/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import 'list_item_purchased_event.dart';

final shoppingListRealtimeClientProvider = Provider<ShoppingListRealtimeClient>(
  (ref) {
    return StompShoppingListRealtimeClient(
      config: ref.watch(appConfigProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    );
  },
);

abstract class ShoppingListRealtimeClient {
  Stream<ListItemPurchasedEvent> subscribeToPurchasedEvents(int listId);
}

class StompShoppingListRealtimeClient implements ShoppingListRealtimeClient {
  StompShoppingListRealtimeClient({
    required AppConfig config,
    required TokenStorage tokenStorage,
  }) : this._(config, tokenStorage);

  StompShoppingListRealtimeClient._(this._config, this._tokenStorage);

  final AppConfig _config;
  final TokenStorage _tokenStorage;

  @override
  Stream<ListItemPurchasedEvent> subscribeToPurchasedEvents(int listId) {
    final streamController = StreamController<ListItemPurchasedEvent>();
    final wsUrl = websocketUrlForApiBaseUrl(_config.apiBaseUrl);
    final destination = purchasedTopicForList(listId);
    StompClient? client;
    StompUnsubscribe? unsubscribe;

    Future<void> activate() async {
      final tokens = await _tokenStorage.read();
      final accessToken = tokens?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        appLogger.debug('Realtime: no access token available for WebSocket');
        await streamController.close();
        return;
      }

      client = StompClient(
        config: StompConfig(
          url: wsUrl,
          reconnectDelay: const Duration(seconds: 5),
          connectionTimeout: const Duration(seconds: 10),
          stompConnectHeaders: {'Authorization': 'Bearer $accessToken'},
          onConnect: (_) {
            appLogger.debug(
              'Realtime: connected and subscribing to purchased events',
            );
            unsubscribe = client?.subscribe(
              destination: destination,
              callback: (frame) => _handleFrame(
                frame.body,
                listId: listId,
                streamController: streamController,
              ),
            );
          },
          onStompError: (frame) {
            appLogger.debug('Realtime: STOMP error received');
            streamController.addError(
              StateError(frame.body ?? 'WebSocket STOMP error'),
            );
          },
          onWebSocketError: (error) {
            appLogger.debug('Realtime: WebSocket connection error');
          },
          onWebSocketDone: () {
            appLogger.debug('Realtime: WebSocket connection closed');
            unsubscribe = null;
          },
        ),
      )..activate();
    }

    streamController.onListen = activate;
    streamController.onCancel = () {
      unsubscribe?.call();
      unsubscribe = null;
      client?.deactivate();
      client = null;
    };

    return streamController.stream;
  }

  void _handleFrame(
    String? body, {
    required int listId,
    required StreamController<ListItemPurchasedEvent> streamController,
  }) {
    if (body == null || body.isEmpty || streamController.isClosed) {
      return;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final event = ListItemPurchasedEvent.fromJson(decoded);
      if (event.appliesToList(listId)) {
        streamController.add(event);
      }
    } on FormatException catch (error) {
      appLogger.debug('Realtime: ignored malformed purchased event: $error');
    } on Object catch (error) {
      appLogger.debug('Realtime: ignored purchased event: $error');
    }
  }
}

final shoppingListPurchasedEventsProvider = StreamProvider.autoDispose
    .family<ListItemPurchasedEvent, int>((ref, listId) {
      return ref
          .watch(shoppingListRealtimeClientProvider)
          .subscribeToPurchasedEvents(listId);
    });
