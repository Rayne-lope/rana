import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/widgets/preset_thumbnail_widget.dart';

void main() {
  const testPreset = PresetModel(
    id: 'test_preset',
    name: 'Test Preset',
    category: 'Test Category',
    color: PresetColor(
      temperature: 0.1,
      contrast: 0.2,
      saturation: 0.3,
    ),
    grain: PresetGrain(intensity: 0.4),
    vignette: PresetVignette(intensity: 0.5),
  );

  group('PresetThumbnailWidget Tests', () {
    testWidgets('renders successfully with given size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PresetThumbnailWidget(
              preset: testPreset,
              size: 24,
            ),
          ),
        ),
      );

      final widgetFinder = find.byType(PresetThumbnailWidget);
      expect(widgetFinder, findsOneWidget);

      final size = tester.getSize(widgetFinder);
      expect(size.width, equals(24));
      expect(size.height, equals(24));

      final iconFinder = find.descendant(
        of: widgetFinder,
        matching: find.byIcon(Icons.photo_camera_outlined),
      );
      expect(iconFinder, findsOneWidget);
    });
  });
}
