import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

class AppConfig {
  const AppConfig();

  static const _defaultBaseUrl = 'https://familylist.guerl.dev';

  String get apiBaseUrl {
    const value = String.fromEnvironment('API_BASE_URL');
    return value.isEmpty ? _defaultBaseUrl : value;
  }
}
