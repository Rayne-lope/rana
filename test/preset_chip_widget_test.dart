import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/widgets/preset_chip_widget.dart';
import 'package:rana/features/preset/model/preset_model.dart';

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

  group('PresetChipWidget Tests', () {
    testWidgets(
      'renders with name in uppercase',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PresetChipWidget(
                preset: testPreset,
                isSelected: false,
                isEnabled: true,
                onSelected: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('TEST PRESET'), findsOneWidget);
        final chipFinder = find.byType(ChoiceChip);
        expect(chipFinder, findsOneWidget);
        final choiceChip = tester.widget<ChoiceChip>(chipFinder);
        expect(choiceChip.selected, isFalse);
      },
    );

    testWidgets(
      'displays as selected when isSelected is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PresetChipWidget(
                preset: testPreset,
                isSelected: true,
                isEnabled: true,
                onSelected: (_) {},
              ),
            ),
          ),
        );

        final chipFinder = find.byType(ChoiceChip);
        final choiceChip = tester.widget<ChoiceChip>(chipFinder);
        expect(choiceChip.selected, isTrue);
      },
    );

    testWidgets(
      'invokes onSelected callback when enabled and tapped',
      (WidgetTester tester) async {
        bool? selectedValue;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PresetChipWidget(
                preset: testPreset,
                isSelected: false,
                isEnabled: true,
                onSelected: (val) => selectedValue = val,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ChoiceChip));
        await tester.pumpAndSettle();

        expect(selectedValue, isTrue);
      },
    );

    testWidgets(
      'does not invoke onSelected when isEnabled is false',
      (WidgetTester tester) async {
        var callbackInvoked = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PresetChipWidget(
                preset: testPreset,
                isSelected: false,
                isEnabled: false,
                onSelected: (_) => callbackInvoked = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ChoiceChip));
        await tester.pumpAndSettle();

        expect(callbackInvoked, isFalse);
        final chipFinder = find.byType(ChoiceChip);
        final choiceChip = tester.widget<ChoiceChip>(chipFinder);
        expect(choiceChip.onSelected, isNull);
      },
    );
  });
}
