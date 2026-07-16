import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';
import 'package:rana/features/film_roll/repository/film_roll_repository.dart';
import 'package:rana/features/gallery/controller/gallery_controller.dart';
import 'package:rana/features/gallery/model/gallery_film_roll.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryGalleryFilmRollRepository implements FilmRollRepository {
  final List<FilmRoll> rolls = <FilmRoll>[];

  @override
  Future<void> delete(String id) async {
    rolls.removeWhere((roll) => roll.id == id);
  }

  @override
  Future<FilmRoll?> loadActive() async => null;

  @override
  Future<List<FilmRoll>> loadAll() async => List<FilmRoll>.of(rolls);

  @override
  Future<void> save(FilmRoll roll) async {
    rolls
      ..removeWhere((existing) => existing.id == roll.id)
      ..add(roll);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cameraChannel = MethodChannel('com.rana.app/camera_control');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
  });

  ProviderContainer containerFor(_MemoryGalleryFilmRollRepository repository) =>
      ProviderContainer(
        overrides: <Override>[
          filmRollRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('projection preserves native chronology and falls back from a deleted '
      'cover', () {
    final first = DateTime.utc(2026, 7, 1, 8);
    final second = first.add(const Duration(minutes: 10));
    final third = first.add(const Duration(minutes: 20));
    final roll = _roll(
      id: 'archive-1',
      exposuresTaken: 3,
      coverUri: 'content://rana/frame-2.jpg',
    );
    final projection = GalleryFilmRoll(
      roll: roll,
      captures: <RollCaptureEntry>[
        _capture(roll.id, 'content://rana/frame-3.jpg', third, 3),
        _capture(roll.id, 'content://rana/frame-2.jpg', second, 2),
        _capture(roll.id, 'content://rana/frame-1.jpg', first, 1),
      ],
      availableItems: <GalleryMediaItem>[
        _item('3', 'content://rana/frame-3.jpg', third),
        _item('1', 'content://rana/frame-1.jpg', first),
      ],
    );

    expect(projection.captures.map((entry) => entry.mediaUri), <String>[
      'content://rana/frame-1.jpg',
      'content://rana/frame-2.jpg',
      'content://rana/frame-3.jpg',
    ]);
    expect(projection.availableItems.map((item) => item.contentUri), <String>[
      'content://rana/frame-1.jpg',
      'content://rana/frame-3.jpg',
    ]);
    expect(projection.preferredCoverUri, 'content://rana/frame-1.jpg');
    expect(projection.dateRangeStart, first);
    expect(projection.dateRangeEnd, third);
    expect(projection.unavailableFrameCount, 1);
    expect(projection.isEarlyEnded, isTrue);
  });

  test(
    'Rolls mode filters archive membership and rebuilds after frame deletion',
    () async {
      final completed = _roll(
        id: 'completed',
        exposuresTaken: 2,
        coverUri: 'content://rana/frame-1.jpg',
      );
      final active = completed.copyWith(
        id: 'active',
        status: FilmRollStatus.active,
        completedAt: null,
      );
      final abandoned = completed.copyWith(
        id: 'abandoned',
        status: FilmRollStatus.abandoned,
      );
      final repository = _MemoryGalleryFilmRollRepository()
        ..rolls.addAll(<FilmRoll>[completed, active, abandoned]);
      final first = DateTime.utc(2026, 7, 2, 8);
      final second = first.add(const Duration(minutes: 5));
      var nativeCaptureRequests = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (call) async {
            switch (call.method) {
              case 'listGalleryMedia':
                return <Map<String, dynamic>>[
                  _mediaMap('2', 'content://rana/frame-2.jpg', second),
                ];
              case 'listFilmRollCaptures':
                nativeCaptureRequests += 1;
                return <Map<String, dynamic>>[
                  _captureMap('content://rana/frame-2.jpg', second),
                  _captureMap('content://rana/frame-1.jpg', first),
                ];
              case 'deleteGalleryMedia':
                return null;
            }
            return null;
          });

      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(galleryControllerProvider.notifier);

      await controller.loadGallery();
      expect(nativeCaptureRequests, 0);
      await controller.setViewMode(GalleryViewMode.rolls);

      var state = container.read(galleryControllerProvider);
      expect(state.viewMode, GalleryViewMode.rolls);
      expect(state.rollsStatus, GalleryRollLoadStatus.loaded);
      expect(nativeCaptureRequests, 1);
      expect(state.rolls.map((roll) => roll.roll.id), <String>['completed']);
      expect(
        state.rolls.single.availableItems.map((item) => item.contentUri),
        <String>['content://rana/frame-2.jpg'],
      );
      expect(
        state.rolls.single.preferredCoverUri,
        'content://rana/frame-2.jpg',
      );
      expect(state.rolls.single.unavailableFrameCount, 1);

      await controller.deleteItem('content://rana/frame-2.jpg');

      state = container.read(galleryControllerProvider);
      expect(state.items, isEmpty);
      expect(state.rolls.single.availableItems, isEmpty);
      expect(state.rolls.single.preferredCover, isNull);
      expect(state.rolls.single.unavailableFrameCount, 2);
    },
  );

  test(
    'Roll metadata failures do not replace a healthy Photos state',
    () async {
      final repository = _MemoryGalleryFilmRollRepository()
        ..rolls.add(_roll(id: 'completed', exposuresTaken: 1));
      final frameTime = DateTime.utc(2026, 7, 3, 10);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (call) async {
            switch (call.method) {
              case 'listGalleryMedia':
                return <Map<String, dynamic>>[
                  _mediaMap('1', 'content://rana/frame-1.jpg', frameTime),
                ];
              case 'listFilmRollCaptures':
                throw PlatformException(
                  code: 'ROLL_METADATA_UNAVAILABLE',
                  message: 'Native index unavailable',
                );
            }
            return null;
          });

      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(galleryControllerProvider.notifier);

      await controller.loadGallery();
      await controller.setViewMode(GalleryViewMode.rolls);

      final state = container.read(galleryControllerProvider);
      expect(state.status, GalleryStatus.loaded);
      expect(state.items, hasLength(1));
      expect(state.rollsStatus, GalleryRollLoadStatus.error);
      expect(state.rollsErrorMessage, isNotEmpty);
    },
  );

  test('first Rolls selection refreshes a stale Photos snapshot', () async {
    final roll = _roll(
      id: 'newly-completed',
      exposuresTaken: 1,
      coverUri: 'content://rana/new-frame.jpg',
    );
    final repository = _MemoryGalleryFilmRollRepository();
    final capturedAt = DateTime.utc(2026, 7, 4, 9);
    var mediaItems = <Map<String, dynamic>>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (call) async {
          switch (call.method) {
            case 'listGalleryMedia':
              return mediaItems;
            case 'listFilmRollCaptures':
              return <Map<String, dynamic>>[
                _captureMap('content://rana/new-frame.jpg', capturedAt),
              ];
          }
          return null;
        });

    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(galleryControllerProvider.notifier);

    await controller.loadGallery();
    expect(container.read(galleryControllerProvider).items, isEmpty);

    repository.rolls.add(roll);
    mediaItems = <Map<String, dynamic>>[
      _mediaMap('new', 'content://rana/new-frame.jpg', capturedAt),
    ];
    await controller.setViewMode(GalleryViewMode.rolls);

    final state = container.read(galleryControllerProvider);
    expect(state.rolls, hasLength(1));
    expect(state.rolls.single.availableItems, hasLength(1));
    expect(
      state.rolls.single.preferredCoverUri,
      'content://rana/new-frame.jpg',
    );
  });

  test(
    'revoked photo access clears previously available Roll frames',
    () async {
      final capturedAt = DateTime.utc(2026, 7, 5, 9);
      final repository = _MemoryGalleryFilmRollRepository()
        ..rolls.add(_roll(id: 'completed', exposuresTaken: 1));
      var photoAccessAllowed = true;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (call) async {
            switch (call.method) {
              case 'listGalleryMedia':
                if (!photoAccessAllowed) {
                  throw PlatformException(
                    code: 'PERMISSION_DENIED',
                    message: 'Photos access was revoked',
                  );
                }
                return <Map<String, dynamic>>[
                  _mediaMap('1', 'content://rana/frame-1.jpg', capturedAt),
                ];
              case 'listFilmRollCaptures':
                return <Map<String, dynamic>>[
                  _captureMap('content://rana/frame-1.jpg', capturedAt),
                ];
            }
            return null;
          });

      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(galleryControllerProvider.notifier);

      await controller.loadGallery();
      await controller.setViewMode(GalleryViewMode.rolls);
      expect(
        container.read(galleryControllerProvider).rolls.single.availableItems,
        hasLength(1),
      );

      photoAccessAllowed = false;
      await controller.loadRolls();

      final state = container.read(galleryControllerProvider);
      expect(state.status, GalleryStatus.permissionDenied);
      expect(state.items, isEmpty);
      expect(state.rolls.single.availableItems, isEmpty);
      expect(state.rolls.single.unavailableFrameCount, 1);
    },
  );

  test(
    'a stale MediaStore refresh cannot restore a deleted Roll cover',
    () async {
      final capturedAt = DateTime.utc(2026, 7, 6, 9);
      const uri = 'content://rana/frame-1.jpg';
      final repository = _MemoryGalleryFilmRollRepository()
        ..rolls.add(_roll(id: 'completed', exposuresTaken: 1, coverUri: uri));
      final staleSnapshotStarted = Completer<void>();
      final releaseStaleSnapshot = Completer<List<Map<String, dynamic>>>();
      var mediaRequests = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (call) async {
            switch (call.method) {
              case 'listGalleryMedia':
                mediaRequests += 1;
                if (mediaRequests == 3) {
                  staleSnapshotStarted.complete();
                  return releaseStaleSnapshot.future;
                }
                if (mediaRequests < 3) {
                  return <Map<String, dynamic>>[
                    _mediaMap('1', uri, capturedAt),
                  ];
                }
                return const <Map<String, dynamic>>[];
              case 'listFilmRollCaptures':
                return <Map<String, dynamic>>[_captureMap(uri, capturedAt)];
              case 'deleteGalleryMedia':
                return null;
            }
            return null;
          });

      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(galleryControllerProvider.notifier);

      await controller.loadGallery();
      await controller.setViewMode(GalleryViewMode.rolls);
      expect(
        container
            .read(galleryControllerProvider)
            .rolls
            .single
            .preferredCoverUri,
        uri,
      );

      final staleRefresh = controller.loadGallery();
      await staleSnapshotStarted.future;
      await controller.deleteItem(uri);
      releaseStaleSnapshot.complete(<Map<String, dynamic>>[
        _mediaMap('1', uri, capturedAt),
      ]);
      await staleRefresh;

      final state = container.read(galleryControllerProvider);
      expect(mediaRequests, greaterThanOrEqualTo(4));
      expect(state.items, isEmpty);
      expect(state.rolls.single.preferredCover, isNull);
      expect(state.rolls.single.unavailableFrameCount, 1);
    },
  );

  test(
    'a concurrent archive request reloads the latest completed history',
    () async {
      final firstRoll = _roll(id: 'first', exposuresTaken: 1);
      final secondRoll = _roll(id: 'second', exposuresTaken: 1);
      final repository = _MemoryGalleryFilmRollRepository()
        ..rolls.add(firstRoll);
      final firstCaptureStarted = Completer<void>();
      final releaseFirstCapture = Completer<List<Map<String, dynamic>>>();
      var captureRequests = 0;
      final capturedAt = DateTime.utc(2026, 7, 4, 10);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (call) async {
            switch (call.method) {
              case 'listGalleryMedia':
                return <Map<String, dynamic>>[
                  _mediaMap('1', 'content://rana/frame-1.jpg', capturedAt),
                ];
              case 'listFilmRollCaptures':
                captureRequests += 1;
                if (captureRequests == 1) {
                  firstCaptureStarted.complete();
                  return releaseFirstCapture.future;
                }
                return <Map<String, dynamic>>[
                  _captureMap(
                    'content://rana/frame-$captureRequests.jpg',
                    capturedAt,
                  ),
                ];
            }
            return null;
          });

      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(galleryControllerProvider.notifier);
      final publishedRollIds = <List<String>>[];
      final subscription = container.listen<GalleryState>(
        galleryControllerProvider,
        (_, next) {
          if (next.rollsStatus == GalleryRollLoadStatus.loaded) {
            publishedRollIds.add(
              next.rolls.map((roll) => roll.roll.id).toList(growable: false),
            );
          }
        },
      );
      addTearDown(subscription.close);

      final firstLoad = controller.setViewMode(GalleryViewMode.rolls);
      await firstCaptureStarted.future;
      repository.rolls.add(secondRoll);
      final latestLoad = controller.loadRolls();
      releaseFirstCapture.complete(<Map<String, dynamic>>[
        _captureMap('content://rana/frame-1.jpg', capturedAt),
      ]);
      await Future.wait<void>(<Future<void>>[firstLoad, latestLoad]);

      final state = container.read(galleryControllerProvider);
      expect(state.rollsStatus, GalleryRollLoadStatus.loaded);
      expect(state.rolls.map((roll) => roll.roll.id), <String>[
        'first',
        'second',
      ]);
      expect(captureRequests, greaterThanOrEqualTo(3));
      expect(
        publishedRollIds.any(
          (rollIds) => rollIds.length == 1 && rollIds.single == 'first',
        ),
        isFalse,
      );
    },
  );
}

FilmRoll _roll({
  required String id,
  required int exposuresTaken,
  String? coverUri,
}) => FilmRoll(
  id: id,
  presetId: 'custom-preset',
  lockedStyle: const RanaStyle(),
  aspectRatioPlatformValue: 'portrait_3_4',
  size: FilmRollSize.twelve,
  exposuresTaken: exposuresTaken,
  status: FilmRollStatus.completed,
  startedAt: DateTime.utc(2026, 7),
  completedAt: DateTime.utc(2026, 7, 2),
  coverUri: coverUri,
);

RollCaptureEntry _capture(
  String rollId,
  String uri,
  DateTime capturedAt,
  int exposureIndex,
) => RollCaptureEntry(
  filmRollId: rollId,
  mediaUri: uri,
  capturedAt: capturedAt,
  exposureIndex: exposureIndex,
);

GalleryMediaItem _item(String id, String uri, DateTime capturedAt) =>
    GalleryMediaItem(
      id: id,
      contentUri: uri,
      displayName: 'Rana_$id.jpg',
      dateTaken: capturedAt,
      width: 4032,
      height: 3024,
      mimeType: 'image/jpeg',
      sizeBytes: 1024,
      relativePath: 'Pictures/Rana',
    );

Map<String, dynamic> _mediaMap(String id, String uri, DateTime capturedAt) =>
    <String, dynamic>{
      'id': id,
      'contentUri': uri,
      'displayName': 'Rana_$id.jpg',
      'dateTaken': capturedAt.millisecondsSinceEpoch,
      'width': 4032,
      'height': 3024,
      'mimeType': 'image/jpeg',
      'sizeBytes': 1024,
      'relativePath': 'Pictures/Rana',
    };

Map<String, dynamic> _captureMap(String uri, DateTime capturedAt) =>
    <String, dynamic>{
      'mediaUri': uri,
      'capturedAtEpochMs': capturedAt.millisecondsSinceEpoch,
    };
