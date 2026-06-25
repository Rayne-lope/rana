import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/gallery/controller/gallery_controller.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';

class GalleryDetailScreen extends ConsumerStatefulWidget {
  const GalleryDetailScreen({
    required this.items,
    required this.initialIndex,
    super.key,
  });

  final List<GalleryMediaItem> items;
  final int initialIndex;

  @override
  ConsumerState<GalleryDetailScreen> createState() =>
      _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends ConsumerState<GalleryDetailScreen> {
  final CameraPlatformService _cameraService = CameraPlatformService();
  final Map<String, Future<Uint8List>> _imageFutures = {};

  late final PageController _pageController;
  late List<GalleryMediaItem> _items;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _items = List<GalleryMediaItem>.from(widget.items);
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryControllerProvider);
    final item = _items[_currentIndex];
    final isFavorite = galleryState.isFavorite(item.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${_items.length}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Remove favorite' : 'Favorite',
            onPressed: () => unawaited(
              ref
                  .read(galleryControllerProvider.notifier)
                  .toggleFavorite(item.id),
            ),
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite ? const Color(0xFFF39C12) : Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Share photo',
            onPressed: () => _share(item),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Delete photo',
            onPressed: () => _confirmDelete(item),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final pageItem = _items[index];
              return _ZoomableGalleryImage(
                future: _imageFutureFor(pageItem.contentUri),
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20 + MediaQuery.paddingOf(context).bottom,
            child: _GalleryMetadataPanel(item: item),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _imageFutureFor(String uri) => _imageFutures.putIfAbsent(
    uri,
    () => _cameraService.loadCapturedImageBytes(uri),
  );

  Future<void> _share(GalleryMediaItem item) async {
    try {
      await ref
          .read(galleryControllerProvider.notifier)
          .shareItem(item.contentUri);
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share this photo.')),
      );
    }
  }

  Future<void> _confirmDelete(GalleryMediaItem item) async {
    final shouldDelete = await showDialog<bool>(
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
    if (shouldDelete != true) return;

    try {
      await ref
          .read(galleryControllerProvider.notifier)
          .deleteItem(item.contentUri);
      _items.removeWhere(
        (candidate) => candidate.contentUri == item.contentUri,
      );
      final removedFuture = _imageFutures.remove(item.contentUri);
      if (removedFuture != null) {
        unawaited(removedFuture);
      }

      if (!mounted) return;
      if (_items.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _currentIndex = _currentIndex.clamp(0, _items.length - 1);
      });
      _pageController.jumpToPage(_currentIndex);
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete this photo.')),
      );
    }
  }
}

class _ZoomableGalleryImage extends StatelessWidget {
  const _ZoomableGalleryImage({required this.future});

  final Future<Uint8List> future;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done ||
          bytes == null ||
          bytes.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF39C12)),
          ),
        );
      }

      return InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      );
    },
  );
}

class _GalleryMetadataPanel extends StatelessWidget {
  const _GalleryMetadataPanel({required this.item});

  final GalleryMediaItem item;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.captureStamp,
            style: const TextStyle(
              color: Color(0xFFF39C12),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.dimensionsLabel}  ${_formatSize(item.sizeBytes)}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'UNKNOWN FILE SIZE';
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)} MB';
  }
}
