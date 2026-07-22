import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/services/camera_feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraFeedbackService', () {
    test('singleton instance initializes cleanly', () {
      final service = CameraFeedbackService.instance;
      expect(service, isNotNull);
    });

    test('feedback triggers execute without throwing exceptions', () async {
      final service = CameraFeedbackService.instance;

      await expectLater(
        service.playShutter(playSound: false, playHaptic: false),
        completes,
      );
      await expectLater(
        service.playDialTick(playSound: false, playHaptic: false),
        completes,
      );
      await expectLater(
        service.playFilmWind(playSound: false, playHaptic: false),
        completes,
      );
      await expectLater(
        service.playRollComplete(playSound: false, playHaptic: false),
        completes,
      );
    });
  });
}
