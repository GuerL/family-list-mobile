import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../debug/app_logger.dart';
import 'push_devices_api.dart';
import 'push_notification_payload.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref: ref);
  ref.onDispose(service.dispose);
  return service;
});

final pushNavigationIntentProvider =
    NotifierProvider<PushNavigationIntent, PushNotificationPayload?>(
      PushNavigationIntent.new,
    );

class PushNavigationIntent extends Notifier<PushNotificationPayload?> {
  @override
  PushNotificationPayload? build() => null;

  void setPayload(PushNotificationPayload payload) {
    state = payload;
  }

  void clear() {
    state = null;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    return;
  }
}

class PushNotificationService {
  PushNotificationService({required this._ref});

  final Ref _ref;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  bool _started = false;
  bool _firebaseReady = false;
  String? _registeredToken;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    if (!await _ensureFirebaseInitialized()) {
      _started = false;
      return;
    }

    final messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      appLogger.debug('Push: notification permission denied');
      return;
    }

    await _registerCurrentToken();
    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen(
      _registerToken,
      onError: (Object error) =>
          appLogger.debug('Push: token refresh failed: $error'),
    );
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _tapSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> unregisterForLogout() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null || token.isEmpty) {
      stopLocal();
      return;
    }

    try {
      await _ref.read(pushDevicesApiProvider).unregisterDeviceToken(token);
      appLogger.debug('Push: unregistered FCM token for logout');
    } catch (error) {
      appLogger.debug('Push: failed to unregister token on logout: $error');
    } finally {
      stopLocal();
    }
  }

  void stopLocal() {
    _started = false;
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_tapSubscription?.cancel());
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _tapSubscription = null;
  }

  void dispose() {
    stopLocal();
  }

  Future<bool> _ensureFirebaseInitialized() async {
    if (_firebaseReady) {
      return true;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
      return true;
    } catch (error) {
      appLogger.debug(
        'Push: Firebase is not configured yet, push disabled: $error',
      );
      return false;
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        appLogger.debug('Push: Firebase returned no FCM token');
        return;
      }
      await _registerToken(token);
    } catch (error) {
      appLogger.debug('Push: failed to obtain FCM token: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _ref
          .read(pushDevicesApiProvider)
          .registerDevice(fcmToken: token, platform: _platformName());
      _registeredToken = token;
      appLogger.debug('Push: FCM token registered');
    } catch (error) {
      appLogger.debug('Push: failed to register FCM token: $error');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final payload = PushNotificationPayload.fromData(message.data);
    appLogger.debug('Push: foreground message received: ${payload.type}');
  }

  void _handleNotificationTap(RemoteMessage message) {
    final payload = PushNotificationPayload.fromData(message.data);
    _ref.read(pushNavigationIntentProvider.notifier).setPayload(payload);
  }

  String _platformName() {
    if (kIsWeb) {
      return 'WEB';
    }
    if (Platform.isIOS) {
      return 'IOS';
    }
    if (Platform.isAndroid) {
      return 'ANDROID';
    }
    return 'UNKNOWN';
  }
}
