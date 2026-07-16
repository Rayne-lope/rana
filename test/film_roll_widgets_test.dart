import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/widgets/roll_complete_sheet.dart';
import 'package:rana/features/film_roll/widgets/roll_hud_pill.dart';
import 'package:rana/features/film_roll/widgets/roll_info_sheet.dart';
import 'package:rana/features/film_roll/widgets/start_roll_sheet.dart';
import 'package:rana/features/preset/model/rana_style.dart';

void main() {
  FilmRoll roll({
    FilmRollSize size = FilmRollSize.twentyFour,
    int exposuresTaken = 0,
  }) => FilmRoll(
    id: 'roll-1',
    presetId: 'normal',
    lockedStyle: const RanaStyle(),
    aspectRatioPlatformValue: 'portrait_3_4',
    size: size,
    exposuresTaken: exposuresTaken,
    status: FilmRollStatus.active,
    startedAt: DateTime.utc(2026),
  );

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(backgroundColor: const Color(0xFF17181C), body: child),
  );

  group('RollHudPill', () {
    testWidgets('shows proportional amber progress and opens roll info', (
      tester,
    ) async {
      var wasTapped = false;
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        host(
          Center(
            child: RollHudPill(
              roll: roll(exposuresTaken: 13),
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('13/24'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('roll-hud-pill')))
            .label,
        contains(
          'Film Roll, 13/24 exposures used, 11 remaining, amber capacity',
        ),
      );
      final decoration =
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey<String>('roll-hud-segment-2')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, const Color(0xFFF4C44F));
      semantics.dispose();

      await tester.tap(find.byKey(const ValueKey<String>('roll-hud-pill')));
      expect(wasTapped, isTrue);
    });

    testWidgets('uses green, amber, and red capacity states', (tester) async {
      Future<Color?> iconColorFor(int exposuresTaken) async {
        await tester.pumpWidget(
          host(
            RollHudPill(
              roll: roll(exposuresTaken: exposuresTaken),
              onTap: () {},
            ),
          ),
        );
        return tester
            .widget<Icon>(find.byKey(const ValueKey<String>('roll-hud-icon')))
            .color;
      }

      expect(await iconColorFor(1), const Color(0xFF81C784));
      expect(await iconColorFor(12), const Color(0xFFF4C44F));
      expect(await iconColorFor(20), const Color(0xFFE57373));
    });
  });

  group('StartRollSheet', () {
    testWidgets('defaults to 24 frames and sends the selected size', (
      tester,
    ) async {
      FilmRollSize? loadedSize;
      await tester.pumpWidget(
        host(
          StartRollSheet(
            presetName: 'Normal',
            aspectRatioLabel: '3:4',
            onLoad: (size) async {
              loadedSize = size;
              return false;
            },
          ),
        ),
      );

      expect(find.text('LOAD 24 EXPOSURES'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('start-roll-size-12')),
      );
      await tester.pump();
      expect(find.text('LOAD 12 EXPOSURES'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('load-roll-button')));
      await tester.pump();
      expect(loadedSize, FilmRollSize.twelve);
    });

    testWidgets('prevents a duplicate load while saving', (tester) async {
      final response = Completer<bool>();
      var loadCalls = 0;
      await tester.pumpWidget(
        host(
          StartRollSheet(
            presetName: 'Normal',
            aspectRatioLabel: '3:4',
            onLoad: (_) {
              loadCalls += 1;
              return response.future;
            },
          ),
        ),
      );

      final button = find.byKey(const ValueKey<String>('load-roll-button'));
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(loadCalls, 1);

      response.complete(false);
      await tester.pump();
      expect(
        find.text('Could not load this Film Roll. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('RollInfoSheet', () {
    testWidgets('disables lifecycle actions while a frame is processing', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          RollInfoSheet(
            roll: roll(exposuresTaken: 3),
            presetName: 'Normal',
            aspectRatioLabel: '3:4',
            pendingExposures: 1,
            onEnd: () async => false,
            onAbandon: () async => false,
          ),
        ),
      );

      expect(find.text('PROCESSING 1 FRAME'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('end-roll-button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey<String>('abandon-roll-button')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('confirms early ending and explains abandonment', (
      tester,
    ) async {
      var ended = false;
      await tester.pumpWidget(
        host(
          RollInfoSheet(
            roll: roll(exposuresTaken: 3),
            presetName: 'Normal',
            aspectRatioLabel: '3:4',
            pendingExposures: 0,
            onEnd: () async {
              ended = true;
              return false;
            },
            onAbandon: () async => false,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('end-roll-button')));
      await tester.pumpAndSettle();
      expect(find.text('END ROLL?'), findsOneWidget);
      expect(find.textContaining('21 frames will stay unused'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'END ROLL').last);
      await tester.pump();
      expect(ended, isTrue);

      await tester.tap(
        find.byKey(const ValueKey<String>('abandon-roll-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABANDON ROLL?'), findsOneWidget);
      expect(
        find.textContaining('saved photos stay available in Photos'),
        findsOneWidget,
      );
    });
  });

  testWidgets('RollCompleteSheet reports the saved roll', (tester) async {
    await tester.pumpWidget(
      host(
        RollCompleteSheet(
          roll: roll(size: FilmRollSize.twelve, exposuresTaken: 12),
          presetName: 'Normal',
        ),
      ),
    );

    expect(find.text('ROLL COMPLETE'), findsOneWidget);
    expect(find.text('12/12 frames saved with NORMAL.'), findsOneWidget);
  });
}
