import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/providers/global_error_provider.dart';
import 'package:rana/core/providers/permission_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionController', () {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          log.add(methodCall);
          if (methodCall.method == 'checkPermissionStatus') {
            // Mock permissions check
            final permissionValue = methodCall.arguments as int;
            // Camera (1) storage (22) photos (9)
            if (permissionValue == 1) {
              return 1; // Granted
            }
            return 0; // Denied
          } else if (methodCall.method == 'requestPermissions') {
            // Mock request returns
            final args = methodCall.arguments as List<dynamic>;
            final results = <int, int>{};
            for (final p in args) {
              results[p as int] = 1; // Grant all requested
            }
            return results;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('initial state has checking true and hasCamera/hasStorage false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(permissionControllerProvider);
      expect(state.isChecking, isTrue);
      expect(state.hasCamera, isFalse);
      expect(state.hasStorage, isFalse);
      expect(state.isAllGranted, isFalse);
    });

    test('checkPermissions queries platform and updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(permissionControllerProvider.notifier);
      await controller.checkPermissions();

      final state = container.read(permissionControllerProvider);
      expect(state.isChecking, isFalse);
      expect(state.hasCamera, isTrue); // Mock check camera returns 1 (granted)
      expect(state.hasStorage, isFalse); // Storage returns 0 (denied)
      expect(state.isAllGranted, isFalse);
    });

    test(
      'requestPermissions requests via platform and updates state',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller =
            container.read(permissionControllerProvider.notifier);
        await controller.requestPermissions();

        final state = container.read(permissionControllerProvider);
        expect(state.isChecking, isFalse);
        expect(state.hasCamera, isTrue); // Mock requests returns granted
        expect(state.hasStorage, isTrue);
        expect(state.isAllGranted, isTrue);
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
