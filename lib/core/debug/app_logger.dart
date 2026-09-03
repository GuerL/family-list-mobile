import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger();

  void debug(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[FamilyList] $message');
  }
}

const appLogger = AppLogger();
