import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/camera/controller/camera_controller.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({required this.imageUri, super.key});

  final String imageUri;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  late final Future<Uint8List> _imageBytesFuture;
  final CameraPlatformService _platformService = CameraPlatformService();
  bool _didAcknowledgeDismissal = false;

  @override
  void initState() {
    super.initState();
    _imageBytesFuture = _platformService.loadCapturedImageBytes(
      widget.imageUri,
    );
  }

  void _acknowledgeDismissal() {
    if (_didAcknowledgeDismissal) {
      return;
    }
    _didAcknowledgeDismissal = true;
    ref.read(cameraControllerProvider.notifier).acknowledgeResultDismissed();
  }

  void _dismissResult() {
    _acknowledgeDismissal();
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _openInGallery() =>
      _platformService.openMediaInGallery(widget.imageUri);

  @override
  Widget build(BuildContext context) => PopScope<void>(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) {
        _acknowledgeDismissal();
      }
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 180),
                child: Center(
                  child: FutureBuilder<Uint8List>(
                    future: _imageBytesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF39C12),
                          ),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        return _ResultLoadFailure(
                          onShootAgain: _dismissResult,
                          onViewInGallery: _openInGallery,
                        );
                      }

                      return DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _ResultActions(
                dateStamp: _buildDateStamp(),
                onShootAgain: _dismissResult,
                onViewInGallery: _openInGallery,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _buildDateStamp() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2);
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$day $month $year  $hour:$minute';
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.dateStamp,
    required this.onShootAgain,
    required this.onViewInGallery,
  });

  final String dateStamp;
  final VoidCallback onShootAgain;
  final Future<void> Function() onViewInGallery;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dateStamp,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Courier',
              color: Color(0xFFF39C12),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onShootAgain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SHOOT AGAIN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onViewInGallery,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'VIEW IN GALLERY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ResultLoadFailure extends StatelessWidget {
  const _ResultLoadFailure({
    required this.onShootAgain,
    required this.onViewInGallery,
  });

  final VoidCallback onShootAgain;
  final Future<void> Function() onViewInGallery;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF16171B),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'FAILED TO LOAD PHOTO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can still return to the camera or open the saved photo '
            'in the gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          _ResultActions(
            dateStamp: '-- -- --  --:--',
            onShootAgain: onShootAgain,
            onViewInGallery: onViewInGallery,
          ),
        ],
      ),
    ),
  );
}
