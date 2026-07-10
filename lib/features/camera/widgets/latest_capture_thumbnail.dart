import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rana/core/services/camera_platform_service.dart';

/// Displays the most recently saved capture without assuming it is a file URI.
class LatestCaptureThumbnail extends StatefulWidget {
  const LatestCaptureThumbnail({required this.imageUri, super.key});

  final String? imageUri;

  @override
  State<LatestCaptureThumbnail> createState() => _LatestCaptureThumbnailState();
}

class _LatestCaptureThumbnailState extends State<LatestCaptureThumbnail> {
  static const _decodeTargetSize = 256;

  final CameraPlatformService _platformService = CameraPlatformService();
  Uint8List? _imageBytes;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadLatestCapture();
  }

  @override
  void didUpdateWidget(LatestCaptureThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUri != widget.imageUri) {
      _loadLatestCapture();
    }
  }

  void _loadLatestCapture() {
    final generation = ++_loadGeneration;
    final imageUri = widget.imageUri;
    if (imageUri == null || imageUri.isEmpty) {
      if (_imageBytes != null) {
        setState(() => _imageBytes = null);
      }
      return;
    }

    unawaited(() async {
      try {
        final bytes = await _platformService.loadCapturedImageBytes(
          imageUri,
          targetSize: _decodeTargetSize,
        );
        if (!mounted || generation != _loadGeneration || bytes.isEmpty) {
          return;
        }
        setState(() => _imageBytes = bytes);
      } on Object {
        // Keep the previous thumbnail when a MediaStore read is unavailable.
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes;
    if (imageBytes == null) {
      return const ColoredBox(
        color: Color(0xFF1E1E24),
        child: Icon(
          Icons.photo_library_outlined,
          color: Colors.white54,
          size: 24,
        ),
      );
    }

    return Image.memory(
      imageBytes,
      key: ValueKey<String?>(widget.imageUri),
      fit: BoxFit.cover,
      width: 54,
      height: 54,
      gaplessPlayback: true,
      cacheWidth: _decodeTargetSize,
      cacheHeight: _decodeTargetSize,
    );
  }
}
