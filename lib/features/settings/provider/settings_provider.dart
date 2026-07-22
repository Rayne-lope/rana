import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that manages whether the viewfinder 3x3 grid lines are visible.
final gridLinesProvider = StateProvider<bool>((ref) => true);

/// The format used for the final, processed camera image.
///
/// The values are part of the Android method-channel contract. Do not rename
/// them without keeping the Android parser backward compatible.
enum OutputQuality {
  standardJpeg(
    storageValue: 'standard_jpeg',
    label: 'Standard',
    detail: 'JPEG 88 · Smaller files, broadly compatible',
  ),
  highJpeg(
    storageValue: 'high_jpeg',
    label: 'High',
    detail: 'JPEG 95 · Best compatible quality',
  ),
  efficientHeic(
    storageValue: 'efficient_heic',
    label: 'Efficient',
    detail: 'HEIC 90 · Smaller high-quality files',
  );

  const OutputQuality({
    required this.storageValue,
    required this.label,
    required this.detail,
  });

  final String storageValue;
  final String label;
  final String detail;

  static OutputQuality fromStorageValue(String? value) => values.firstWhere(
    (quality) => quality.storageValue == value,
    orElse: () => OutputQuality.highJpeg,
  );
}

/// Whether this device can encode a HEIC file after Rana's GL processing.
class OutputCapabilities {
  const OutputCapabilities({
    required this.isHeicSupported,
    this.unavailableReason,
  });

  factory OutputCapabilities.fromMap(Map<String, dynamic> map) =>
      OutputCapabilities(
        isHeicSupported: map['isHeicSupported'] == true,
        unavailableReason: map['unavailableReason'] as String?,
      );

  final bool isHeicSupported;
  final String? unavailableReason;

  String get unavailableMessage => switch (unavailableReason) {
    'android_version' => 'Requires Android 9 or later',
    'hevc_encoder_unavailable' => 'HEVC encoder unavailable on this device',
    _ => 'Unavailable on this device',
  };
}

const _outputQualityStorageKey = 'rana.output_quality.v1';

/// Persists the output preference. High JPEG is the safe migration default:
/// it matches Rana's previous JPEG 95 export behavior.
class OutputQualityController extends AsyncNotifier<OutputQuality> {
  @override
  Future<OutputQuality> build() async {
    final preferences = await SharedPreferences.getInstance();
    return OutputQuality.fromStorageValue(
      preferences.getString(_outputQualityStorageKey),
    );
  }

  Future<void> setQuality(OutputQuality quality) async {
    // Make the choice visible immediately; persistence failure is retried on
    // the next change rather than blocking capture.
    state = AsyncData(quality);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_outputQualityStorageKey, quality.storageValue);
  }
}

final outputQualityProvider =
    AsyncNotifierProvider<OutputQualityController, OutputQuality>(
      OutputQualityController.new,
    );

final outputCapabilitiesProvider = FutureProvider<OutputCapabilities>((
  ref,
) async {
  try {
    final capabilities = await CameraPlatformService().getOutputCapabilities();
    return OutputCapabilities.fromMap(capabilities);
  } on Object {
    // Settings remains usable without a native response (including widget
    // tests); only the optional HEIC choice is unavailable.
    return const OutputCapabilities(
      isHeicSupported: false,
      unavailableReason: 'hevc_encoder_unavailable',
    );
  }
});

const _soundEffectsStorageKey = 'rana.sound_effects_enabled.v1';
const _hapticFeedbackStorageKey = 'rana.haptic_feedback_enabled.v1';

class SoundEffectsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEffectsStorageKey) ?? true;
  }

  Future<void> setEnabled({required bool enabled}) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsStorageKey, enabled);
  }
}

final soundEffectsEnabledProvider =
    AsyncNotifierProvider<SoundEffectsController, bool>(
      SoundEffectsController.new,
    );

class HapticFeedbackController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticFeedbackStorageKey) ?? true;
  }

  Future<void> setEnabled({required bool enabled}) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticFeedbackStorageKey, enabled);
  }
}

final hapticFeedbackEnabledProvider =
    AsyncNotifierProvider<HapticFeedbackController, bool>(
      HapticFeedbackController.new,
    );
