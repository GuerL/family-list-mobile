import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/products/presentation/products_placeholder_screen.dart';
import '../features/authentication/presentation/auth_controller.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/families/presentation/families_screen.dart';
import '../features/families/presentation/family_detail_screen.dart';
import '../features/shopping/presentation/shopping_screen.dart';
import '../features/shopping_lists/data/shopping_list_models.dart';
import '../features/shopping_lists/presentation/shopping_list_detail_screen.dart';
import '../features/shopping_lists/presentation/shopping_lists_screen.dart';
import 'main_scaffold.dart';

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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: FamiliesScreen.routePath,
                builder: (context, state) => const FamiliesScreen(),
                routes: [
                  GoRoute(
                    path: ':familyId',
                    builder: (context, state) {
                      final familyId = int.parse(
                        state.pathParameters['familyId']!,
                      );
                      return FamilyDetailScreen(familyId: familyId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShoppingListsScreen.routePath,
                builder: (context, state) => const ShoppingListsScreen(),
                routes: [
                  GoRoute(
                    path: ':listId',
                    builder: (context, state) {
                      final listId = int.parse(state.pathParameters['listId']!);
                      final list = state.extra is ShoppingListDto
                          ? state.extra! as ShoppingListDto
                          : null;
                      return ShoppingListDetailScreen(
                        listId: listId,
                        listName: list?.description ?? 'List',
                        familyId: list?.family.id,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShoppingScreen.routePath,
                builder: (context, state) => const ShoppingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProductsPlaceholderScreen.routePath,
                builder: (context, state) => const ProductsPlaceholderScreen(),
              ),
            ],
          ),
        ],
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
