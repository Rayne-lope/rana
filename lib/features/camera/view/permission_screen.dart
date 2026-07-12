import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rana/core/providers/permission_provider.dart';

/// Permission screen displayed when Camera access is missing.
class CameraPermissionScreen extends ConsumerWidget {
  const CameraPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(cameraPermissionControllerProvider);
    final controller = ref.read(cameraPermissionControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11), // Deep slate black
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Camera retro logo/icon header
              const Center(
                child: Icon(
                  Icons.photo_camera_back_outlined,
                  color: Color(0xFFF39C12), // Vintage gold/yellow
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'CAMERA ACCESS REQUIRED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Rana needs camera access to show the viewfinder and take '
                'your analog photos. Photo-library access stays optional.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Camera is the only permission that blocks the viewfinder.
              _buildPermissionStatusCard(
                title: 'Camera Access',
                icon: Icons.camera_alt_rounded,
                isGranted: permissionState.isGranted,
              ),

              const Spacer(),

              // Action buttons
              if (permissionState.isPermanentlyDenied) ...[
                const Text(
                  'Permissions are permanently disabled. Please go to '
                  'system settings to enable them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE74C3C), // Warning red
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: openAppSettings,
                  style: _buildButtonStyle(const Color(0xFFE74C3C)),
                  child: const Text('OPEN APP SETTINGS'),
                ),
              ] else
                ElevatedButton(
                  onPressed: controller.requestCamera,
                  style: _buildButtonStyle(const Color(0xFFF39C12)),
                  child: const Text('ALLOW CAMERA'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionStatusCard({
    required String title,
    required IconData icon,
    required bool isGranted,
  }) {
    final accentColor = isGranted
        ? const Color(0xFF2ECC71) // Safe green
        : const Color(0xFFE74C3C); // Alert red

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accentColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  ButtonStyle _buildButtonStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.black,
    elevation: 4,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
    ),
  );
}
