import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/widgets/contact_sheet_export.dart';
import 'package:rana/features/gallery/controller/gallery_controller.dart';
import 'package:rana/features/gallery/model/gallery_film_roll.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
import 'package:rana/features/gallery/view/gallery_detail_screen.dart';
import 'package:rana/features/gallery/widgets/styled_image_view.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Chronological Gallery view for the captures belonging to one Film Roll.
class RollDetailScreen extends ConsumerStatefulWidget {
  const RollDetailScreen({
    required this.rollId,
    this.onExportContactSheet,
    super.key,
  });

  final String rollId;

  /// Builds and opens the share sheet for this archived roll's saved frames.
  ///
  /// The optional callback keeps this route testable while production uses the
  /// default [ContactSheetExporter] path.
  final Future<ContactSheetExportResult> Function({
    required FilmRoll roll,
    required String presetName,
  })?
  onExportContactSheet;

  @override
  ConsumerState<RollDetailScreen> createState() => _RollDetailScreenState();
}

class _RollDetailScreenState extends ConsumerState<RollDetailScreen> {
  late final ContactSheetExporter _contactSheetExporter =
      ContactSheetExporter();
  bool _isExporting = false;
  String? _exportMessage;
  String? _exportError;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_loadRolls));
  }

  @override
  void didUpdateWidget(covariant RollDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rollId != widget.rollId) {
      _isExporting = false;
      _exportMessage = null;
      _exportError = null;
    }
  }

  Future<void> _loadRolls() =>
      ref.read(galleryControllerProvider.notifier).loadRolls();

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryControllerProvider);
    final roll = _rollForId(galleryState.rolls, widget.rollId);
    final presetName = roll == null ? null : _presetName(roll.roll.presetId);
    final canExport =
        roll != null && roll.availableItems.isNotEmpty && !_isExporting;
    final exportHint = _isExporting
        ? 'Please wait for the current export to finish'
        : roll == null
        ? 'Film Roll metadata is still loading'
        : roll.availableItems.isEmpty
        ? 'No saved Film Roll frames are available to export'
        : 'Creates a JPEG contact sheet to share';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D3037), Color(0xFF1E2025), Color(0xFF121316)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Scaffold(
        key: const ValueKey<String>('roll-detail-screen'),
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const ValueKey<String>('roll-detail-back-button'),
            tooltip: 'Back to Rolls',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text(
            'FILM ROLL',
            style: TextStyle(
              color: Color(0xFFF39C12),
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                enabled: canExport,
                label: _isExporting
                    ? 'Preparing contact sheet'
                    : 'Export contact sheet',
                hint: exportHint,
                child: IconButton(
                  key: const ValueKey<String>(
                    'roll-detail-export-contact-sheet-button',
                  ),
                  tooltip: _isExporting
                      ? 'Preparing contact sheet'
                      : canExport
                      ? 'Export contact sheet'
                      : 'No saved frames to export',
                  onPressed: canExport
                      ? () => _exportContactSheet(
                          roll: roll,
                          presetName: presetName!,
                        )
                      : null,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFF4C44F),
                            ),
                          ),
                        )
                      : const Icon(Icons.grid_view_rounded),
                ),
              ),
            ),
          ],
        ),
        body: _bodyFor(
          context: context,
          state: galleryState,
          roll: roll,
          presetName: presetName,
        ),
      ),
    );
  }

  Widget _bodyFor({
    required BuildContext context,
    required GalleryState state,
    required GalleryFilmRoll? roll,
    required String? presetName,
  }) {
    if (roll != null) {
      return _RollDetailBody(
        roll: roll,
        presetName: presetName!,
        isRefreshing: state.rollsStatus == GalleryRollLoadStatus.loading,
        onRetry: () => unawaited(_loadRolls()),
        isExporting: _isExporting,
        exportMessage: _exportMessage,
        exportError: _exportError,
      );
    }

    return switch (state.rollsStatus) {
      GalleryRollLoadStatus.initial ||
      GalleryRollLoadStatus.loading => const _RollDetailLoadingState(),
      GalleryRollLoadStatus.error => _RollDetailErrorState(
        message: state.rollsErrorMessage,
        onRetry: () => unawaited(_loadRolls()),
      ),
      GalleryRollLoadStatus.loaded ||
      GalleryRollLoadStatus.empty => _RollNotFoundState(onBack: _handleBack),
    };
  }

  Future<void> _exportContactSheet({
    required GalleryFilmRoll roll,
    required String presetName,
  }) async {
    if (_isExporting || roll.availableItems.isEmpty) return;

    setState(() {
      _isExporting = true;
      _exportMessage = null;
      _exportError = null;
    });

    try {
      final export =
          widget.onExportContactSheet ?? _contactSheetExporter.exportRoll;
      final result = await export(roll: roll.roll, presetName: presetName);
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        if (!result.succeeded) {
          _exportError =
              result.message ??
              'Could not prepare the contact sheet. Try again.';
          return;
        }
        _exportMessage =
            result.exportedFrameCount == result.historicalFrameCount
            ? 'CONTACT SHEET READY: ${result.exportedFrameCount} '
                  '${result.exportedFrameCount == 1 ? 'FRAME' : 'FRAMES'}'
            : 'CONTACT SHEET READY: ${result.exportedFrameCount} OF '
                  '${result.historicalFrameCount} FRAMES';
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportError = 'Could not prepare the contact sheet. Try again.';
      });
    }
  }

  String _presetName(String presetId) {
    final presets =
        ref.watch(presetsProvider).valueOrNull ?? const <PresetModel>[];
    for (final preset in presets) {
      if (preset.id == presetId) return preset.name;
    }
    return presetId;
  }

  void _handleBack() {
    final controller = ref.read(galleryControllerProvider.notifier);
    unawaited(controller.setViewMode(GalleryViewMode.rolls));

    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(AppRoutes.gallery);
  }

  static GalleryFilmRoll? _rollForId(
    List<GalleryFilmRoll> rolls,
    String rollId,
  ) {
    for (final roll in rolls) {
      if (roll.roll.id == rollId) return roll;
    }
    return null;
  }
}

class _RollDetailBody extends StatelessWidget {
  const _RollDetailBody({
    required this.roll,
    required this.presetName,
    required this.isRefreshing,
    required this.onRetry,
    required this.isExporting,
    required this.exportMessage,
    required this.exportError,
  });

  final GalleryFilmRoll roll;
  final String presetName;
  final bool isRefreshing;
  final VoidCallback onRetry;
  final bool isExporting;
  final String? exportMessage;
  final String? exportError;

  @override
  Widget build(BuildContext context) {
    final availableItems = roll.availableItems;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverToBoxAdapter(
            child: _RollDetailHeader(
              roll: roll,
              presetName: presetName,
              isRefreshing: isRefreshing,
            ),
          ),
        ),
        if (isExporting || exportMessage != null || exportError != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _RollContactSheetFeedback(
                isExporting: isExporting,
                message: exportError ?? exportMessage,
                isError: exportError != null,
              ),
            ),
          ),
        if (availableItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _RollNoAvailableFramesState(
              unavailableFrameCount: roll.unavailableFrameCount,
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Icon(
                    Icons.view_module_rounded,
                    color: Color(0xFFF39C12),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${availableItems.length} AVAILABLE '
                      'FRAME${availableItems.length == 1 ? '' : 'S'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey<String>('roll-detail-retry-button'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('REFRESH'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF4C44F),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.crossAxisExtent >= 520
                    ? 3
                    : 2;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _RollFrameTile(
                      key: ValueKey<String>(
                        'roll-detail-tile-${availableItems[index].id}',
                      ),
                      item: availableItems[index],
                      position: index + 1,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GalleryDetailScreen(
                            items: availableItems,
                            initialIndex: index,
                          ),
                        ),
                      ),
                    ),
                    childCount: availableItems.length,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _RollContactSheetFeedback extends StatelessWidget {
  const _RollContactSheetFeedback({
    required this.isExporting,
    required this.message,
    required this.isError,
  });

  final bool isExporting;
  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFE57373) : const Color(0xFFF4C44F);
    final text = isExporting
        ? 'PREPARING CONTACT SHEET…'
        : message ?? 'CONTACT SHEET READY';

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.42)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (isExporting)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.grid_view_rounded,
                  color: color,
                  size: 18,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  key: ValueKey<String>(
                    isError
                        ? 'roll-detail-export-error'
                        : 'roll-detail-export-status',
                  ),
                  style: TextStyle(
                    color: color,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollDetailHeader extends StatelessWidget {
  const _RollDetailHeader({
    required this.roll,
    required this.presetName,
    required this.isRefreshing,
  });

  final GalleryFilmRoll roll;
  final String presetName;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final filmRoll = roll.roll;
    final missingFrames = roll.unavailableFrameCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2F36), Color(0xFF1A1C21), Color(0xFF121316)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF39C12).withValues(alpha: 0.12),
                    border: Border.all(
                      color: const Color(0xFFF39C12).withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.photo_camera_back_outlined,
                    color: Color(0xFFF4C44F),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOCKED RECIPE',
                        style: TextStyle(
                          color: Color(0xFFF39C12),
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Semantics(
                        label: 'Locked preset $presetName',
                        child: Text(
                          presetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRefreshing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFF4C44F),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _RollMetric(
                    label: 'EXPOSURES',
                    value: '${filmRoll.exposuresTaken}/${filmRoll.size.count}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RollMetric(
                    label: 'ROLL SIZE',
                    value: '${filmRoll.size.count} FRAME',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'DATE RANGE',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dateRangeLabel(roll.dateRangeStart, roll.dateRangeEnd),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (roll.isEarlyEnded || missingFrames > 0) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (roll.isEarlyEnded) const _RollStatusBadge.earlyEnded(),
                  if (missingFrames > 0)
                    _RollStatusBadge.unavailable(frameCount: missingFrames),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _dateRangeLabel(DateTime start, DateTime end) {
    final startLabel = _dateLabel(start);
    final endLabel = _dateLabel(end);
    return startLabel == endLabel ? startLabel : '$startLabel to $endLabel';
  }

  static String _dateLabel(DateTime value) {
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${value.day.toString().padLeft(2, '0')} '
        '${months[value.month - 1]} ${value.year}';
  }
}

class _RollMetric extends StatelessWidget {
  const _RollMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.23),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RollStatusBadge extends StatelessWidget {
  const _RollStatusBadge.earlyEnded()
    : icon = Icons.stop_circle_outlined,
      text = 'ENDED EARLY',
      color = const Color(0xFFF4C44F);

  const _RollStatusBadge.unavailable({required int frameCount})
    : icon = Icons.hide_image_outlined,
      text = '$frameCount FRAME${frameCount == 1 ? '' : 'S'} UNAVAILABLE',
      color = const Color(0xFFE6A65A);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RollFrameTile extends StatefulWidget {
  const _RollFrameTile({
    required this.item,
    required this.position,
    required this.onTap,
    super.key,
  });

  final GalleryMediaItem item;
  final int position;
  final VoidCallback onTap;

  @override
  State<_RollFrameTile> createState() => _RollFrameTileState();
}

class _RollFrameTileState extends State<_RollFrameTile> {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Frame ${widget.position}, ${widget.item.displayName}',
    child: InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF16171B),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              StyledImageView(
                mediaUri: widget.item.contentUri,
                metadata: widget.item.styleMetadata,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0x99000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    child: Text(
                      widget.position.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: Color(0xFFF4C44F),
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 9,
                child: Text(
                  widget.item.captureStamp,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RollDetailLoadingState extends StatelessWidget {
  const _RollDetailLoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF39C12)),
        ),
        SizedBox(height: 16),
        Text(
          'LOADING FILM ROLL',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _RollDetailErrorState extends StatelessWidget {
  const _RollDetailErrorState({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE6A65A),
            size: 52,
          ),
          const SizedBox(height: 16),
          const Text(
            'ROLL COULD NOT LOAD',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'Check your photo access and try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey<String>('roll-detail-error-retry-button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('RETRY'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RollNotFoundState extends StatelessWidget {
  const _RollNotFoundState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_album_outlined,
            color: Color(0xFFF4C44F),
            size: 52,
          ),
          const SizedBox(height: 16),
          const Text(
            'ROLL NOT FOUND',
            key: ValueKey<String>('roll-detail-not-found'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This Film Roll may have been removed from your archive.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey<String>('roll-detail-show-rolls-button'),
            onPressed: onBack,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
            ),
            child: const Text('SHOW ROLLS'),
          ),
        ],
      ),
    ),
  );
}

class _RollNoAvailableFramesState extends StatelessWidget {
  const _RollNoAvailableFramesState({required this.unavailableFrameCount});

  final int unavailableFrameCount;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        key: const ValueKey<String>('roll-detail-empty'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hide_image_outlined,
            color: Color(0xFFE6A65A),
            size: 52,
          ),
          const SizedBox(height: 16),
          const Text(
            'NO FRAMES AVAILABLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            switch (unavailableFrameCount) {
              0 => 'No saved frame metadata is available for this roll yet.',
              1 => 'The saved frame is no longer available in Photos.',
              _ =>
                '$unavailableFrameCount saved frames are no longer '
                    'available in Photos.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
