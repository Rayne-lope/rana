import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/widgets/contact_sheet_export.dart';
import 'package:rana/features/preset/model/rana_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactSheetLayout', () {
    test('uses three columns and bounds every supported Film Roll size', () {
      for (final size in FilmRollSize.values) {
        for (final aspectRatio in const <String>[
          'portrait_3_4',
          'square_1_1',
          'portrait_9_16',
        ]) {
          final layout = ContactSheetLayout.forFrameCount(
            frameCount: size.count,
            aspectRatioPlatformValue: aspectRatio,
          );

          expect(layout.columns, 3);
          expect(layout.rows, (size.count + 2) ~/ 3);
          expect(
            layout.canvasWidth > layout.canvasHeight
                ? layout.canvasWidth
                : layout.canvasHeight,
            lessThanOrEqualTo(ContactSheetLayout.maxLongEdge),
          );
        }
      }
    });

    test(
      'scales a 36-frame 9:16 roll instead of exceeding the texture cap',
      () {
        final layout = ContactSheetLayout.forFrameCount(
          frameCount: 36,
          aspectRatioPlatformValue: 'portrait_9_16',
        );

        expect(layout.rows, 12);
        expect(layout.scale, lessThan(1));
        expect(layout.canvasHeight, ContactSheetLayout.maxLongEdge);
        expect(layout.canvasWidth, lessThan(ContactSheetLayout.preferredWidth));
      },
    );
  });

  group('ContactSheetHeaderMetadata', () {
    test('falls back to locked recipe and persisted roll dates', () {
      final roll = _roll(exposuresTaken: 3).copyWith(
        startedAt: DateTime.utc(2026, 7, 14),
        completedAt: DateTime.utc(2026, 7, 16),
      );

      final metadata = ContactSheetHeaderMetadata.fromRoll(
        roll: roll,
        presetName: '   ',
        availableFrameCount: 2,
      );

      expect(metadata.presetName, 'portra');
      expect(metadata.dateRangeLabel, '14 JUL 2026 TO 16 JUL 2026');
      expect(metadata.takenLabel, '3/36 TAKEN');
      expect(metadata.availableLabel, '2/36 AVAILABLE');
    });

    test('uses native frame dates when they are available', () {
      final metadata = ContactSheetHeaderMetadata.fromRoll(
        roll: _roll(exposuresTaken: 1),
        presetName: 'Portra 400',
        availableFrameCount: 1,
        firstCaptureAt: DateTime.utc(2026, 7, 17),
        lastCaptureAt: DateTime.utc(2026, 7, 18),
      );

      expect(metadata.presetName, 'Portra 400');
      expect(metadata.dateRangeLabel, '17 JUL 2026 TO 18 JUL 2026');
    });
  });

  group('ContactSheetExporter', () {
    test(
      'orders native captures, loads them sequentially, and shares PNG',
      () async {
        final first = DateTime.utc(2026, 7, 16, 10);
        final requestedUris = <String>[];
        final requestedTargetSizes = <int>[];
        var inFlightLoads = 0;
        var maxInFlightLoads = 0;
        Uint8List? sharedBytes;
        final exporter = ContactSheetExporter(
          loadCaptures: (_) async => <FilmRollCaptureRecord>[
            _capture(
              'content://rana/late',
              first.add(const Duration(minutes: 2)),
            ),
            _capture(
              'content://rana/same-b',
              first.add(const Duration(minutes: 1)),
            ),
            _capture('content://rana/first', first),
            _capture(
              'content://rana/same-a',
              first.add(const Duration(minutes: 1)),
            ),
            _capture('content://rana/first', first),
          ],
          loadImageBytes: (uri, {required targetSize}) async {
            inFlightLoads += 1;
            maxInFlightLoads = maxInFlightLoads < inFlightLoads
                ? inFlightLoads
                : maxInFlightLoads;
            requestedUris.add(uri);
            requestedTargetSizes.add(targetSize);
            await Future<void>.delayed(Duration.zero);
            inFlightLoads -= 1;
            return _validPngBytes();
          },
          shareContactSheet: (bytes) async {
            sharedBytes = Uint8List.fromList(bytes);
          },
        );

        final result = await exporter.exportRoll(
          roll: _roll(exposuresTaken: 4),
          presetName: 'A very long preset name with Unicode 写真',
        );

        expect(
          result.succeeded,
          isTrue,
          reason: '${result.status}: ${result.error}',
        );
        expect(result.exportedFrameCount, 4);
        expect(result.historicalFrameCount, 4);
        expect(result.skippedFrameCount, 0);
        expect(maxInFlightLoads, 1);
        expect(requestedUris, <String>[
          'content://rana/first',
          'content://rana/same-a',
          'content://rana/same-b',
          'content://rana/late',
        ]);
        expect(requestedTargetSizes, everyElement(inInclusiveRange(64, 1024)));
        expect(_isPng(sharedBytes), isTrue);

        final decoded = await ui.instantiateImageCodec(sharedBytes!);
        final image = (await decoded.getNextFrame()).image;
        try {
          expect(image.width, result.width);
          expect(image.height, result.height);
        } finally {
          image.dispose();
          decoded.dispose();
        }
      },
    );

    test(
      'omits unreadable frames and keeps historical exposure accounting',
      () async {
        var shareCalls = 0;
        final first = DateTime.utc(2026, 7, 16, 10);
        final exporter = ContactSheetExporter(
          loadCaptures: (_) async => <FilmRollCaptureRecord>[
            _capture('content://rana/readable', first),
            _capture(
              'content://rana/invalid',
              first.add(const Duration(minutes: 1)),
            ),
            _capture(
              'content://rana/deleted',
              first.add(const Duration(minutes: 2)),
            ),
          ],
          loadImageBytes: (uri, {required targetSize}) async {
            if (uri.endsWith('readable')) return _validPngBytes();
            if (uri.endsWith('invalid')) return Uint8List.fromList(<int>[1, 2]);
            throw StateError('MediaStore item is gone');
          },
          shareContactSheet: (_) async => shareCalls += 1,
        );

        final result = await exporter.exportRoll(
          roll: _roll(exposuresTaken: 3),
          presetName: 'Portra',
        );

        expect(
          result.succeeded,
          isTrue,
          reason: '${result.status}: ${result.error}',
        );
        expect(result.exportedFrameCount, 1);
        expect(result.historicalFrameCount, 3);
        expect(result.skippedFrameCount, 2);
        expect(result.isPartial, isTrue);
        expect(shareCalls, 1);
      },
    );

    test('does not open share when no saved frame is readable', () async {
      var shareCalls = 0;
      final exporter = ContactSheetExporter(
        loadCaptures: (_) async => <FilmRollCaptureRecord>[
          _capture('content://rana/missing', DateTime.utc(2026, 7, 16)),
        ],
        loadImageBytes: (_, {required targetSize}) async => Uint8List(0),
        shareContactSheet: (_) async => shareCalls += 1,
      );

      final result = await exporter.exportRoll(
        roll: _roll(exposuresTaken: 1),
        presetName: 'Portra',
      );

      expect(result.status, ContactSheetExportStatus.noExportableFrames);
      expect(result.succeeded, isFalse);
      expect(result.exportedFrameCount, 0);
      expect(result.historicalFrameCount, 1);
      expect(result.skippedFrameCount, 1);
      expect(shareCalls, 0);
    });

    test(
      'returns a typed failure when capture metadata or sharing fails',
      () async {
        final metadataFailure = StateError('metadata unavailable');
        final metadataExporter = ContactSheetExporter(
          loadCaptures: (_) async => throw metadataFailure,
          loadImageBytes: (_, {required targetSize}) async => _validPngBytes(),
          shareContactSheet: (_) async {},
        );

        final metadataResult = await metadataExporter.exportRoll(
          roll: _roll(exposuresTaken: 1),
          presetName: 'Portra',
        );
        expect(metadataResult.status, ContactSheetExportStatus.renderFailed);
        expect(metadataResult.error, metadataFailure);

        final shareFailure = StateError('share unavailable');
        final shareExporter = ContactSheetExporter(
          loadCaptures: (_) async => <FilmRollCaptureRecord>[
            _capture('content://rana/frame', DateTime.utc(2026, 7, 16)),
          ],
          loadImageBytes: (_, {required targetSize}) async => _validPngBytes(),
          shareContactSheet: (_) async => throw shareFailure,
        );
        final shareResult = await shareExporter.exportRoll(
          roll: _roll(exposuresTaken: 1),
          presetName: 'Portra',
        );

        expect(
          shareResult.status,
          ContactSheetExportStatus.shareFailed,
          reason: '${shareResult.status}: ${shareResult.error}',
        );
        expect(shareResult.exportedFrameCount, 1);
        expect(shareResult.historicalFrameCount, 1);
        expect(shareResult.error, shareFailure);
      },
    );

    test('uses a matte around a contained landscape source image', () async {
      Uint8List? sharedBytes;
      final exporter = ContactSheetExporter(
        loadCaptures: (_) async => <FilmRollCaptureRecord>[
          _capture('content://rana/landscape', DateTime.utc(2026, 7, 16)),
        ],
        loadImageBytes: (_, {required targetSize}) async =>
            _landscapePngBytes(),
        shareContactSheet: (bytes) async =>
            sharedBytes = Uint8List.fromList(bytes),
      );

      final result = await exporter.exportRoll(
        roll: _roll(exposuresTaken: 1),
        presetName: 'Portra',
      );
      final layout = ContactSheetLayout.forFrameCount(
        frameCount: 1,
        aspectRatioPlatformValue: 'portrait_3_4',
      );
      final tile = layout.tileRectAt(0);
      final decoded = await ui.instantiateImageCodec(sharedBytes!);
      final image = (await decoded.getNextFrame()).image;
      final raw = await image.toByteData();
      try {
        final x = tile.center.dx.floor();
        final y = (tile.top + 2).floor();
        final offset = ((y * image.width) + x) * 4;
        expect(raw, isNotNull);
        expect(raw!.getUint8(offset), 0x25);
        expect(raw.getUint8(offset + 1), 0x21);
        expect(raw.getUint8(offset + 2), 0x1c);
        expect(raw.getUint8(offset + 3), 0xff);
        expect(result.succeeded, isTrue);
      } finally {
        image.dispose();
        decoded.dispose();
      }
    });
  });
}

FilmRoll _roll({
  required int exposuresTaken,
  String aspectRatioPlatformValue = 'portrait_3_4',
}) => FilmRoll(
  id: 'roll-42',
  presetId: 'portra',
  lockedStyle: const RanaStyle(),
  aspectRatioPlatformValue: aspectRatioPlatformValue,
  size: FilmRollSize.thirtySix,
  exposuresTaken: exposuresTaken,
  status: FilmRollStatus.completed,
  startedAt: DateTime.utc(2026, 7, 16),
  completedAt: DateTime.utc(2026, 7, 16, 12),
);

FilmRollCaptureRecord _capture(String uri, DateTime capturedAt) =>
    FilmRollCaptureRecord(mediaUri: uri, capturedAt: capturedAt);

bool _isPng(Uint8List? bytes) {
  const signature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes == null || bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

Uint8List _validPngBytes() => _landscapePngBytes();

Uint8List _landscapePngBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAJCAYAAAA7KqwyAAAAFklEQVR4nGO406PxnxLM'
  'MGrAqAFADAARhHCA1uhxAQAAAABJRU5ErkJggg==',
);
