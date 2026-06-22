import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/router/app_router.dart';

/// Stub Camera Screen — Phase 0 placeholder.
/// Real camera preview will be wired in Phase 1.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Center(
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rana Camera\n(Preview — Phase 0)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.gallery),
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    tooltip: 'Gallery',
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.circle,
                      color: Colors.white,
                      size: 56,
                    ),
                    tooltip: 'Capture',
                  ),
                  IconButton(
                    onPressed: () => context.go(AppRoutes.settings),
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
