import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/presentation/auth_controller.dart';
import '../debug/app_logger.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.ref, required this.dio});

  static const _retriedKey = 'familylist.retriedAfterRefresh';

  final Ref ref;
  final Dio dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await ref.read(tokenStorageProvider).read();
    if (tokens != null && tokens.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      appLogger.debug('Auth: attached bearer token to ${options.path}');
    } else {
      appLogger.debug('Auth: no access token available for ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;

    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    appLogger.debug('Auth: received 401, attempting token refresh');
    final refreshed = await ref
        .read(authControllerProvider.notifier)
        .refreshAccessToken();

    if (!refreshed) {
      appLogger.debug('Auth: token refresh failed');
      handler.next(err);
      return;
    }

    final tokens = await ref.read(tokenStorageProvider).read();
    if (tokens == null) {
      appLogger.debug('Auth: refresh succeeded but no token was stored');
      handler.next(err);
      return;
    }

    requestOptions.extra[_retriedKey] = true;
    requestOptions.headers['Authorization'] = 'Bearer ${tokens.accessToken}';

    try {
      appLogger.debug('Auth: retrying original request ${requestOptions.path}');
      final response = await dio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldAttemptRefresh(DioException err) {
    if (err.response?.statusCode != 401) {
      return false;
    }

    if (err.requestOptions.extra[_retriedKey] == true) {
      return false;
    }

    final path = err.requestOptions.path;
    return !path.endsWith('/auth/login') && !path.endsWith('/auth/refresh');
  }
}
