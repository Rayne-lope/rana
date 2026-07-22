import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/src/features/camera/view/camera_screen_coordinator.dart';
import 'package:rana/src/features/camera/view/camera_ui_mode.dart';

void main() {
  CameraScreenCoordinator coordinator({
    void Function()? onRelease,
    void Function()? onResume,
    void Function()? onMetrics,
  }) => CameraScreenCoordinator(
    sessionId: 'test-session',
    releaseCamera: onRelease ?? () {},
    resumeCamera: onResume ?? () {},
    scheduleMetricsCheck: onMetrics ?? () {},
  );

  test('camera primary modes are mutually exclusive', () {
    final subject = coordinator();

    subject.transitionTo(const CameraStyleEditingMode());
    expect(subject.mode, isA<CameraStyleEditingMode>());
    expect(subject.mode, isNot(isA<CameraUndertoneEditingMode>()));

    subject.transitionTo(const CameraUndertoneEditingMode());
    expect(subject.mode, isA<CameraUndertoneEditingMode>());
    expect(subject.mode, isNot(isA<CameraStyleEditingMode>()));
  });

  test('Film Roll route serializes ownership and restores prior mode', () {
    final subject = coordinator()
      ..transitionTo(const CameraFilmSelectionMode());

    expect(subject.beginFilmRollRoute(CameraFilmRollRoute.start), isTrue);
    expect(subject.mode, isA<CameraFilmRollManagementMode>());
    expect(subject.beginFilmRollRoute(CameraFilmRollRoute.completion), isFalse);
    expect(
      () => subject.transitionTo(const CameraCaptureMode()),
      throwsStateError,
    );

    expect(subject.finishFilmRollRoute(CameraFilmRollRoute.start), isTrue);
    expect(subject.mode, isA<CameraFilmSelectionMode>());
    expect(subject.hasFilmRollRoute, isFalse);
  });

  test(
    'lifecycle ignores inactive and releases only terminal background states',
    () async {
      var releases = 0;
      var resumes = 0;
      final subject = coordinator(
        onRelease: () => releases += 1,
        onResume: () => resumes += 1,
      );

      subject.handleLifecycle(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(releases, 0);
      expect(resumes, 0);

      subject.handleLifecycle(AppLifecycleState.paused);
      subject.handleLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(releases, 1);
      expect(resumes, 1);
    },
  );

  test('metrics notification delegates one stability check', () {
    var checks = 0;
    final subject = coordinator(onMetrics: () => checks += 1);

    subject.handleMetricsChanged();

    expect(checks, 1);
  });
}
