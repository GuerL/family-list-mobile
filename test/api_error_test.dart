import 'package:dio/dio.dart';
import 'package:familylist/core/network/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses backend ApiErrorResponse field errors', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/families'),
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/families'),
        statusCode: 400,
        data: {
          'message': 'Validation failed',
          'status': 400,
          'fieldErrors': {'name': 'Family name is required'},
        },
      ),
    );

    final apiError = ApiError.fromDioException(error);

    expect(apiError.message, 'Validation failed');
    expect(apiError.statusCode, 400);
    expect(apiError.fieldErrors, {'name': 'Family name is required'});
  });

  test('maps 403 responses to a readable message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/families/1'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/api/families/1'),
        statusCode: 403,
      ),
    );

    expect(
      ApiError.fromDioException(error).message,
      'You do not have access to this resource.',
    );
  });
}
