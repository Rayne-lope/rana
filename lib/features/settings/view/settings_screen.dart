import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';

/// Settings Screen — Displays settings and developer tools in debug mode.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: const Color(0xFF0F0F11),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F11),
          foregroundColor: Colors.white,
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          leading: BackButton(
            onPressed: () => context.go(AppRoutes.camera),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'PREFERENCES',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.tune, color: Colors.white54),
              title: Text(
                'Image Quality',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'High (Original RAW/JPEG)',
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.white24),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on, color: Colors.white54),
              title: const Text(
                'Grid Lines',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                ref.watch(gridLinesProvider) ? 'On (3x3)' : 'Off',
                style: const TextStyle(color: Colors.white30, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white24),
              onTap: () => ref
                  .read(gridLinesProvider.notifier)
                  .update((state) => !state),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'ABOUT',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.white54),
              title: Text(
                'Version',
                style: TextStyle(color: Colors.white),
              ),
              trailing: Text(
                '1.0.0-dev',
                style: TextStyle(color: Colors.white30, fontSize: 14),
              ),
            ),
            if (kDebugMode) ...[
              Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'DEVELOPER TOOLS',
                  style: TextStyle(
                    color: Color(0xFFF39C12),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.bug_report_outlined,
                  color: Color(0xFFF39C12),
                ),
                title: const Text(
                  'GL Shader Consistency',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Compare preview and export parameters',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFF39C12),
                ),
                onTap: () => context.push(AppRoutes.consistencyDebug),
              ),
            ],
          ],
        ),
      );
}
