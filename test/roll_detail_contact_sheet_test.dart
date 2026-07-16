import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/widgets/contact_sheet_export.dart';
import 'package:rana/features/gallery/view/roll_detail_screen.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cameraChannel = MethodChannel('com.rana.app/camera_control');
  late List<Map<String, dynamic>> galleryItems;
  late Map<String, List<Map<String, dynamic>>> filmRollCaptures;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    galleryItems = <Map<String, dynamic>>[];
    filmRollCaptures = <String, List<Map<String, dynamic>>>{};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (MethodCall call) async {
          switch (call.method) {
            case 'listGalleryMedia':
              return galleryItems;
            case 'listFilmRollCaptures':
              final arguments = call.arguments;
              if (arguments is! Map<dynamic, dynamic>) return const [];
              final rollId = arguments['filmRollId'];
              return rollId is String
                  ? filmRollCaptures[rollId] ?? const []
                  : const [];
            case 'loadGalleryThumbnailBytes':
              return Uint8List(0);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
  });

  testWidgets(
    'exports once with the locked recipe and reports a partial archive',
    (WidgetTester tester) async {
      final roll = _archivedRoll(exposuresTaken: 2);
      const firstFrameUri = 'content://rana/roll-frame-101.jpg';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'rana.film_rolls.v1': jsonEncode(<Map<String, dynamic>>[roll.toJson()]),
      });
      galleryItems = <Map<String, dynamic>>[
        _galleryItemMap(uri: firstFrameUri, capturedAt: roll.startedAt),
      ];
      filmRollCaptures = <String, List<Map<String, dynamic>>>{
        roll.id: <Map<String, dynamic>>[
          <String, dynamic>{
            'mediaUri': firstFrameUri,
            'capturedAtEpochMs': roll.startedAt.millisecondsSinceEpoch,
          },
        ],
      };

      final result = Completer<ContactSheetExportResult>();
      FilmRoll? exportedRoll;
      String? exportedPresetName;
      var exportCalls = 0;

      await _pumpRollDetail(
        tester,
        roll: roll,
        onExportContactSheet: ({required roll, required presetName}) {
          exportCalls += 1;
          exportedRoll = roll;
          exportedPresetName = presetName;
          return result.future;
        },
      );

      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Export contact sheet')), findsOne);
      semantics.dispose();

      final button = find.byKey(
        const ValueKey<String>('roll-detail-export-contact-sheet-button'),
      );
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.pump();

      expect(exportCalls, 1);
      expect(exportedRoll, roll);
      expect(exportedPresetName, 'Normal');
      expect(
        tester.widget<IconButton>(button).onPressed,
        isNull,
        reason: 'An in-flight export must not be submitted twice.',
      );
      expect(find.text('PREPARING CONTACT SHEET…'), findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      expect(exportCalls, 1);

      result.complete(
        const ContactSheetExportResult.shared(
          exportedFrameCount: 1,
          historicalFrameCount: 2,
          skippedFrameCount: 1,
          width: 1440,
          height: 1000,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('roll-detail-export-status')),
        findsOneWidget,
      );
      expect(find.text('CONTACT SHEET READY: 1 OF 2 FRAMES'), findsOneWidget);
    },
  );

  testWidgets('disables contact-sheet export when no frame is available', (
    WidgetTester tester,
  ) async {
    final roll = _archivedRoll(exposuresTaken: 1);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'rana.film_rolls.v1': jsonEncode(<Map<String, dynamic>>[roll.toJson()]),
    });
    filmRollCaptures = <String, List<Map<String, dynamic>>>{
      roll.id: <Map<String, dynamic>>[
        <String, dynamic>{
          'mediaUri': 'content://rana/missing-roll-frame.jpg',
          'capturedAtEpochMs': roll.startedAt.millisecondsSinceEpoch,
        },
      ],
    };

    await _pumpRollDetail(tester, roll: roll);

    final button = find.byKey(
      const ValueKey<String>('roll-detail-export-contact-sheet-button'),
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    expect(find.text('NO FRAMES AVAILABLE'), findsOneWidget);
  });

  testWidgets('shows a live inline error when contact-sheet export fails', (
    WidgetTester tester,
  ) async {
    final roll = _archivedRoll(exposuresTaken: 1);
    const frameUri = 'content://rana/roll-frame-101.jpg';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'rana.film_rolls.v1': jsonEncode(<Map<String, dynamic>>[roll.toJson()]),
    });
    galleryItems = <Map<String, dynamic>>[
      _galleryItemMap(uri: frameUri, capturedAt: roll.startedAt),
    ];
    filmRollCaptures = <String, List<Map<String, dynamic>>>{
      roll.id: <Map<String, dynamic>>[
        <String, dynamic>{
          'mediaUri': frameUri,
          'capturedAtEpochMs': roll.startedAt.millisecondsSinceEpoch,
        },
      ],
    };

    await _pumpRollDetail(
      tester,
      roll: roll,
      onExportContactSheet: ({required roll, required presetName}) async =>
          const ContactSheetExportResult.shareFailed(
            exportedFrameCount: 1,
            historicalFrameCount: 1,
            skippedFrameCount: 0,
          ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('roll-detail-export-contact-sheet-button'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('roll-detail-export-error')),
      findsOneWidget,
    );
    expect(
      find.text('Could not share the Film Roll contact sheet. Try again.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpRollDetail(
  WidgetTester tester, {
  required FilmRoll roll,
  Future<ContactSheetExportResult> Function({
    required FilmRoll roll,
    required String presetName,
  })?
  onExportContactSheet,
}) async {
  final container = ProviderContainer(
    overrides: <Override>[
      presetRepositoryProvider.overrideWithValue(
        const _StaticPresetRepository(<PresetModel>[_normalPreset]),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: RollDetailScreen(
          rollId: roll.id,
          onExportContactSheet: onExportContactSheet,
        ),
      ),
    ),
  );

  final rollExposure = find.text('${roll.exposuresTaken}/${roll.size.count}');
  for (
    var attempt = 0;
    attempt < 20 && rollExposure.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(rollExposure, findsOneWidget);

  final presetName = find.text('Normal');
  for (
    var attempt = 0;
    attempt < 20 && presetName.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(presetName, findsOneWidget);

  final exportButton = find.byKey(
    const ValueKey<String>('roll-detail-export-contact-sheet-button'),
  );
  for (
    var attempt = 0;
    attempt < 20 && exportButton.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(exportButton, findsOneWidget);
}

FilmRoll _archivedRoll({required int exposuresTaken}) => FilmRoll(
  id: 'roll-contact-sheet',
  presetId: 'normal',
  lockedStyle: const RanaStyle(),
  aspectRatioPlatformValue: 'portrait_3_4',
  size: FilmRollSize.twelve,
  exposuresTaken: exposuresTaken,
  status: FilmRollStatus.completed,
  startedAt: DateTime.utc(2026, 7, 12, 9),
  completedAt: DateTime.utc(2026, 7, 12, 10),
  coverUri: 'content://rana/roll-frame-101.jpg',
);

Map<String, dynamic> _galleryItemMap({
  required String uri,
  required DateTime capturedAt,
}) => <String, dynamic>{
  'id': 101,
  'contentUri': uri,
  'displayName': 'Rana_101.jpg',
  'dateTaken': capturedAt.millisecondsSinceEpoch,
  'dateAdded': capturedAt.millisecondsSinceEpoch,
  'width': 4032,
  'height': 3024,
  'sizeBytes': 1024000,
  'mimeType': 'image/jpeg',
  'relativePath': 'Pictures/Rana/',
};

const _normalPreset = PresetModel(
  id: 'normal',
  name: 'Normal',
  category: 'Classic',
  color: PresetColor(temperature: 0, contrast: 0, saturation: 0),
  grain: PresetGrain(intensity: 0),
  vignette: PresetVignette(intensity: 0),
  style: RanaStyle(),
);

class _StaticPresetRepository implements PresetRepository {
  const _StaticPresetRepository(this.presets);

  final List<PresetModel> presets;

  @override
  Future<List<PresetModel>> loadAll() async => presets;
}
