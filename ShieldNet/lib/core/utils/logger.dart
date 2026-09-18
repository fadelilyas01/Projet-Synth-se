import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('Exception: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }
  }
}
