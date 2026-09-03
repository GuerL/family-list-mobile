import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'auth_models.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

final rawAuthApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(rawDioProvider));
});

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  Future<LoginResponse> login(LoginUserDto request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: request.toJson(),
    );
    return LoginResponse.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<AuthUserDto> getCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/user');
    return AuthUserDto.fromJson(response.data ?? <String, dynamic>{});
  }
}
