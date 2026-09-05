import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';

final pushDevicesApiProvider = Provider<PushDevicesApi>((ref) {
  return PushDevicesApi(ref.watch(dioProvider));
});

class PushDevicesApi {
  const PushDevicesApi(this._dio);

  final Dio _dio;

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
  }) async {
    await _dio.post<void>(
      '/api/devices',
      data: {'fcmToken': fcmToken, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _dio.delete<void>(
      '/api/devices',
      queryParameters: {'fcmToken': fcmToken},
    );
  }
}
