import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  bool get isComplete => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}

abstract class TokenStorage {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> updateAccessToken(String accessToken);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({this.secureStorage = const FlutterSecureStorage()});

  static const _accessTokenKey = 'familylist.accessToken';
  static const _refreshTokenKey = 'familylist.refreshToken';

  final FlutterSecureStorage secureStorage;

  @override
  Future<AuthTokens?> read() async {
    final accessToken = await secureStorage.read(key: _accessTokenKey);
    final refreshToken = await secureStorage.read(key: _refreshTokenKey);

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await secureStorage.write(key: _accessTokenKey, value: tokens.accessToken);
    await secureStorage.write(
      key: _refreshTokenKey,
      value: tokens.refreshToken,
    );
  }

  @override
  Future<void> updateAccessToken(String accessToken) async {
    await secureStorage.write(key: _accessTokenKey, value: accessToken);
  }

  @override
  Future<void> clear() async {
    await secureStorage.delete(key: _accessTokenKey);
    await secureStorage.delete(key: _refreshTokenKey);
  }
}
