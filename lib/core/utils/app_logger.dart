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
  static final Logger _logger = Logger(printer: PrettyPrinter());

  static void d(String tag, String message) => _logger.d('[$tag] $message');

  static void i(String tag, String message) => _logger.i('[$tag] $message');

  static void w(String tag, String message) => _logger.w('[$tag] $message');

  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) => _logger.e('[$tag] $message', error: error, stackTrace: stackTrace);

  static void glParams(String stage, Map<String, dynamic> params) {
    final temp = params['temperature'] ?? 0.0;
    final sat = params['saturation'] ?? 0.0;
    final contrast = params['contrast'] ?? 0.0;
    final grain = params['grain'] ?? 0.0;
    final grainShadowsLimit = params['grainShadowsLimit'] ?? 0.04;
    final grainHighlightsLimit = params['grainHighlightsLimit'] ?? 0.07;
    final vignette = params['vignette'] ?? 0.0;
    final lut = params['lutPath'];
    final strength = params['lutStrength'] ?? 0.0;
    final lightLeakIntensity = params['lightLeakIntensity'] ?? 0.0;
    final lightLeakVariant = params['lightLeakVariant'] ?? -1;
    final dustIntensity = params['dustIntensity'] ?? 0.0;
    final bloomThreshold = params['bloomThreshold'] ?? 0.8;
    final bloomIntensity = params['bloomIntensity'] ?? 0.0;
    final halationIntensity = params['halationIntensity'] ?? 0.0;
    final lensDistortionStrength = params['lensDistortionStrength'] ?? 0.0;
    final msg =
        '[$stage] temp=$temp sat=$sat contrast=$contrast '
        'grain=$grain grainShadowsLimit=$grainShadowsLimit '
        'grainHighlightsLimit=$grainHighlightsLimit '
        'vignette=$vignette lut=$lut strength=$strength '
        'lightLeakIntensity=$lightLeakIntensity '
        'lightLeakVariant=$lightLeakVariant dustIntensity=$dustIntensity '
        'bloomThreshold=$bloomThreshold bloomIntensity=$bloomIntensity '
        'halationIntensity=$halationIntensity '
        'lensDistortionStrength=$lensDistortionStrength';
    d('GlParams', msg);
  }
}
