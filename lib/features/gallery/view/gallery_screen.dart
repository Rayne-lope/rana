import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/router/app_router.dart';

/// Stub Gallery Screen — Phase 0 placeholder.
/// Real MediaStore integration will be wired in Phase 6.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Gallery'),
          leading: BackButton(
            onPressed: () => context.go(AppRoutes.camera),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'Gallery\n(Placeholder — Phase 0)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
}
