import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/features/debug/provider/consistency_debug_provider.dart';

class ConsistencyDebugScreen extends ConsumerStatefulWidget {
  const ConsistencyDebugScreen({super.key});

  @override
  ConsumerState<ConsistencyDebugScreen> createState() =>
      _ConsistencyDebugScreenState();
}

class _ConsistencyDebugScreenState
    extends ConsumerState<ConsistencyDebugScreen> {
  static const _channel = MethodChannel('com.rana.app/camera_control');
  bool _isTestingOffline = false;
  String? _testResultPath;
  String? _testError;

  Future<void> _runOfflinePipelineTest(Map<String, dynamic> params) async {
    setState(() {
      _isTestingOffline = true;
      _testResultPath = null;
      _testError = null;
    });

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'testOfflineProcessing',
        params,
      );
      setState(() {
        _testResultPath = result?['filePath'] as String?;
      });
    } on PlatformException catch (e) {
      setState(() {
        _testError = e.message;
      });
    } finally {
      setState(() {
        _isTestingOffline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final glState = ref.watch(consistencyDebugProvider);
    final preview = glState.lastPreviewParams;
    final export = glState.lastExportParams;

    final allKeys = {
      'temperature',
      'saturation',
      'contrast',
      'grain',
      'vignette',
      'lutPath',
      'lutStrength',
    };

    var hasMismatch = false;
    if (preview != null && export != null) {
      for (final key in allKeys) {
        if (preview[key] != export[key]) {
          hasMismatch = true;
          break;
        }
      }
    }

    final isConsistent = preview != null && export != null && !hasMismatch;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        foregroundColor: Colors.white,
        title: const Text(
          'GL Shader Consistency',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            if (preview == null && export == null)
              _buildCard(
                color: Colors.white.withValues(alpha: 0.05),
                child: const Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white54, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'No rendering parameters recorded yet.\n'
                      'Interact with the camera preview or capture an '
                      'image to populate parameters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, height: 1.4),
                    ),
                  ],
                ),
              )
            else if (hasMismatch)
              _buildCard(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.15),
                borderColor: const Color(0xFFE74C3C),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE74C3C),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DIVERGENCE DETECTED',
                            style: TextStyle(
                              color: Color(0xFFE74C3C),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preview parameters differ from Export parameters. '
                            'This will cause visual inconsistency.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (isConsistent)
              _buildCard(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                borderColor: const Color(0xFF2ECC71),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF2ECC71),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PIPELINES CONSISTENT',
                            style: TextStyle(
                              color: Color(0xFF2ECC71),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preview and export parameters match perfectly. '
                            'Shader operations are unified.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Comparison Details Table
            const Text(
              'PARAMETER COMPARISON',
              style: TextStyle(
                color: Color(0xFFF39C12),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildCard(
              padding: EdgeInsets.zero,
              color: const Color(0xFF16161A),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FixedColumnWidth(48),
                  },
                  border: TableBorder.symmetric(
                    inside: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  children: [
                    // Header
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                      ),
                      children: [
                        _buildCell('Parameter', isHeader: true),
                        _buildCell('[PREVIEW]', isHeader: true),
                        _buildCell('[EXPORT]', isHeader: true),
                        _buildCell(
                          'Match',
                          isHeader: true,
                          align: Alignment.center,
                        ),
                      ],
                    ),
                    // Rows
                    for (final key in allKeys)
                      _buildComparisonRow(
                        key,
                        preview?[key],
                        export?[key],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Offline processing simulation
            const Text(
              'TEST PIPELINE EXECUTION',
              style: TextStyle(
                color: Color(0xFFF39C12),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildCard(
              color: const Color(0xFF16161A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Execute Offline Shader test with current preview '
                    'parameters using the native rendering pipeline.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: preview == null || _isTestingOffline
                        ? null
                        : () => _runOfflinePipelineTest(preview),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF39C12),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white30,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isTestingOffline
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : const Text('Run Native Offline Shader Test'),
                  ),
                  if (_testResultPath != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        'Test Success! Output saved at:\n$_testResultPath',
                        style: const TextStyle(
                          color: Color(0xFF2ECC71),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  if (_testError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Test Failed: $_testError',
                        style: const TextStyle(
                          color: Color(0xFFE74C3C),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Log Verification Guide
            const Text(
              'LOGCAT MANUAL VERIFICATION GUIDE',
              style: TextStyle(
                color: Color(0xFFF39C12),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildCard(
              color: Colors.white.withValues(alpha: 0.02),
              borderColor: Colors.white.withValues(alpha: 0.05),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To verify parameter logs in real-time, run the '
                    'following command in terminal or Android Studio Logcat:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12),
                  SelectableText(
                    'adb logcat -s GlParams:D Logger:D',
                    style: TextStyle(
                      color: Color(0xFFF39C12),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Verify that the printed [PREVIEW] logs during camera '
                    'adjustments match the [EXPORT] logs printed immediately '
                    'after hitting the capture button.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    Color? color,
    Color? borderColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: borderColor != null
              ? Border.all(color: borderColor)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );

  TableRow _buildComparisonRow(
    String key,
    Object? previewVal,
    Object? exportVal,
  ) {
    final matches = previewVal == exportVal;
    final displayPreview = previewVal != null ? _formatValue(previewVal) : '-';
    final displayExport = exportVal != null ? _formatValue(exportVal) : '-';

    return TableRow(
      children: [
        _buildCell(key, isCode: true),
        _buildCell(
          displayPreview,
          color: previewVal == null ? Colors.white30 : null,
        ),
        _buildCell(
          displayExport,
          color: exportVal == null ? Colors.white30 : null,
        ),
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            matches ? Icons.check_rounded : Icons.close_rounded,
            color: matches ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
            size: 18,
          ),
        ),
      ],
    );
  }

  String _formatValue(Object val) {
    if (val is double) {
      return val.toStringAsFixed(2);
    }
    return val.toString();
  }

  Widget _buildCell(
    String text, {
    bool isHeader = false,
    bool isCode = false,
    Color? color,
    Alignment align = Alignment.centerLeft,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: align,
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: TextStyle(
            color: color ?? (isHeader ? Colors.white54 : Colors.white),
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            fontSize: isHeader ? 11 : (isCode ? 12 : 13),
            fontFamily: isCode ? 'monospace' : null,
          ),
        ),
      );
}
