import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/debug/app_logger.dart';
import '../../../core/push/push_notification_service.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  Completer<bool>? _refreshCompleter;

  @override
  Future<AuthSession?> build() async {
    appLogger.debug('Auth: restoring session from secure storage');
    final tokens = await ref.read(tokenStorageProvider).read();
    if (tokens == null || !tokens.isComplete) {
      appLogger.debug('Auth: no stored session found');
      return null;
    }

    try {
      appLogger.debug('Auth: stored tokens found, validating with /auth/user');
      final user = await ref.read(authApiProvider).getCurrentUser();
      appLogger.debug('Auth: session restored for ${user.email}');
      return AuthSession(user: user);
    } catch (_) {
      appLogger.debug('Auth: session restoration failed, clearing tokens');
      await ref.read(tokenStorageProvider).clear();
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();

    try {
      appLogger.debug('Auth: login started for $email');
      final loginResponse = await ref
          .read(authApiProvider)
          .login(LoginUserDto(email: email, password: password));
      appLogger.debug('Auth: login succeeded, storing tokens');
      await ref
          .read(tokenStorageProvider)
          .write(
            AuthTokens(
              accessToken: loginResponse.accessToken,
              refreshToken: loginResponse.refreshToken,
            ),
          );
      appLogger.debug('Auth: fetching current user after login');
      final user = await ref.read(authApiProvider).getCurrentUser();
      appLogger.debug('Auth: authenticated as ${user.email}');
      state = AsyncData(AuthSession(user: user));
    } catch (error, stackTrace) {
      final apiError = ApiError.fromObject(error);
      appLogger.debug('Auth: login failed: ${apiError.message}');
      await ref.read(tokenStorageProvider).clear();
      state = AsyncError(apiError, stackTrace);
      throw apiError;
    }
  }

  Future<bool> refreshAccessToken() async {
    final activeRefresh = _refreshCompleter;
    if (activeRefresh != null) {
      return activeRefresh.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final tokens = await ref.read(tokenStorageProvider).read();
      if (tokens == null || tokens.refreshToken.isEmpty) {
        appLogger.debug('Auth: cannot refresh because no refresh token exists');
        await _clearSession();
        completer.complete(false);
        return false;
      }

      appLogger.debug('Auth: calling /auth/refresh');
      final response = await ref
          .read(rawAuthApiProvider)
          .refresh(tokens.refreshToken);
      final accessToken = response['accessToken'];

      if (accessToken is! String || accessToken.isEmpty) {
        appLogger.debug('Auth: refresh response did not include accessToken');
        await _clearSession();
        completer.complete(false);
        return false;
      }

      await ref.read(tokenStorageProvider).updateAccessToken(accessToken);
      appLogger.debug('Auth: access token refreshed');
      completer.complete(true);
      return true;
    } catch (_) {
      appLogger.debug('Auth: refresh request failed');
      await _clearSession();
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> logout() async {
    await ref.read(pushNotificationServiceProvider).unregisterForLogout();
    // The current backend has no logout/revocation endpoint, so logout is local
    // after best-effort device unregister: remove stored tokens and return to
    // unauthenticated state.
    appLogger.debug('Auth: local logout, clearing tokens');
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }
}
