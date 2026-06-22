import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/router/app_router.dart';

/// Splash screen shown briefly on app launch before redirecting to Camera.
///
/// Displays the Rana wordmark on a black background for [_duration],
/// then navigates to [AppRoutes.camera] using a replace so the user
/// cannot back-navigate to the splash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Duration _duration = Duration(milliseconds: 1200);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(SplashScreen._duration, () {
      if (mounted) {
        context.go(AppRoutes.camera);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 56,
              ),
              SizedBox(height: 16),
              Text(
                'Rana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 8,
                ),
              ),
            ],
          ),
        ),
      );
}
