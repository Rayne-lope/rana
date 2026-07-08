import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rana/core/providers/permission_provider.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/core/services/media_store_service.dart';
import 'package:rana/features/gallery/controller/gallery_controller.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
import 'package:rana/features/gallery/view/gallery_detail_screen.dart';

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
      await ref.read(permissionControllerProvider.notifier).checkPermissions();
      await ref.read(galleryControllerProvider.notifier).loadGallery();
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
      ref.read(permissionControllerProvider.notifier).checkPermissions().then((
        _,
      ) {
        ref.read(galleryControllerProvider.notifier).loadGallery();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionControllerProvider);
    final galleryState = ref.watch(galleryControllerProvider);
    final controller = ref.read(galleryControllerProvider.notifier);
    final visibleItems = galleryState.visibleItems;

    final showLoader =
        permissionState.isChecking ||
        (galleryState.status == GalleryStatus.loading &&
            galleryState.items.isEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        foregroundColor: Colors.white,
        title: const Text(
          'Gallery',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
        leading: BackButton(onPressed: () => context.go(AppRoutes.camera)),
        actions: [
          IconButton(
            onPressed: showLoader ? null : controller.loadGallery,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh gallery',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF15151A), Color(0xFF0F0F11)],
          ),
        ),
        child: RefreshIndicator(
          color: const Color(0xFFF39C12),
          backgroundColor: const Color(0xFF17171B),
          onRefresh: controller.loadGallery,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _GallerySummaryCard(
                    itemCount: galleryState.items.length,
                    favoriteCount: galleryState.favoriteIds.length,
                    hasPermission: permissionState.hasStorage,
                    isLoading: showLoader,
                    showFavoritesOnly: galleryState.showFavoritesOnly,
                    onFavoritesOnlyChanged: (value) =>
                        controller.setFavoritesOnly(value: value),
                  ),
                ),
              ),
              if (permissionState.hasStorage && !showLoader)
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
              if (showLoader)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _GalleryLoadingState(),
                )
              else if (!permissionState.hasStorage)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _GalleryPermissionState(
                    isPermanentlyDenied: permissionState.isPermanentlyDenied,
                    onOpenSettings: openAppSettings,
                    onRetryCheck: () async {
                      await ref
                          .read(permissionControllerProvider.notifier)
                          .checkPermissions();
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
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
          ),
        ),
      ),
    );
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
      gradient: LinearGradient(
        colors: [
          const Color(0xFFF39C12).withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              color: Colors.black.withValues(alpha: 0.34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              hasPermission
                  ? Icons.photo_library_rounded
                  : Icons.lock_outline_rounded,
              color: const Color(0xFFF39C12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RANA LIBRARY',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading ? 'Loading recent captures' : _photoCountLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilterChip(
            selected: showFavoritesOnly,
            onSelected: hasPermission && !isLoading
                ? onFavoritesOnlyChanged
                : null,
            avatar: Icon(
              showFavoritesOnly
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 16,
            ),
            label: Text('$favoriteCount'),
            selectedColor: const Color(0xFFF39C12),
            backgroundColor: Colors.black.withValues(alpha: 0.26),
            checkmarkColor: Colors.black,
            labelStyle: TextStyle(
              color: showFavoritesOnly ? Colors.black : Colors.white70,
              fontWeight: FontWeight.w800,
            ),
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
    required this.onRetryCheck,
  });

  final bool isPermanentlyDenied;
  final VoidCallback onOpenSettings;
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
                : 'Rana needs READ_MEDIA_IMAGES access to show saved '
                      'captures from your device library.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onOpenSettings,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isPermanentlyDenied ? 'OPEN SETTINGS' : 'OPEN SETTINGS',
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
  });

  final bool showFavoritesOnly;
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
          color: const Color(0xFF17171B),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                  colors: [Colors.transparent, Color(0xC2000000)],
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
                  size: 22,
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item.captureStamp,
                    style: const TextStyle(
                      color: Color(0xFFF39C12),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
              isSelected: activeFilter == GalleryTimeFilter.all &&
                  !showFavoritesOnly,
              onSelected: (_) {
                onFilterChanged(GalleryTimeFilter.all);
                onFavoritesOnlyChanged(false);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'TODAY',
              isSelected: activeFilter == GalleryTimeFilter.today &&
                  !showFavoritesOnly,
              onSelected: (_) {
                onFilterChanged(GalleryTimeFilter.today);
                onFavoritesOnlyChanged(false);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'THIS WEEK',
              isSelected: activeFilter == GalleryTimeFilter.thisWeek &&
                  !showFavoritesOnly,
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
  }) =>
      ChoiceChip(
        avatar: icon != null
            ? Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.black : const Color(0xFFF39C12),
              )
            : null,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: const Color(0xFFF39C12),
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFF39C12)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      );
}
