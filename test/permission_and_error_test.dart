import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/providers/global_error_provider.dart';
import 'package:rana/core/providers/permission_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Separated permission controllers', () {
    const permissionChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    const cameraChannel = MethodChannel('com.rana.app/camera_control');
    final log = <MethodCall>[];
    var cameraStatus = 1;
    var galleryStatus = 0;
    var galleryRequestStatus = 1;
    var galleryPermission = 'photos';

    setUp(() {
      log.clear();
      cameraStatus = 1;
      galleryStatus = 0;
      galleryRequestStatus = 1;
      galleryPermission = 'photos';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (
            MethodCall methodCall,
          ) async {
            log.add(methodCall);
            if (methodCall.method == 'checkPermissionStatus') {
              final permissionValue = methodCall.arguments as int;
              if (permissionValue == 1) {
                return cameraStatus;
              }
              return galleryStatus;
            } else if (methodCall.method == 'requestPermissions') {
              // Mock request returns
              final args = methodCall.arguments as List<dynamic>;
              final results = <int, int>{};
              for (final p in args) {
                results[p as int] = p == 1
                    ? cameraStatus
                    : galleryRequestStatus;
              }
              return results;
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'getPermissionCapabilities') {
              return {
                'requiresLegacyStorageForCapture': false,
                'galleryReadPermission': galleryPermission,
              };
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, null);
    });

    test('camera and gallery begin as independent pending states', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(cameraPermissionControllerProvider).isChecking,
        isTrue,
      );
      expect(
        container.read(galleryPermissionControllerProvider).isChecking,
        isTrue,
      );
    });

    test('camera grant is unaffected when gallery access is denied', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(cameraPermissionControllerProvider.notifier)
          .refresh();
      await container
          .read(galleryPermissionControllerProvider.notifier)
          .refresh();

      expect(
        container.read(cameraPermissionControllerProvider).isGranted,
        isTrue,
      );
      expect(
        container.read(galleryPermissionControllerProvider).canRead,
        isFalse,
      );
      expect(
        log.where((call) => call.method == 'checkPermissionStatus').length,
        2,
      );
    });

    test(
      'gallery accepts limited access without changing camera state',
      () async {
        galleryStatus = 3; // PermissionStatus.limited.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(cameraPermissionControllerProvider.notifier)
            .refresh();
        await container
            .read(galleryPermissionControllerProvider.notifier)
            .refresh();

        expect(
          container.read(galleryPermissionControllerProvider).isLimited,
          isTrue,
        );
        expect(
          container.read(galleryPermissionControllerProvider).canRead,
          isTrue,
        );
        expect(
          container.read(cameraPermissionControllerProvider).isGranted,
          isTrue,
        );
      },
    );

    test(
      'gallery request is lazy and uses the platform-selected permission',
      () async {
        galleryPermission = 'storage';
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(galleryPermissionControllerProvider.notifier)
            .requestGalleryAccess();

        expect(
          container.read(galleryPermissionControllerProvider).isGranted,
          isTrue,
        );
        expect(
          log.where((call) => call.method == 'requestPermissions').length,
          1,
        );
        expect(
          container.read(cameraPermissionControllerProvider).isChecking,
          isTrue,
        );
      },
    );
  });

  group('GlobalErrorController', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final error = container.read(globalErrorControllerProvider);
      expect(error, isNull);
    });

    test('setError sets error state and clearError resets it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(globalErrorControllerProvider.notifier);
      final testError = Exception('Fault occurred');
      final testStack = StackTrace.current;

      controller.setError(testError, testStack);

      final errorState = container.read(globalErrorControllerProvider);
      expect(errorState, isNotNull);
      expect(errorState!.error, equals(testError));
      expect(errorState.stackTrace, equals(testStack));

      controller.clearError();
      final clearedState = container.read(globalErrorControllerProvider);
      expect(clearedState, isNull);
    });
  });
}
