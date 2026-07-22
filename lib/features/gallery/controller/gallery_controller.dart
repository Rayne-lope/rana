import 'dart:async';

import 'package:flutter/services.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/core/services/media_store_service.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';
import 'package:rana/features/film_roll/repository/film_roll_repository.dart';
import 'package:rana/features/gallery/model/gallery_film_roll.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'gallery_controller.g.dart';

@Riverpod(keepAlive: true)
class GalleryController extends _$GalleryController {
  static const _favoriteIdsKey = 'rana_gallery_favorite_ids';

  late final MediaStoreService _mediaStoreService;
  late final CameraPlatformService _cameraPlatformService;
  late final FilmRollRepository _filmRollRepository;
  bool _favoritesLoaded = false;
  Future<void>? _galleryLoadFuture;
  Future<void>? _rollLoadFuture;
  bool _galleryReloadRequested = false;
  bool _rollReloadRequested = false;
  bool _rollMediaRefreshRequested = false;
  int _mediaSnapshotGeneration = 0;
  int _rollRequestGeneration = 0;
  Future<void> _mediaMutationQueue = Future<void>.value();

  @override
  GalleryState build() {
    _mediaStoreService = MediaStoreService();
    _cameraPlatformService = CameraPlatformService();
    _filmRollRepository = ref.read(filmRollRepositoryProvider);

    // A completed roll can be created while this keep-alive controller sits
    // behind the camera branch. Refresh an already-visible/archive-ready view
    // so returning to Gallery never leaves the new roll out of the list.
    ref.listen(
      filmRollControllerProvider.select((rollState) => rollState.history),
      (previous, next) {
        if (previous == next ||
            (state.viewMode != GalleryViewMode.rolls &&
                state.rollsStatus == GalleryRollLoadStatus.initial)) {
          return;
        }
        unawaited(loadRolls());
      },
    );
    return GalleryState.initial();
  }

  /// Loads the recent Rana media items from Android MediaStore.
  Future<void> loadGallery() {
    final inFlight = _galleryLoadFuture;
    if (inFlight != null) {
      // A delete, lifecycle refresh, or explicit retry may arrive while the
      // native query is running. Drain one more snapshot before resolving so
      // the last writer is always based on the newest MediaStore state.
      _galleryReloadRequested = true;
      return inFlight;
    }

    final future = _drainGalleryLoads();
    _galleryLoadFuture = future;
    return future;
  }

  Future<void> _drainGalleryLoads() async {
    try {
      do {
        _galleryReloadRequested = false;
        await _loadGalleryInternal();
      } while (_galleryReloadRequested);
    } finally {
      _galleryLoadFuture = null;
    }
  }

  /// Refreshes the photo snapshot before rebuilding Film Roll projections.
  ///
  /// The ordering matters: Film Roll records are joined by URI against the
  /// newest MediaStore snapshot, never an older in-memory gallery list.
  Future<void> refresh({bool includeRolls = true}) async {
    await loadGallery();
    if (includeRolls) await loadRolls(refreshMediaSnapshot: false);
  }

  Future<void> _loadGalleryInternal() async {
    await _ensureFavoritesLoaded();
    // If a delete is queued, query only after it settles. If a delete begins
    // after this await, the generation check below rejects the old result.
    await _mediaMutationQueue;
    final snapshotGeneration = _mediaSnapshotGeneration;

    state = state.copyWith(status: GalleryStatus.loading, errorMessage: null);

    try {
      final items = await _mediaStoreService.loadGalleryItems();
      if (snapshotGeneration != _mediaSnapshotGeneration) {
        _galleryReloadRequested = true;
        return;
      }
      final uris = items
          .map((i) => i.contentUri)
          .where((u) => u.isNotEmpty)
          .toList(growable: false);
      final styleMetaMap = await _cameraPlatformService
          .getCaptureStyleMetadataBatch(uris);
      final sortedItems = items.map((item) {
        final meta = styleMetaMap[item.contentUri];
        return meta != null ? item.copyWith(styleMetadata: meta) : item;
      }).toList()..sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
      final rebuiltRolls = state.rollsStatus == GalleryRollLoadStatus.initial
          ? state.rolls
          : _rebuildRolls(state.rolls, sortedItems);
      state = state.copyWith(
        status: sortedItems.isEmpty
            ? GalleryStatus.empty
            : GalleryStatus.loaded,
        items: sortedItems,
        errorMessage: null,
        rolls: rebuiltRolls,
      );
    } on PlatformException catch (e) {
      if (snapshotGeneration != _mediaSnapshotGeneration) {
        _galleryReloadRequested = true;
        return;
      }
      if (e.code == 'PERMISSION_DENIED') {
        state = state.copyWith(
          status: GalleryStatus.permissionDenied,
          items: const <GalleryMediaItem>[],
          errorMessage: null,
          rolls: state.rollsStatus == GalleryRollLoadStatus.initial
              ? state.rolls
              : _rebuildRolls(state.rolls, const <GalleryMediaItem>[]),
        );
        return;
      }
      state = state.copyWith(
        status: GalleryStatus.error,
        errorMessage: e.toString(),
      );
    } on Object catch (e) {
      if (snapshotGeneration != _mediaSnapshotGeneration) {
        _galleryReloadRequested = true;
        return;
      }
      state = state.copyWith(
        status: GalleryStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Selects the visible Gallery surface and loads the Film Roll archive on
  /// demand. Photo filters/favorites intentionally remain unchanged.
  Future<void> setViewMode(GalleryViewMode viewMode) async {
    if (state.viewMode != viewMode) {
      state = state.copyWith(viewMode: viewMode);
    }
    if (viewMode == GalleryViewMode.rolls) {
      await loadRolls();
    }
  }

  /// Builds completed Film Roll cards from durable native capture metadata.
  ///
  /// The repository owns archive membership while Android metadata owns frame
  /// order. MediaStore contributes only the frames still available to render.
  ///
  /// [refreshMediaSnapshot] is false only when [refresh] has already loaded
  /// MediaStore in the same coordinated operation.
  Future<void> loadRolls({bool refreshMediaSnapshot = true}) {
    _rollRequestGeneration += 1;
    final inFlight = _rollLoadFuture;
    if (inFlight != null) {
      // Keep a history change, deep link, or retry from being lost behind an
      // earlier native metadata request.
      _rollReloadRequested = true;
      _rollMediaRefreshRequested |= refreshMediaSnapshot;
      return inFlight;
    }

    _rollMediaRefreshRequested = refreshMediaSnapshot;
    final future = _drainRollLoads();
    _rollLoadFuture = future;
    return future;
  }

  Future<void> _drainRollLoads() async {
    try {
      do {
        final requestGeneration = _rollRequestGeneration;
        final refreshMediaSnapshot = _rollMediaRefreshRequested;
        _rollReloadRequested = false;
        _rollMediaRefreshRequested = false;
        await _loadRollsInternal(
          requestGeneration: requestGeneration,
          refreshMediaSnapshot: refreshMediaSnapshot,
        );
      } while (_rollReloadRequested);
    } finally {
      _rollLoadFuture = null;
    }
  }

  Future<void> _loadRollsInternal({
    required int requestGeneration,
    required bool refreshMediaSnapshot,
  }) async {
    if (refreshMediaSnapshot) {
      await loadGallery();
    } else {
      final galleryLoad = _galleryLoadFuture;
      if (galleryLoad != null) await galleryLoad;
    }
    if (!_isCurrentRollRequest(requestGeneration)) return;
    state = state.copyWith(
      rollsStatus: GalleryRollLoadStatus.loading,
      rollsErrorMessage: null,
    );

    try {
      final archivedRolls = (await _filmRollRepository.loadAll())
          .where((roll) => roll.status == FilmRollStatus.completed)
          .toList(growable: false);
      if (!_isCurrentRollRequest(requestGeneration)) return;
      final capturesByRoll = await Future.wait(
        archivedRolls.map((roll) async {
          final records = await _cameraPlatformService.listFilmRollCaptures(
            roll.id,
          );
          return <String, List<RollCaptureEntry>>{
            roll.id: [
              for (var index = 0; index < records.length; index += 1)
                RollCaptureEntry(
                  filmRollId: roll.id,
                  mediaUri: records[index].mediaUri,
                  capturedAt: records[index].capturedAt,
                  exposureIndex: index + 1,
                ),
            ],
          };
        }),
      );

      // Read the current state only after native work settles. A concurrent
      // gallery refresh or delete therefore cannot leave this projection tied
      // to an older MediaStore list.
      if (!_isCurrentRollRequest(requestGeneration)) return;
      final availableItems = state.items;
      final projections = <GalleryFilmRoll>[
        for (var index = 0; index < archivedRolls.length; index += 1)
          GalleryFilmRoll(
            roll: archivedRolls[index],
            captures:
                capturesByRoll[index][archivedRolls[index].id] ?? const [],
            availableItems: availableItems,
          ),
      ];
      state = state.copyWith(
        rollsStatus: projections.isEmpty
            ? GalleryRollLoadStatus.empty
            : GalleryRollLoadStatus.loaded,
        rolls: projections,
        rollsErrorMessage: null,
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentRollRequest(requestGeneration)) return;
      _logRollLoadFailure(error, stackTrace);
      state = state.copyWith(
        rollsStatus: GalleryRollLoadStatus.error,
        rollsErrorMessage: 'Film Roll history could not be loaded.',
      );
    }
  }

  Future<void> shareItem(String uri) =>
      _mediaStoreService.shareGalleryMedia(uri);

  Future<void> deleteItem(String uri) {
    // Invalidate a query that may already be in progress before Android
    // removes the URI. The next snapshot waits for this queue and sees the
    // post-delete store rather than reviving an old cover/frame.
    _mediaSnapshotGeneration += 1;
    _galleryReloadRequested = true;
    final operation = _mediaMutationQueue.then((_) async {
      await _mediaStoreService.deleteGalleryMedia(uri);
      final items = state.items
          .where((item) => item.contentUri != uri)
          .toList(growable: false);
      state = state.copyWith(
        status: items.isEmpty ? GalleryStatus.empty : GalleryStatus.loaded,
        items: items,
        errorMessage: null,
        rolls: state.rollsStatus == GalleryRollLoadStatus.initial
            ? state.rolls
            : _rebuildRolls(state.rolls, items),
      );
    });
    // Keep later deletes FIFO even when this one fails, while still allowing
    // the initiating UI action to receive the original failure.
    _mediaMutationQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> toggleFavorite(String id) async {
    await _ensureFavoritesLoaded();

    final favoriteIds = Set<String>.from(state.favoriteIds);
    if (!favoriteIds.add(id)) {
      favoriteIds.remove(id);
    }

    state = state.copyWith(favoriteIds: favoriteIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteIdsKey, favoriteIds.toList()..sort());
  }

  Future<void> setFavoritesOnly({required bool value}) async {
    await _ensureFavoritesLoaded();
    state = state.copyWith(showFavoritesOnly: value);
  }

  void setTimeFilter(GalleryTimeFilter filter) {
    state = state.copyWith(timeFilter: filter);
  }

  Future<void> _ensureFavoritesLoaded() async {
    if (_favoritesLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_favoriteIdsKey)?.toSet() ?? {};
    _favoritesLoaded = true;
    state = state.copyWith(favoriteIds: favoriteIds);
  }

  List<GalleryFilmRoll> _rebuildRolls(
    List<GalleryFilmRoll> rolls,
    List<GalleryMediaItem> items,
  ) => List<GalleryFilmRoll>.unmodifiable([
    for (final roll in rolls)
      GalleryFilmRoll(
        roll: roll.roll,
        captures: roll.captures,
        availableItems: items,
      ),
  ]);

  bool _isCurrentRollRequest(int requestGeneration) =>
      requestGeneration == _rollRequestGeneration;

  void _logRollLoadFailure(Object error, StackTrace stackTrace) {
    AppLogger.e(
      'GalleryController',
      'Failed to load Film Roll gallery projections',
      error,
      stackTrace,
    );
  }
}
