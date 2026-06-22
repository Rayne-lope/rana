import 'package:logger/logger.dart';

/// Global application logger wrapper.
///
/// Usage:
/// ```dart
/// AppLogger.d('Tag', 'debug message');
/// AppLogger.i('Tag', 'info message');
/// AppLogger.w('Tag', 'warning message');
/// AppLogger.e('Tag', 'error message', error, stackTrace);
/// ```
abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(),
  );

  static void d(String tag, String message) =>
      _logger.d('[$tag] $message');

  static void i(String tag, String message) =>
      _logger.i('[$tag] $message');

  static void w(String tag, String message) =>
      _logger.w('[$tag] $message');

  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      _logger.e('[$tag] $message', error: error, stackTrace: stackTrace);
}
