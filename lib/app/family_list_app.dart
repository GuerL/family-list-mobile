import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/push/push_notification_payload.dart';
import '../core/push/push_notification_service.dart';
import '../features/authentication/presentation/auth_controller.dart';
import '../features/shopping_lists/presentation/shopping_list_detail_screen.dart';
import 'router.dart';
import 'theme.dart';

class FamilyListApp extends ConsumerWidget {
  const FamilyListApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authControllerProvider);
    final session = authState.whenOrNull(data: (session) => session);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (session == null) {
        ref.read(pushNotificationServiceProvider).stopLocal();
        return;
      }
      unawaited(ref.read(pushNotificationServiceProvider).start());
      final payload = ref.read(pushNavigationIntentProvider);
      if (payload != null && payload.canOpenShoppingList) {
        _openPushPayload(ref, router, payload);
      }
    });

    ref.listen(authControllerProvider, (_, next) {
      final nextSession = next.whenOrNull(data: (session) => session);
      if (nextSession == null) {
        ref.read(pushNotificationServiceProvider).stopLocal();
        return;
      }
      unawaited(ref.read(pushNotificationServiceProvider).start());
      final payload = ref.read(pushNavigationIntentProvider);
      if (payload != null && payload.canOpenShoppingList) {
        _openPushPayload(ref, router, payload);
      }
    });
    ref.listen(pushNavigationIntentProvider, (_, payload) {
      if (payload == null || !payload.canOpenShoppingList) {
        return;
      }
      _openPushPayload(ref, router, payload);
    });

    return MaterialApp.router(
      title: 'FamilyList',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  void _openPushPayload(
    WidgetRef ref,
    GoRouter router,
    PushNotificationPayload payload,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref
          .read(authControllerProvider)
          .whenOrNull(data: (session) => session);
      if (session == null) {
        return;
      }
      router.go(ShoppingListDetailScreen.routePath(payload.listId!));
      ref.read(pushNavigationIntentProvider.notifier).clear();
    });
  }
}
