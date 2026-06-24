import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/debug/provider/consistency_debug_provider.dart';
import 'package:rana/features/debug/view/consistency_debug_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConsistencyDebugScreen Tests', () {
    const channel = MethodChannel('com.rana.app/camera_control');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('renders empty state before params are recorded', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, const GlParamsState());

      expect(
        find.text(
          'No rendering parameters recorded yet.\n'
          'Interact with the camera preview or capture an '
          'image to populate parameters.',
        ),
        findsOneWidget,
      );
      expect(find.text('PARAMETER COMPARISON'), findsOneWidget);
    });

    testWidgets(
      'shows style params as consistent when preview matches export',
      (WidgetTester tester) async {
        final params = _params(
          tone: 24,
          color: -18,
          textureVal: 36,
          styleStrength: 82,
          undertoneX: -0.5,
          undertoneY: 0.25,
        );

        await _pumpScreen(
          tester,
          GlParamsState(lastPreviewParams: params, lastExportParams: params),
        );

        expect(find.text('PIPELINES CONSISTENT'), findsOneWidget);
        expect(find.text('tone'), findsOneWidget);
        expect(find.text('color'), findsOneWidget);
        expect(find.text('textureVal'), findsOneWidget);
        expect(find.text('styleStrength'), findsOneWidget);
        expect(find.text('undertoneX'), findsOneWidget);
        expect(find.text('undertoneY'), findsOneWidget);
        expect(find.text('24.00'), findsNWidgets(2));
        expect(find.text('-18.00'), findsNWidgets(2));
        expect(find.text('36.00'), findsNWidgets(2));
        expect(find.text('82.00'), findsNWidgets(2));
        expect(find.text('-0.50'), findsNWidgets(2));
        expect(find.text('0.25'), findsNWidgets(2));
      },
    );

    testWidgets('flags divergence when a style param differs', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(
        tester,
        GlParamsState(
          lastPreviewParams: _params(tone: 24),
          lastExportParams: _params(tone: 25),
        ),
      );

      expect(find.text('DIVERGENCE DETECTED'), findsOneWidget);
      expect(find.text('24.00'), findsOneWidget);
      expect(find.text('25.00'), findsOneWidget);
    });

    testWidgets('uses captured preview params for export comparison', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(
        tester,
        GlParamsState(
          lastPreviewParams: _params(tone: 77),
          lastCapturedPreviewParams: _params(tone: 88),
          lastExportParams: _params(tone: 88),
        ),
      );

      expect(find.text('PIPELINES CONSISTENT'), findsOneWidget);
      expect(find.text('88.00'), findsNWidgets(2));
      expect(find.text('77.00'), findsNothing);
    });

    testWidgets('runs native offline shader test with current preview params', (
      WidgetTester tester,
    ) async {
      final params = _params(tone: 12, undertoneX: 0.4);
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            capturedCall = call;
            return {'filePath': '/tmp/rana-offline-test.jpg'};
          });

      await _pumpScreen(tester, GlParamsState(lastPreviewParams: params));

      await tester.ensureVisible(find.text('Run Native Offline Shader Test'));
      await tester.tap(find.text('Run Native Offline Shader Test'));
      await tester.pumpAndSettle();

      expect(capturedCall?.method, equals('testOfflineProcessing'));
      expect(capturedCall?.arguments, equals(params));
      expect(
        find.text('Test Success! Output saved at:\n/tmp/rana-offline-test.jpg'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpScreen(WidgetTester tester, GlParamsState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [consistencyDebugProvider.overrideWith((ref) => state)],
      child: const MaterialApp(home: ConsistencyDebugScreen()),
    ),
  );
}

Map<String, dynamic> _params({
  double tone = 0,
  double color = 0,
  double textureVal = 0,
  double styleStrength = 100,
  double undertoneX = 0,
  double undertoneY = 0,
}) => <String, dynamic>{
  'temperature': 0.3,
  'saturation': 0.1,
  'contrast': 0.0,
  'grain': 0.1,
  'vignette': 0.05,
  'lutPath': 'assets/luts/rana_warm_v1.png',
  'lutStrength': 1.0,
  'lightLeakIntensity': 0.22,
  'lightLeakVariant': 1,
  'dustIntensity': 0.06,
  'bloomThreshold': 0.65,
  'bloomIntensity': 0.1,
  'halationIntensity': 0.08,
  'lensDistortionStrength': 0.06,
  'tone': tone,
  'color': color,
  'textureVal': textureVal,
  'styleStrength': styleStrength,
  'undertoneX': undertoneX,
  'undertoneY': undertoneY,
  'grainSize': 1.0,
  'softness': 0.0,
};
