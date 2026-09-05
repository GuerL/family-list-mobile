# familylist

Family List for IOS and Android

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Push notifications

FamilyList uses Firebase Cloud Messaging through `firebase_core` and
`firebase_messaging`. Push registration starts only after a user is
authenticated. If notification permission is denied or Firebase is not
configured, the app remains usable and push is skipped.

Do not commit Firebase secrets or generated environment-specific files unless
your release process explicitly allows them. Configure Firebase per environment:

- Run `flutterfire configure` for the Firebase project used by that environment.
- Android: add the generated `android/app/google-services.json` and required
  Gradle configuration from FlutterFire.
- iOS: add the generated `ios/Runner/GoogleService-Info.plist` to the Runner
  target in Xcode.
- iOS: enable Push Notifications and Background Modes > Remote notifications
  for the Runner target.
- iOS: upload/configure the APNs authentication key or certificate in Firebase
  Cloud Messaging settings.
- Physical iOS devices are required for APNs/FCM push testing.
