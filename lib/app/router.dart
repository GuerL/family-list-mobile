import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/auth_controller.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/families/presentation/families_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: FamiliesScreen.routePath,
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: LoginScreen.routePath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: FamiliesScreen.routePath,
        builder: (context, state) => const FamiliesScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoginRoute = state.matchedLocation == LoginScreen.routePath;

      if (authState.isLoading) {
        return null;
      }

      final session = authState.whenOrNull(data: (session) => session);
      final isAuthenticated = session != null;
      if (!isAuthenticated && !isLoginRoute) {
        return LoginScreen.routePath;
      }

      if (isAuthenticated && isLoginRoute) {
        return FamiliesScreen.routePath;
      }

      return null;
    },
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
