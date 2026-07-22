import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/gallery/services/styled_thumbnail_cache.dart';
import 'package:rana/features/preset/model/capture_style_metadata.dart';

/// Reusable Widget that dynamically renders clean photos using saved preset &
/// style parameters, backed by [StyledThumbnailCache] for 60 FPS scrolling.
class StyledImageView extends StatefulWidget {
  const StyledImageView({
    required this.mediaUri,
    super.key,
    this.metadata,
    this.fit = BoxFit.cover,
    this.targetSize = 360,
    this.placeholder,
    this.errorWidget,
  });

  final String mediaUri;
  final CaptureStyleMetadata? metadata;
  final BoxFit fit;
  final int targetSize;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<StyledImageView> createState() => _StyledImageViewState();
}

class _StyledImageViewState extends State<StyledImageView> {
  static ui.FragmentProgram? _cachedProgram;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  final CameraPlatformService _platformService = CameraPlatformService();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(StyledImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUri != widget.mediaUri ||
        oldWidget.metadata?.cacheKey != widget.metadata?.cacheKey ||
        oldWidget.targetSize != widget.targetSize) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final meta = widget.metadata;

    // 1. Check if styled thumbnail is cached
    if (meta != null && !meta.mediaIsRendered) {
      final cachedBytes = await StyledThumbnailCache.instance.get(
        meta.cacheKey,
      );
      if (cachedBytes != null && mounted) {
        setState(() {
          _imageBytes = cachedBytes;
          _isLoading = false;
        });
        return;
      }
    }

    // 2. Fetch base clean image bytes
    try {
      final baseBytes = await _platformService.loadCapturedImageBytes(
        widget.mediaUri,
        targetSize: widget.targetSize,
      );

      if (baseBytes.isEmpty) {
        if (mounted) setState(() => _hasError = true);
        return;
      }

      // If already rendered natively or no metadata, use base bytes
      if (meta == null || meta.mediaIsRendered) {
        if (mounted) {
          setState(() {
            _imageBytes = baseBytes;
            _isLoading = false;
          });
        }
        return;
      }

      // 3. Render clean image with GLSL Shader dynamically
      final renderedBytes = await _renderStyledImage(baseBytes, meta);
      if (renderedBytes != null) {
        await StyledThumbnailCache.instance.put(meta.cacheKey, renderedBytes);
      }

      if (mounted) {
        setState(() {
          _imageBytes = renderedBytes ?? baseBytes;
          _isLoading = false;
        });
      }
    } on Object catch (e, stack) {
      AppLogger.e(
        'StyledImageView',
        'Failed loading image: ${widget.mediaUri}',
        e,
        stack,
      );
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List?> _renderStyledImage(
    Uint8List baseBytes,
    CaptureStyleMetadata meta,
  ) async {
    try {
      _cachedProgram ??= await ui.FragmentProgram.fromAsset(
        'assets/shaders/rana_preset_filter.frag',
      );

      final codec = await ui.instantiateImageCodec(baseBytes);
      final frameInfo = await codec.getNextFrame();
      final baseImage = frameInfo.image;

      final width = baseImage.width.toDouble();
      final height = baseImage.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      final shader = _cachedProgram!.fragmentShader();
      shader.setFloat(0, width);
      shader.setFloat(1, height);
      shader.setImageSampler(0, baseImage);
      shader.setFloat(2, meta.undertoneX);
      shader.setFloat(3, meta.undertoneY);

      // Extract custom parameters (exposure, contrast, saturation)
      final exposure = (meta.params['exposure'] as num?)?.toDouble() ?? 0.0;
      final contrast = (meta.params['contrast'] as num?)?.toDouble() ?? 1.0;
      final saturation = (meta.params['saturation'] as num?)?.toDouble() ?? 1.0;

      shader.setFloat(4, exposure);
      shader.setFloat(5, contrast);
      shader.setFloat(6, saturation);

      final paint = Paint()..shader = shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

      final picture = recorder.endRecording();
      final renderedImage = await picture.toImage(
        baseImage.width,
        baseImage.height,
      );
      final byteData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } on Object catch (e, stack) {
      AppLogger.e('StyledImageView', 'Fallback shader render error', e, stack);
      return baseBytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ??
          const ColoredBox(
            color: Color(0xFF1E2025),
            child: Center(
              child: Icon(Icons.broken_image_rounded, color: Colors.white38),
            ),
          );
    }

    if (_isLoading || _imageBytes == null) {
      return widget.placeholder ??
          const ColoredBox(
            color: Color(0xFF1E2025),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF39C12),
                ),
              ),
            ),
          );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
    );
  }
}
