import 'dart:async';

import 'package:dio/dio.dart';
import 'package:familylist/app/router.dart';
import 'package:familylist/core/network/api_error.dart';
import 'package:familylist/core/storage/token_storage.dart';
import 'package:familylist/features/families/data/families_api.dart';
import 'package:familylist/features/families/data/family_models.dart';
import 'package:familylist/features/authentication/data/auth_api.dart';
import 'package:familylist/features/authentication/data/auth_models.dart';
import 'package:familylist/features/authentication/presentation/auth_controller.dart';
import 'package:familylist/features/authentication/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('register form validates required fields', (tester) async {
    await _pumpRegisterScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.text('First name is required.'), findsOneWidget);
    expect(find.text('Last name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Confirm your password.'), findsOneWidget);
  });

  testWidgets('register form validates email format', (tester) async {
    await _pumpRegisterScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Test');
    await tester.enterText(find.byType(TextFormField).at(1), 'User');
    await tester.enterText(find.byType(TextFormField).at(2), 'invalid');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret');
    await tester.enterText(find.byType(TextFormField).at(4), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('register form validates password confirmation', (tester) async {
    await _pumpRegisterScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Test');
    await tester.enterText(find.byType(TextFormField).at(1), 'User');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(3), 'secret');
    await tester.enterText(find.byType(TextFormField).at(4), 'different');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('register prevents duplicate submissions while loading', (
    tester,
  ) async {
    final api = _FakeAuthApi();
    final storage = _FakeTokenStorage();
    final registerCompleter = Completer<LoginResponse>();
    api.registerCompleter = registerCompleter;

    await _pumpRegisterScreen(tester, api: api, storage: storage);
    await _enterValidRegistration(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(api.registerCalls, hasLength(1));

    registerCompleter.complete(
      const LoginResponse(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresIn: 3600,
      ),
    );
    await tester.pumpAndSettle();
  });

  test(
    'successful registration stores tokens and authenticates session',
    () async {
      final api = _FakeAuthApi();
      final storage = _FakeTokenStorage();
      final container = ProviderContainer(
        overrides: [
          authApiProvider.overrideWithValue(api),
          tokenStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .register(
            firstName: 'Test',
            lastName: 'User',
            email: 'test@example.com',
            password: 'secret',
          );

      expect(api.registerCalls.single.email, 'test@example.com');
      expect(storage.tokens?.accessToken, 'access-token');
      expect(storage.tokens?.refreshToken, 'refresh-token');
      expect(
        container.read(authControllerProvider).value?.user.email,
        'test@example.com',
      );
    },
  );

  test('registration maps backend duplicate email validation', () async {
    final api = _FakeAuthApi(
      registerError: const ApiError(
        message: 'Email is already taken.',
        statusCode: 409,
      ),
    );
    final storage = _FakeTokenStorage();
    final container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .register(
            firstName: 'Test',
            lastName: 'User',
            email: 'test@example.com',
            password: 'secret',
          ),
      throwsA(
        isA<ApiError>()
            .having(
              (error) => error.message,
              'message',
              'An account already exists with this email.',
            )
            .having(
              (error) => error.fieldErrors['email'],
              'email error',
              'An account already exists with this email.',
            ),
      ),
    );
    expect(storage.tokens, isNull);
  });

  testWidgets('authenticated users are redirected away from register', (
    tester,
  ) async {
    final storage = _FakeTokenStorage()
      ..tokens = const AuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );
    final container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(_FakeAuthApi()),
        tokenStorageProvider.overrideWithValue(storage),
        familiesApiProvider.overrideWithValue(_FakeFamiliesApi()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(RegisterScreen.routePath);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/families');
  });
}

Future<void> _pumpRegisterScreen(
  WidgetTester tester, {
  _FakeAuthApi? api,
  _FakeTokenStorage? storage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(api ?? _FakeAuthApi()),
        tokenStorageProvider.overrideWithValue(storage ?? _FakeTokenStorage()),
      ],
      child: const MaterialApp(home: RegisterScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterValidRegistration(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Test');
  await tester.enterText(find.byType(TextFormField).at(1), 'User');
  await tester.enterText(find.byType(TextFormField).at(2), 'test@example.com');
  await tester.enterText(find.byType(TextFormField).at(3), 'secret');
  await tester.enterText(find.byType(TextFormField).at(4), 'secret');
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.registerError}) : super(Dio());

  final ApiError? registerError;
  final registerCalls = <RegisterUserDto>[];
  Completer<LoginResponse>? registerCompleter;

  @override
  Future<LoginResponse> register(RegisterUserDto request) async {
    registerCalls.add(request);
    if (registerError != null) {
      throw registerError!;
    }
    final completer = registerCompleter;
    if (completer != null) {
      return completer.future;
    }
    return const LoginResponse(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 3600,
    );
  }

  @override
  Future<AuthUserDto> getCurrentUser() async {
    return const AuthUserDto(
      fullName: 'Test User',
      email: 'test@example.com',
      roles: ['ROLE_USER'],
    );
  }
}

class _FakeTokenStorage implements TokenStorage {
  AuthTokens? tokens;
  var clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    tokens = null;
  }

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> updateAccessToken(String accessToken) async {
    final current = tokens;
    if (current != null) {
      tokens = AuthTokens(
        accessToken: accessToken,
        refreshToken: current.refreshToken,
      );
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}

class _FakeFamiliesApi extends FamiliesApi {
  _FakeFamiliesApi() : super(Dio());

  @override
  Future<List<FamilyDto>> getFamilies() async => const [];
}
