import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rana/core/providers/permission_provider.dart';
import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/core/services/media_store_service.dart';
import 'package:rana/features/gallery/controller/gallery_controller.dart';
import 'package:rana/features/gallery/model/gallery_film_roll.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
import 'package:rana/features/gallery/view/gallery_detail_screen.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Gallery screen that reads Rana photos from Android MediaStore.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref.read(galleryPermissionControllerProvider.notifier).refresh();
      await _refreshGallery();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(galleryPermissionControllerProvider.notifier).refresh().then((
        _,
      ) {
        _refreshGallery();
      });
    }
  }

  /// Refreshes the active Gallery surface. Rolls remain lazy on a cold Photos
  /// launch, while a Rolls refresh first updates its MediaStore URI join.
  Future<void> _refreshGallery() {
    final state = ref.read(galleryControllerProvider);
    return ref
        .read(galleryControllerProvider.notifier)
        .refresh(includeRolls: state.viewMode == GalleryViewMode.rolls);
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(galleryPermissionControllerProvider);
    final galleryState = ref.watch(galleryControllerProvider);
    final controller = ref.read(galleryControllerProvider.notifier);
    final visibleItems = galleryState.visibleItems;
    final isRollsMode = galleryState.viewMode == GalleryViewMode.rolls;

    final showLoader =
        galleryState.status == GalleryStatus.loading &&
        galleryState.items.isEmpty;
    final showRollsLoader =
        (galleryState.rollsStatus == GalleryRollLoadStatus.initial ||
            galleryState.rollsStatus == GalleryRollLoadStatus.loading) &&
        galleryState.rolls.isEmpty;
    final isCurrentViewLoading = isRollsMode ? showRollsLoader : showLoader;
    final presets =
        ref.watch(presetsProvider).valueOrNull ?? const <PresetModel>[];

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D3037), // Top sheet titanium
            Color(0xFF1E2025), // Mid sheet gunmetal
            Color(0xFF121316), // Bottom sheet deep charcoal metal
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 72,
          leading: Center(
            child: _AppBarActionButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.go(AppRoutes.camera),
              tooltip: 'Back to Camera',
            ),
          ),
          title: const Text(
            'RANA GALLERY',
            style: TextStyle(
              color: Color(0xFFF39C12),
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _AppBarActionButton(
                icon: Icons.refresh_rounded,
                onPressed: isCurrentViewLoading ? null : _refreshGallery,
                tooltip: isRollsMode ? 'Refresh Film Rolls' : 'Refresh gallery',
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: const Color(0xFFF39C12),
          backgroundColor: const Color(0xFF17171B),
          onRefresh: _refreshGallery,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _GalleryViewModeControl(
                    viewMode: galleryState.viewMode,
                    onChanged: controller.setViewMode,
                  ),
                ),
              ),
              if (isRollsMode) ...[
                if (showRollsLoader)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _RollsLoadingState(),
                  )
                else if (galleryState.rollsStatus ==
                    GalleryRollLoadStatus.error)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _RollsErrorState(
                      message: galleryState.rollsErrorMessage,
                      onRetry: controller.loadRolls,
                    ),
                  )
                else if (galleryState.rolls.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _RollsEmptyState(
                      onTakePhoto: () => context.go(AppRoutes.camera),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: galleryState.rolls.length,
                      itemBuilder: (context, index) {
                        final filmRoll = galleryState.rolls[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == galleryState.rolls.length - 1
                                ? 0
                                : 12,
                          ),
                          child: _GalleryFilmRollCard(
                            key: ValueKey<String>(
                              'gallery-roll-${filmRoll.roll.id}',
                            ),
                            filmRoll: filmRoll,
                            presetName: _presetNameForRoll(filmRoll, presets),
                            onTap: () => context.push(
                              AppRoutes.rollDetail(filmRoll.roll.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ] else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _GallerySummaryCard(
                      itemCount: galleryState.items.length,
                      favoriteCount: galleryState.favoriteIds.length,
                      hasPermission: !galleryState.isPermissionDenied,
                      isLoading: showLoader,
                      showFavoritesOnly: galleryState.showFavoritesOnly,
                      onFavoritesOnlyChanged: (value) =>
                          controller.setFavoritesOnly(value: value),
                    ),
                  ),
                ),
                if (!galleryState.isPermissionDenied && !showLoader)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _GalleryFilterStrip(
                        activeFilter: galleryState.timeFilter,
                        showFavoritesOnly: galleryState.showFavoritesOnly,
                        onFilterChanged: controller.setTimeFilter,
                        onFavoritesOnlyChanged: (value) =>
                            controller.setFavoritesOnly(value: value),
                      ),
                    ),
                  ),
                if (permissionState.isLimited && !showLoader)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _GalleryLimitedAccessBanner(),
                    ),
                  ),
                if (showLoader)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _GalleryLoadingState(),
                  )
                else if (galleryState.isPermissionDenied)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _GalleryPermissionState(
                      isPermanentlyDenied: permissionState.isPermanentlyDenied,
                      onOpenSettings: openAppSettings,
                      onRequestAccess: () async {
                        await ref
                            .read(galleryPermissionControllerProvider.notifier)
                            .requestGalleryAccess();
                        await controller.loadGallery();
                      },
                      onRetryCheck: () async {
                        await ref
                            .read(galleryPermissionControllerProvider.notifier)
                            .refresh();
                        await controller.loadGallery();
                      },
                    ),
                  )
                else if (galleryState.status == GalleryStatus.error &&
                    galleryState.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _GalleryErrorState(
                      message: galleryState.errorMessage,
                      onRetry: controller.loadGallery,
                    ),
                  )
                else if (visibleItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _GalleryEmptyState(
                      showFavoritesOnly: galleryState.showFavoritesOnly,
                      onTakePhoto: () => context.go(AppRoutes.camera),
                      onFindPreviousInstallPhotos: permissionState.canRead
                          ? null
                          : () async {
                              await ref
                                  .read(
                                    galleryPermissionControllerProvider
                                        .notifier,
                                  )
                                  .requestGalleryAccess();
                              await controller.loadGallery();
                            },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final crossAxisCount = width >= 520 ? 3 : 2;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.82,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = visibleItems[index];
                            return _GalleryTile(
                              key: ValueKey<String>('gallery-tile-${item.id}'),
                              item: item,
                              isFavorite: galleryState.isFavorite(item.id),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => GalleryDetailScreen(
                                    items: visibleItems,
                                    initialIndex: index,
                                  ),
                                ),
                              ),
                              onLongPress: () => _showGalleryActions(
                                context: context,
                                ref: ref,
                                item: item,
                                isFavorite: galleryState.isFavorite(item.id),
                              ),
                            );
                          }, childCount: visibleItems.length),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _presetNameForRoll(
    GalleryFilmRoll filmRoll,
    List<PresetModel> presets,
  ) {
    final presetId = filmRoll.roll.presetId;
    for (final preset in presets) {
      if (preset.id == presetId) return preset.name;
    }
    return presetId;
  }
}

Future<void> _showGalleryActions({
  required BuildContext context,
  required WidgetRef ref,
  required GalleryMediaItem item,
  required bool isFavorite,
}) async {
  final action = await showModalBottomSheet<_GalleryAction>(
    context: context,
    backgroundColor: const Color(0xFF17171B),
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: const Color(0xFFF39C12),
            ),
            title: Text(
              isFavorite ? 'Remove favorite' : 'Favorite',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.of(context).pop(_GalleryAction.favorite),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded, color: Colors.white70),
            title: const Text('Share', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).pop(_GalleryAction.share),
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFF39C12),
            ),
            title: const Text('Delete', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).pop(_GalleryAction.delete),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  final controller = ref.read(galleryControllerProvider.notifier);
  try {
    switch (action) {
      case _GalleryAction.favorite:
        await controller.toggleFavorite(item.id);
      case _GalleryAction.share:
        await controller.shareItem(item.contentUri);
      case _GalleryAction.delete:
        final shouldDelete = await _confirmGalleryDelete(context, item);
        if (shouldDelete == true) {
          await controller.deleteItem(item.contentUri);
        }
    }
  } on Object catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to complete this gallery action.')),
    );
  }
}

Future<bool?> _confirmGalleryDelete(
  BuildContext context,
  GalleryMediaItem item,
) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: const Color(0xFF17171B),
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    ),
    contentTextStyle: const TextStyle(color: Colors.white70, height: 1.4),
    title: const Text('Delete photo?'),
    content: Text('${item.displayName} will be removed from MediaStore.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('CANCEL'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF39C12),
          foregroundColor: Colors.black,
        ),
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('DELETE'),
      ),
    ],
  ),
);

enum _GalleryAction { favorite, share, delete }

/// Compact Photos/Rolls mode selector kept close to the Gallery heading.
class _GalleryViewModeControl extends StatelessWidget {
  const _GalleryViewModeControl({
    required this.viewMode,
    required this.onChanged,
  });

  final GalleryViewMode viewMode;
  final ValueChanged<GalleryViewMode> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Gallery view',
    child: Container(
      // 3dp inset on both sides leaves each segmented action with the
      // required 48dp minimum tap target.
      height: 54,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _GalleryViewModeButton(
            key: const ValueKey<String>('gallery-mode-photos'),
            icon: Icons.photo_library_outlined,
            label: 'PHOTOS',
            isSelected: viewMode == GalleryViewMode.photos,
            onTap: () => onChanged(GalleryViewMode.photos),
          ),
          const SizedBox(width: 4),
          _GalleryViewModeButton(
            key: const ValueKey<String>('gallery-mode-rolls'),
            icon: Icons.local_movies_outlined,
            label: 'ROLLS',
            isSelected: viewMode == GalleryViewMode.rolls,
            onTap: () => onChanged(GalleryViewMode.rolls),
          ),
        ],
      ),
    ),
  );
}

class _GalleryViewModeButton extends StatelessWidget {
  const _GalleryViewModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: isSelected,
      label: '$label view',
      hint: isSelected ? 'Selected' : 'Show $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: isSelected ? const Color(0xFFF39C12) : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF39C12).withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isSelected ? Colors.black : Colors.white60,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RollsLoadingState extends StatelessWidget {
  const _RollsLoadingState();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'Loading Film Rolls',
      liveRegion: true,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 34,
            child: CircularProgressIndicator(
              color: Color(0xFFF39C12),
              strokeWidth: 2.6,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'LOADING FILM ROLLS',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RollsEmptyState extends StatelessWidget {
  const _RollsEmptyState({required this.onTakePhoto});

  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.local_movies_outlined,
              color: Color(0xFFF39C12),
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO FILM ROLLS YET',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Load a Film Roll in Camera to keep its photos together here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey<String>('gallery-rolls-open-camera'),
            onPressed: onTakePhoto,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('OPEN CAMERA'),
          ),
        ],
      ),
    ),
  );
}

class _RollsErrorState extends StatelessWidget {
  const _RollsErrorState({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFF39C12),
            size: 42,
          ),
          const SizedBox(height: 16),
          const Text(
            'FAILED TO LOAD FILM ROLLS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              message ?? 'Film Roll history could not be loaded.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.45),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey<String>('gallery-rolls-retry'),
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
            ),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    ),
  );
}

class _GalleryFilmRollCard extends StatelessWidget {
  const _GalleryFilmRollCard({
    required this.filmRoll,
    required this.presetName,
    required this.onTap,
    super.key,
  });

  final GalleryFilmRoll filmRoll;
  final String presetName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roll = filmRoll.roll;
    final availableCount = filmRoll.availableItems.length;
    final unavailableCount = filmRoll.unavailableFrameCount;
    final totalCount = roll.exposuresTaken;
    final statusLabel = filmRoll.isEarlyEnded
        ? 'ENDED EARLY'
        : roll.isFull
        ? 'COMPLETE'
        : roll.isActive
        ? 'ACTIVE ROLL'
        : 'ARCHIVED';
    final availabilityLabel = totalCount == 0
        ? 'NO SAVED FRAMES'
        : '$availableCount OF $totalCount '
              'FRAME${totalCount == 1 ? '' : 'S'} AVAILABLE';
    final dateLabel = _filmRollDateRangeLabel(
      filmRoll.dateRangeStart,
      filmRoll.dateRangeEnd,
    );
    final unavailableFrameWord = unavailableCount == 1 ? 'frame' : 'frames';
    final unavailableSemanticLabel =
        '$unavailableCount unavailable $unavailableFrameWord';
    final semanticLabel = [
      'Film Roll',
      presetName,
      statusLabel,
      '${roll.exposuresTaken} of ${roll.size.count} exposures',
      availabilityLabel.toLowerCase(),
      dateLabel,
      if (unavailableCount > 0) unavailableSemanticLabel,
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      hint: 'Open Film Roll details',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 148),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF24262C), Color(0xFF15161A)],
                ),
                border: Border.all(
                  color: const Color(0xFFF39C12).withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _RollCoverThumbnail(item: filmRoll.preferredCover),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_movies_outlined,
                                size: 16,
                                color: const Color(
                                  0xFFF4C44F,
                                ).withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  presetName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.05,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${roll.exposuresTaken}/${roll.size.count} '
                            'EXPOSURES',
                            style: const TextStyle(
                              color: Color(0xFFF4C44F),
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _RollCardBadge(
                                label: statusLabel,
                                color: filmRoll.isEarlyEnded
                                    ? const Color(0xFFF4C44F)
                                    : const Color(0xFF81C784),
                              ),
                              if (unavailableCount > 0)
                                _RollCardBadge(
                                  label:
                                      'PARTIAL · $unavailableCount UNAVAILABLE',
                                  color: const Color(0xFFE57373),
                                ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            availabilityLabel,
                            style: const TextStyle(
                              color: Color(0xFFF4C44F),
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RollCardBadge extends StatelessWidget {
  const _RollCardBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontSize: 8.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _RollCoverThumbnail extends StatefulWidget {
  const _RollCoverThumbnail({required this.item});

  final GalleryMediaItem? item;

  @override
  State<_RollCoverThumbnail> createState() => _RollCoverThumbnailState();
}

class _RollCoverThumbnailState extends State<_RollCoverThumbnail> {
  final MediaStoreService _service = MediaStoreService();
  Future<Uint8List>? _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _RollCoverThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.contentUri != widget.item?.contentUri) {
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    final item = widget.item;
    _thumbnailFuture = item == null
        ? null
        : _service.loadThumbnailBytes(item.contentUri, targetSize: 480);
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailFuture = _thumbnailFuture;
    return SizedBox(
      width: 116,
      height: 148,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(19),
          bottomLeft: Radius.circular(19),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF1A1B20)),
          child: thumbnailFuture == null
              ? const _RollCoverPlaceholder()
              : FutureBuilder<Uint8List>(
                  future: thumbnailFuture,
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (snapshot.connectionState != ConnectionState.done ||
                        bytes == null ||
                        bytes.isEmpty) {
                      return const _RollCoverPlaceholder();
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _RollCoverPlaceholder extends StatelessWidget {
  const _RollCoverPlaceholder();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF34363D), Color(0xFF17181C)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.local_movies_outlined,
        color: Color(0xFFF4C44F),
        size: 31,
      ),
    ),
  );
}

String _filmRollDateRangeLabel(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'DATE UNAVAILABLE';
  final first = start ?? end!;
  final last = end ?? first;
  final firstLabel = _formatRollDate(first);
  final lastLabel = _formatRollDate(last);
  return firstLabel == lastLabel ? firstLabel : '$firstLabel to $lastLabel';
}

String _formatRollDate(DateTime date) {
  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[date.month - 1]} '
      '${date.day.toString().padLeft(2, '0')}, ${date.year}';
}

class _FavoriteFilterButton extends StatefulWidget {
  const _FavoriteFilterButton({
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  final bool isSelected;
  final int count;
  final VoidCallback? onTap;

  @override
  State<_FavoriteFilterButton> createState() => _FavoriteFilterButtonState();
}

class _FavoriteFilterButtonState extends State<_FavoriteFilterButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const activeGrad = LinearGradient(
      colors: [Color(0xFFF4C44F), Color(0xFFF39C12)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _isPressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _isPressed = false)
          : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: widget.isSelected ? activeGrad : null,
            color: widget.isSelected
                ? null
                : Colors.black.withValues(alpha: 0.42),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFFD4840C)
                  : Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? const Color(0xFFF39C12).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSelected
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 14,
                color: widget.isSelected ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                '${widget.count}',
                style: TextStyle(
                  color: widget.isSelected ? Colors.black : Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GallerySummaryCard extends StatelessWidget {
  const _GallerySummaryCard({
    required this.itemCount,
    required this.favoriteCount,
    required this.hasPermission,
    required this.isLoading,
    required this.showFavoritesOnly,
    required this.onFavoritesOnlyChanged,
  });

  final int itemCount;
  final int favoriteCount;
  final bool hasPermission;
  final bool isLoading;
  final bool showFavoritesOnly;
  final ValueChanged<bool> onFavoritesOnlyChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [
          Color(0xFF2C2F36), // Brushed titanium
          Color(0xFF1E2025),
          Color(0xFF15161A),
        ],
        stops: [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF131416), Color(0xFF24272D)],
                center: Alignment(-0.1, -0.1),
                radius: 0.6,
              ),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              hasPermission
                  ? Icons.photo_library_rounded
                  : Icons.lock_outline_rounded,
              color: const Color(0xFFF39C12),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RANA LIBRARY',
                  style: TextStyle(
                    color: Color(0xFFF39C12),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isLoading ? 'Loading recent captures' : _photoCountLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _FavoriteFilterButton(
            isSelected: showFavoritesOnly,
            count: favoriteCount,
            onTap: hasPermission && !isLoading
                ? () => onFavoritesOnlyChanged(!showFavoritesOnly)
                : null,
          ),
        ],
      ),
    ),
  );

  String get _photoCountLabel {
    final plural = itemCount == 1 ? '' : 's';
    return '$itemCount photo$plural saved in MediaStore';
  }
}

class _GalleryLoadingState extends StatelessWidget {
  const _GalleryLoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF39C12)),
        ),
        SizedBox(height: 16),
        Text(
          'SCANNING MEDIASTORE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

class _GalleryPermissionState extends StatelessWidget {
  const _GalleryPermissionState({
    required this.isPermanentlyDenied,
    required this.onOpenSettings,
    required this.onRequestAccess,
    required this.onRetryCheck,
  });

  final bool isPermanentlyDenied;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onRequestAccess;
  final Future<void> Function() onRetryCheck;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Color(0xFFF39C12),
            size: 62,
          ),
          const SizedBox(height: 16),
          const Text(
            'PHOTOS ACCESS REQUIRED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isPermanentlyDenied
                ? 'Photos access was permanently denied. Open system '
                      'settings to enable it, then come back here.'
                : 'Rana can show photos from its current install without '
                      'access. Allow photo access to find older Rana captures.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isPermanentlyDenied ? onOpenSettings : onRequestAccess,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isPermanentlyDenied ? 'OPEN SETTINGS' : 'ALLOW PHOTO ACCESS',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetryCheck, child: const Text('CHECK AGAIN')),
        ],
      ),
    ),
  );
}

class _GalleryLimitedAccessBanner extends StatelessWidget {
  const _GalleryLimitedAccessBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFF39C12).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFFF39C12).withValues(alpha: 0.35),
      ),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded, color: Color(0xFFF39C12), size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Photo access is limited. Only images allowed by Android may '
            'appear.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _GalleryErrorState extends StatelessWidget {
  const _GalleryErrorState({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 62,
          ),
          const SizedBox(height: 16),
          const Text(
            'FAILED TO LOAD GALLERY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message ?? 'MediaStore query returned an error.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
            ),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    ),
  );
}

class _GalleryEmptyState extends StatelessWidget {
  const _GalleryEmptyState({
    required this.showFavoritesOnly,
    required this.onTakePhoto,
    required this.onFindPreviousInstallPhotos,
  });

  final bool showFavoritesOnly;
  final VoidCallback onTakePhoto;
  final Future<void> Function()? onFindPreviousInstallPhotos;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white54,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            showFavoritesOnly ? 'NO FAVORITES YET' : 'NO RANA PHOTOS YET',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            showFavoritesOnly
                ? 'Tap the heart on a photo to keep it in your favorites.'
                : 'Capture a photo and it will appear here automatically from '
                      'MediaStore.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onTakePhoto,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
            ),
            child: const Text('OPEN CAMERA'),
          ),
          if (!showFavoritesOnly && onFindPreviousInstallPhotos != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onFindPreviousInstallPhotos,
              child: const Text('FIND PHOTOS FROM PREVIOUS RANA INSTALL'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _GalleryTile extends StatefulWidget {
  const _GalleryTile({
    required this.item,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final GalleryMediaItem item;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  late final Future<Uint8List> _thumbnailFuture;
  final MediaStoreService _service = MediaStoreService();

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _service.loadThumbnailBytes(widget.item.contentUri);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onLongPress: widget.onLongPress,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF16171B),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List>(
              future: _thumbnailFuture,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (snapshot.connectionState != ConnectionState.done ||
                    bytes == null ||
                    bytes.isEmpty) {
                  return const ColoredBox(
                    color: Color(0xFF1B1B20),
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white24,
                        size: 28,
                      ),
                    ),
                  );
                }

                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0x66000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (widget.isFavorite)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFF39C12),
                  size: 20,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(17),
                  bottomRight: Radius.circular(17),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.captureStamp,
                          style: const TextStyle(
                            color: Color(0xFFF39C12),
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GalleryFilterStrip extends StatelessWidget {
  const _GalleryFilterStrip({
    required this.activeFilter,
    required this.showFavoritesOnly,
    required this.onFilterChanged,
    required this.onFavoritesOnlyChanged,
  });

  final GalleryTimeFilter activeFilter;
  final bool showFavoritesOnly;
  final ValueChanged<GalleryTimeFilter> onFilterChanged;
  final ValueChanged<bool> onFavoritesOnlyChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _buildFilterChip(
          label: 'ALL TIME',
          isSelected:
              activeFilter == GalleryTimeFilter.all && !showFavoritesOnly,
          onSelected: (_) {
            onFilterChanged(GalleryTimeFilter.all);
            onFavoritesOnlyChanged(false);
          },
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: 'TODAY',
          isSelected:
              activeFilter == GalleryTimeFilter.today && !showFavoritesOnly,
          onSelected: (_) {
            onFilterChanged(GalleryTimeFilter.today);
            onFavoritesOnlyChanged(false);
          },
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: 'THIS WEEK',
          isSelected:
              activeFilter == GalleryTimeFilter.thisWeek && !showFavoritesOnly,
          onSelected: (_) {
            onFilterChanged(GalleryTimeFilter.thisWeek);
            onFavoritesOnlyChanged(false);
          },
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: 'FAVORITES',
          isSelected: showFavoritesOnly,
          onSelected: (selected) {
            onFavoritesOnlyChanged(selected);
            if (selected) {
              onFilterChanged(GalleryTimeFilter.all);
            }
          },
          icon: Icons.favorite_rounded,
        ),
      ],
    ),
  );

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    IconData? icon,
  }) => GestureDetector(
    onTap: () => onSelected(!isSelected),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4C44F), Color(0xFFF39C12)],
              )
            : null,
        color: isSelected ? null : Colors.black.withValues(alpha: 0.36),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFF39C12)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFF39C12).withValues(alpha: 0.24),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: isSelected ? Colors.black : const Color(0xFFF39C12),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    ),
  );
}

class _AppBarActionButton extends StatelessWidget {
  const _AppBarActionButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.15, -0.2),
                colors: isEnabled
                    ? const [
                        Color(0xFF3E424B),
                        Color(0xFF202227),
                        Color(0xFF131416),
                      ]
                    : const [
                        Color(0xFF24262A),
                        Color(0xFF181A1C),
                        Color(0xFF0F1011),
                      ],
                stops: const [0.0, 0.7, 1.0],
              ),
              border: Border.all(
                color: isEnabled
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                width: 0.8,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isEnabled ? const Color(0xFFF39C12) : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}
