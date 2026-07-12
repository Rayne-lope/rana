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
      leading: BackButton(onPressed: () => context.go(AppRoutes.camera)),
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
        _OutputQualityTile(ref: ref),
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
          onTap: () =>
              ref.read(gridLinesProvider.notifier).update((state) => !state),
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
          title: Text('Version', style: TextStyle(color: Colors.white)),
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
            trailing: const Icon(Icons.chevron_right, color: Color(0xFFF39C12)),
            onTap: () => context.push(AppRoutes.consistencyDebug),
          ),
        ],
      ],
    ),
  );
}

class _OutputQualityTile extends ConsumerWidget {
  const _OutputQualityTile({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final quality =
        ref.watch(outputQualityProvider).valueOrNull ?? OutputQuality.highJpeg;
    final capabilities = ref.watch(outputCapabilitiesProvider).valueOrNull;

    return ListTile(
      leading: const Icon(Icons.tune, color: Colors.white54),
      title: const Text('Image Quality', style: TextStyle(color: Colors.white)),
      subtitle: Text(
        '${quality.label} · ${quality == OutputQuality.efficientHeic
            ? 'HEIC 90'
            : quality == OutputQuality.standardJpeg
            ? 'JPEG 88'
            : 'JPEG 95'}',
        style: const TextStyle(color: Colors.white30, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () => _showOutputQualitySheet(context, ref, capabilities),
    );
  }

  Future<void> _showOutputQualitySheet(
    BuildContext context,
    WidgetRef ref,
    OutputCapabilities? capabilities,
  ) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF17171B),
    showDragHandle: true,
    builder: (sheetContext) {
      final selected =
          ref.read(outputQualityProvider).valueOrNull ?? OutputQuality.highJpeg;
      final isHeicSupported = capabilities?.isHeicSupported == true;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IMAGE QUALITY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All modes keep full resolution. Rana may reduce resolution '
                'in low-memory conditions to complete a capture safely.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              for (final quality in OutputQuality.values)
                _OutputQualityOption(
                  quality: quality,
                  selected: selected == quality,
                  isEnabled:
                      quality != OutputQuality.efficientHeic || isHeicSupported,
                  unavailableMessage:
                      quality == OutputQuality.efficientHeic && !isHeicSupported
                      ? (capabilities?.unavailableMessage ??
                            'Checking device support…')
                      : null,
                  onTap: () async {
                    if (quality == OutputQuality.efficientHeic &&
                        !isHeicSupported) {
                      return;
                    }
                    await ref
                        .read(outputQualityProvider.notifier)
                        .setQuality(quality);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _OutputQualityOption extends StatelessWidget {
  const _OutputQualityOption({
    required this.quality,
    required this.selected,
    required this.isEnabled,
    required this.unavailableMessage,
    required this.onTap,
  });

  final OutputQuality quality;
  final bool selected;
  final bool isEnabled;
  final String? unavailableMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: isEnabled,
    onTap: isEnabled ? onTap : null,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_off,
      color: selected
          ? const Color(0xFFF39C12)
          : isEnabled
          ? Colors.white54
          : Colors.white24,
    ),
    title: Text(
      quality.label,
      style: TextStyle(color: isEnabled ? Colors.white : Colors.white38),
    ),
    subtitle: Text(
      unavailableMessage ?? quality.detail,
      style: TextStyle(color: isEnabled ? Colors.white54 : Colors.white30),
    ),
  );
}
