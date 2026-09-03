import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';
import 'network_debug_interceptor.dart';

final rawDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = buildApiClient(config);
  dio.interceptors.add(NetworkDebugInterceptor());
  return dio;
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = buildApiClient(config);
  dio.interceptors.add(AuthInterceptor(ref: ref, dio: dio));
  dio.interceptors.add(NetworkDebugInterceptor());
  return dio;
});
