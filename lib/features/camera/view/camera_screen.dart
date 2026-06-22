import 'package:flutter/material.dart';

/// Stub Camera Screen — Phase 0 placeholder.
///
/// Navigation to Gallery and Settings is handled by [MainShell]'s
/// [NavigationBar] — no manual nav calls needed here.
/// Real CameraX preview will be wired in Phase 1.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Spacer(),
              Center(
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white24,
                  size: 80,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Rana Camera',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Phase 0 Placeholder',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
              Spacer(),
              // Shutter button placeholder
              Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Icon(
                  Icons.circle_outlined,
                  color: Colors.white54,
                  size: 72,
                ),
              ),
            ],
          ),
        ),
      );
}
