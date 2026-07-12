import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/state/camera_state.dart';

void main() {
  test(
    'capture output metadata records HEIC fallback and memory safeguards',
    () {
      final metadata = CaptureOutputMetadata.fromEvent(const {
        'requestedOutputQuality': 'efficient_heic',
        'actualOutputFormat': 'jpeg',
        'outputMimeType': 'image/jpeg',
        'outputWidth': 3000,
        'outputHeight': 4000,
        'fileSizeBytes': 3145728,
        'qualityReduced': true,
        'lutSkipped': true,
        'fallbackReason': 'heic_encode_failed',
      });

      expect(metadata.formatLabel, 'JPEG');
      expect(metadata.fileSizeLabel, '3.0 MB');
      expect(metadata.fallbackReason, 'heic_encode_failed');
      expect(metadata.qualityReduced, isTrue);
      expect(metadata.lutSkipped, isTrue);
    },
  );
}
