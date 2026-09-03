import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  static ApiError fromObject(Object error) {
    if (error is ApiError) {
      return error;
    }

    if (error is DioException) {
      return fromDioException(error);
    }

    return ApiError(
      message: kDebugMode
          ? 'Something went wrong: ${error.runtimeType}'
          : 'Something went wrong.',
    );
  }

  static ApiError fromDioException(DioException error) {
    final response = error.response;
    final data = response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      final fieldErrors = data['fieldErrors'];
      return ApiError(
        message: message is String && message.isNotEmpty
            ? message
            : _messageForStatus(response?.statusCode),
        statusCode: response?.statusCode,
        fieldErrors: fieldErrors is Map
            ? fieldErrors.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              )
            : const {},
      );
    }

    if (data is String && data.isNotEmpty) {
      return ApiError(message: data, statusCode: response?.statusCode);
    }

    if (_isNetworkError(error)) {
      return const ApiError(
        message:
            'Cannot reach the server. Check your connection and try again.',
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiError(message: 'The request timed out. Try again.');
    }

    return ApiError(
      message: _messageForStatus(response?.statusCode),
      statusCode: response?.statusCode,
    );
  }

  static bool _isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.error is SocketException;
  }

  static String _messageForStatus(int? statusCode) {
    if (statusCode != null && statusCode >= 500) {
      return 'The server could not complete the request.';
    }

    return switch (statusCode) {
      400 => 'The request was invalid.',
      401 => 'Your session has expired. Sign in again.',
      403 => 'You do not have access to this resource.',
      404 => 'The requested resource was not found.',
      _ => 'Something went wrong.',
    };
  }

  @override
  String toString() => message;
}
