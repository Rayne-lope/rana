import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/core/services/media_store_service.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';

/// Reads durable native capture records for one Film Roll.
typedef ContactSheetCaptureLoader =
    Future<List<FilmRollCaptureRecord>> Function(String filmRollId);

/// Reads one display-sized image for the contact-sheet canvas.
typedef ContactSheetImageBytesLoader =
    Future<Uint8List> Function(String uri, {required int targetSize});

/// Hands the rendered PNG to the platform bridge, which shares a JPEG.
typedef ContactSheetShareCallback = Future<void> Function(Uint8List pngBytes);

/// Starts a complete Film Roll export for a locked recipe.
typedef ContactSheetExportRunner =
    Future<ContactSheetExportResult> Function({
      required FilmRoll roll,
      required String presetName,
    });

/// Terminal state of one Film Roll contact-sheet export request.
enum ContactSheetExportStatus {
  shared,
  noExportableFrames,
  renderFailed,
  shareFailed,
}

/// Typed outcome for a contact-sheet export attempt.
///
/// [historicalFrameCount] always reflects the durable Film Roll exposure
/// counter. [exportedFrameCount] counts only frames that were readable and
/// rendered into the shared sheet, so UI can explain partial exports without
/// treating deleted MediaStore images as newly shot exposures.
@immutable
class ContactSheetExportResult {
  const ContactSheetExportResult._({
    required this.status,
    required this.message,
    required this.exportedFrameCount,
    required this.historicalFrameCount,
    required this.skippedFrameCount,
    this.width,
    this.height,
    this.error,
  });

  /// A sheet was handed to Android's share flow.
  const ContactSheetExportResult.shared({
    required int exportedFrameCount,
    required int historicalFrameCount,
    required int skippedFrameCount,
    required int width,
    required int height,
  }) : this._(
         status: ContactSheetExportStatus.shared,
         message: 'Contact sheet ready to share.',
         exportedFrameCount: exportedFrameCount,
         historicalFrameCount: historicalFrameCount,
         skippedFrameCount: skippedFrameCount,
         width: width,
         height: height,
       );

  /// No readable saved frame exists for this roll.
  const ContactSheetExportResult.noExportableFrames({
    required int historicalFrameCount,
    required int skippedFrameCount,
  }) : this._(
         status: ContactSheetExportStatus.noExportableFrames,
         message: 'No saved Film Roll frames are available to export.',
         exportedFrameCount: 0,
         historicalFrameCount: historicalFrameCount,
         skippedFrameCount: skippedFrameCount,
       );

  /// Capture lookup or Flutter PNG rendering could not finish.
  const ContactSheetExportResult.renderFailed({
    required int exportedFrameCount,
    required int historicalFrameCount,
    required int skippedFrameCount,
    Object? error,
  }) : this._(
         status: ContactSheetExportStatus.renderFailed,
         message: 'Could not prepare the Film Roll contact sheet. Try again.',
         exportedFrameCount: exportedFrameCount,
         historicalFrameCount: historicalFrameCount,
         skippedFrameCount: skippedFrameCount,
         error: error,
       );

  /// Flutter rendered the PNG, but Android's JPEG share flow could not open.
  const ContactSheetExportResult.shareFailed({
    required int exportedFrameCount,
    required int historicalFrameCount,
    required int skippedFrameCount,
    Object? error,
  }) : this._(
         status: ContactSheetExportStatus.shareFailed,
         message: 'Could not share the Film Roll contact sheet. Try again.',
         exportedFrameCount: exportedFrameCount,
         historicalFrameCount: historicalFrameCount,
         skippedFrameCount: skippedFrameCount,
         error: error,
       );

  final ContactSheetExportStatus status;
  final String? message;
  final int exportedFrameCount;
  final int historicalFrameCount;
  final int skippedFrameCount;
  final int? width;
  final int? height;
  final Object? error;

  bool get succeeded => status == ContactSheetExportStatus.shared;
  bool get isPartial => exportedFrameCount < historicalFrameCount;
}

/// Text values rendered into a Film Roll contact-sheet header.
///
/// Native capture timestamps win when available. A saved roll can outlive its
/// individual MediaStore frames, so its own start/completion timestamps and
/// locked preset ID provide a deterministic fallback for recovery paths.
@immutable
class ContactSheetHeaderMetadata {
  const ContactSheetHeaderMetadata._({
    required this.presetName,
    required this.dateRangeLabel,
    required this.takenLabel,
    required this.availableLabel,
  });

  factory ContactSheetHeaderMetadata.fromRoll({
    required FilmRoll roll,
    required String presetName,
    required int availableFrameCount,
    DateTime? firstCaptureAt,
    DateTime? lastCaptureAt,
  }) {
    final first = firstCaptureAt ?? roll.startedAt;
    final last = lastCaptureAt ?? roll.completedAt ?? first;
    final available = availableFrameCount.clamp(0, roll.size.count);
    return ContactSheetHeaderMetadata._(
      presetName: presetName.trim().isEmpty ? roll.presetId : presetName,
      dateRangeLabel: _dateRangeLabel(first, last),
      takenLabel: '${roll.exposuresTaken}/${roll.size.count} TAKEN',
      availableLabel: '$available/${roll.size.count} AVAILABLE',
    );
  }

  final String presetName;
  final String dateRangeLabel;
  final String takenLabel;
  final String availableLabel;
}

/// Geometry for a bounded three-column Film Roll contact sheet.
///
/// The design begins at [preferredWidth] so small and medium rolls remain
/// legible, then scales the whole page down when a long roll would exceed
/// [maxLongEdge]. Keeping every dimension on the same scale preserves the
/// contact-sheet composition and prevents oversized engine textures.
@immutable
class ContactSheetLayout {
  const ContactSheetLayout._({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.columns,
    required this.rows,
    required this.scale,
    required this.pagePadding,
    required this.headerHeight,
    required this.gutter,
    required this.tileWidth,
    required this.tileHeight,
  });

  /// Calculates the page for [frameCount] using the roll's locked ratio.
  factory ContactSheetLayout.forFrameCount({
    required int frameCount,
    required String aspectRatioPlatformValue,
  }) {
    final safeFrameCount = frameCount < 1 ? 1 : frameCount;
    final rows = (safeFrameCount + columnCount - 1) ~/ columnCount;
    final aspectRatio = _aspectRatioFor(aspectRatioPlatformValue);
    const baseTileWidth =
        (preferredWidth - (_basePagePadding * 2) - (_baseGutter * 2)) /
        columnCount;
    final baseTileHeight = baseTileWidth / aspectRatio;
    final baseHeight =
        _baseHeaderHeight +
        _basePagePadding +
        (baseTileHeight * rows) +
        (_baseGutter * (rows - 1));
    final longestEdge = baseHeight > preferredWidth
        ? baseHeight
        : preferredWidth.toDouble();
    final scale = longestEdge > maxLongEdge ? maxLongEdge / longestEdge : 1.0;

    return ContactSheetLayout._(
      canvasWidth: (preferredWidth * scale).round().clamp(1, maxLongEdge),
      canvasHeight: (baseHeight * scale).round().clamp(1, maxLongEdge),
      columns: columnCount,
      rows: rows,
      scale: scale,
      pagePadding: _basePagePadding * scale,
      headerHeight: _baseHeaderHeight * scale,
      gutter: _baseGutter * scale,
      tileWidth: baseTileWidth * scale,
      tileHeight: baseTileHeight * scale,
    );
  }

  static const int columnCount = 3;
  static const int preferredWidth = 1440;
  static const int maxLongEdge = 4096;

  static const double _basePagePadding = 48;
  static const double _baseHeaderHeight = 216;
  static const double _baseGutter = 18;

  final int canvasWidth;
  final int canvasHeight;
  final int columns;
  final int rows;
  final double scale;
  final double pagePadding;
  final double headerHeight;
  final double gutter;
  final double tileWidth;
  final double tileHeight;

  /// A stable native decode target that preserves quality even if a later
  /// frame turns out to be unavailable and the packed grid has fewer rows.
  static int preferredDecodeTarget(String aspectRatioPlatformValue) {
    final aspectRatio = _aspectRatioFor(aspectRatioPlatformValue);
    const tileWidth =
        (preferredWidth - (_basePagePadding * 2) - (_baseGutter * 2)) /
        columnCount;
    final tileHeight = tileWidth / aspectRatio;
    final longest = tileWidth > tileHeight ? tileWidth : tileHeight;
    return longest.round().clamp(64, 1024);
  }

  /// Returns the destination rectangle for the packed frame at [index].
  ui.Rect tileRectAt(int index) {
    final row = index ~/ columns;
    final column = index % columns;
    final left = pagePadding + (column * (tileWidth + gutter));
    final top = headerHeight + (row * (tileHeight + gutter));
    return ui.Rect.fromLTWH(left, top, tileWidth, tileHeight);
  }

  static double _aspectRatioFor(String platformValue) =>
      switch (platformValue) {
        'square_1_1' => 1,
        'portrait_9_16' => 9 / 16,
        _ => 3 / 4,
      };
}

/// Composes and shares a bounded three-column Film Roll contact sheet.
///
/// Dependencies are injectable so exporter tests can exercise chronology,
/// unavailable frames, and platform failures without a MethodChannel. The
/// default path uses durable Android Film Roll records, then the existing
/// target-sized capture-byte API, and finally [MediaStoreService].
class ContactSheetExporter {
  ContactSheetExporter({
    ContactSheetCaptureLoader? loadCaptures,
    ContactSheetImageBytesLoader? loadImageBytes,
    ContactSheetShareCallback? shareContactSheet,
  }) : _loadCaptures = loadCaptures ?? _loadCapturesFromPlatform,
       _loadImageBytes = loadImageBytes ?? _loadImageBytesFromPlatform,
       _shareContactSheet = shareContactSheet ?? _shareWithMediaStore;

  final ContactSheetCaptureLoader _loadCaptures;
  final ContactSheetImageBytesLoader _loadImageBytes;
  final ContactSheetShareCallback _shareContactSheet;

  /// Builds a contact sheet for [roll] and opens the native share surface.
  ///
  /// Capture records are sorted by durable native timestamp and URI. Each URI
  /// is read and decoded one at a time; bad reads/bytes are omitted rather
  /// than creating a fake frame or failing a healthy partial archive.
  Future<ContactSheetExportResult> exportRoll({
    required FilmRoll roll,
    required String presetName,
  }) async {
    final historicalFrameCount = roll.exposuresTaken;
    late final List<FilmRollCaptureRecord> captureRecords;
    try {
      captureRecords = await _loadChronologicalCaptures(roll.id);
    } on Object catch (error) {
      return ContactSheetExportResult.renderFailed(
        exportedFrameCount: 0,
        historicalFrameCount: historicalFrameCount,
        skippedFrameCount: historicalFrameCount,
        error: error,
      );
    }

    final targetSize = ContactSheetLayout.preferredDecodeTarget(
      roll.aspectRatioPlatformValue,
    );
    final frames = <_ContactSheetFrame>[];
    for (
      var captureIndex = 0;
      captureIndex < captureRecords.length;
      captureIndex += 1
    ) {
      final capture = captureRecords[captureIndex];
      try {
        final bytes = await _loadImageBytes(
          capture.mediaUri,
          targetSize: targetSize,
        );
        final image = bytes.isEmpty ? null : await _decodeFrame(bytes);
        if (image == null) {
          continue;
        }
        frames.add(
          _ContactSheetFrame(
            capturedAt: capture.capturedAt,
            image: image,
            frameNumber: captureIndex + 1,
          ),
        );
      } on Object catch (_) {
        // Individual MediaStore frames may be deleted, permission-limited, or
        // corrupt. A contact sheet is still valuable when the remaining
        // archive is healthy, so omit just this entry.
      }
    }

    final skippedFrameCount = _skippedFrameCount(
      historicalFrameCount: historicalFrameCount,
      exportedFrameCount: frames.length,
    );
    if (frames.isEmpty) {
      return ContactSheetExportResult.noExportableFrames(
        historicalFrameCount: historicalFrameCount,
        skippedFrameCount: skippedFrameCount,
      );
    }

    late final _ContactSheetComposition composition;
    try {
      composition = await _compose(
        roll: roll,
        presetName: presetName,
        frames: frames,
      );
    } on Object catch (error) {
      return ContactSheetExportResult.renderFailed(
        exportedFrameCount: 0,
        historicalFrameCount: historicalFrameCount,
        skippedFrameCount: historicalFrameCount,
        error: error,
      );
    } finally {
      for (final frame in frames) {
        frame.image.dispose();
      }
    }
    if (composition.renderedFrameCount == 0) {
      return ContactSheetExportResult.noExportableFrames(
        historicalFrameCount: historicalFrameCount,
        skippedFrameCount: historicalFrameCount,
      );
    }

    try {
      await _shareContactSheet(composition.pngBytes);
    } on Object catch (error) {
      return ContactSheetExportResult.shareFailed(
        exportedFrameCount: composition.renderedFrameCount,
        historicalFrameCount: historicalFrameCount,
        skippedFrameCount: _skippedFrameCount(
          historicalFrameCount: historicalFrameCount,
          exportedFrameCount: composition.renderedFrameCount,
        ),
        error: error,
      );
    }

    return ContactSheetExportResult.shared(
      exportedFrameCount: composition.renderedFrameCount,
      historicalFrameCount: historicalFrameCount,
      skippedFrameCount: _skippedFrameCount(
        historicalFrameCount: historicalFrameCount,
        exportedFrameCount: composition.renderedFrameCount,
      ),
      width: composition.layout.canvasWidth,
      height: composition.layout.canvasHeight,
    );
  }

  Future<List<FilmRollCaptureRecord>> _loadChronologicalCaptures(
    String filmRollId,
  ) async {
    final captures = await _loadCaptures(filmRollId);
    final seenUris = <String>{};
    final ordered =
        captures
            .where((capture) => capture.mediaUri.isNotEmpty)
            .toList(growable: false)
          ..sort((a, b) {
            final date = a.capturedAt.compareTo(b.capturedAt);
            return date != 0 ? date : a.mediaUri.compareTo(b.mediaUri);
          });
    return [
      for (final capture in ordered)
        if (seenUris.add(capture.mediaUri)) capture,
    ];
  }

  static int _skippedFrameCount({
    required int historicalFrameCount,
    required int exportedFrameCount,
  }) {
    final difference = historicalFrameCount - exportedFrameCount;
    return difference > 0 ? difference : 0;
  }

  static Future<List<FilmRollCaptureRecord>> _loadCapturesFromPlatform(
    String filmRollId,
  ) => CameraPlatformService().listFilmRollCaptures(filmRollId);

  static Future<Uint8List> _loadImageBytesFromPlatform(
    String uri, {
    required int targetSize,
  }) => CameraPlatformService().loadCapturedImageBytes(
    uri,
    targetSize: targetSize,
  );

  static Future<void> _shareWithMediaStore(Uint8List pngBytes) =>
      MediaStoreService().shareContactSheet(pngBytes);
}

/// Default export runner for Camera UI.
///
/// Keeping the expensive renderer behind a provider lets CameraScreen tests
/// exercise lifecycle wiring without depending on a real raster backend or a
/// system share surface. Production retains the concrete exporter.
final contactSheetExportRunnerProvider = Provider<ContactSheetExportRunner>(
  (ref) => ContactSheetExporter().exportRoll,
);

@immutable
class _ContactSheetFrame {
  const _ContactSheetFrame({
    required this.capturedAt,
    required this.image,
    required this.frameNumber,
  });

  final DateTime capturedAt;
  final ui.Image image;
  final int frameNumber;
}

@immutable
class _ContactSheetComposition {
  const _ContactSheetComposition({
    required this.pngBytes,
    required this.layout,
    required this.renderedFrameCount,
  });

  final Uint8List pngBytes;
  final ContactSheetLayout layout;
  final int renderedFrameCount;
}

Future<ui.Image?> _decodeFrame(Uint8List bytes) async {
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    if (image.width > 0 && image.height > 0) return image;
    image.dispose();
    return null;
  } on Object catch (_) {
    return null;
  } finally {
    codec?.dispose();
  }
}

Future<_ContactSheetComposition> _compose({
  required FilmRoll roll,
  required String presetName,
  required List<_ContactSheetFrame> frames,
}) async {
  final layout = ContactSheetLayout.forFrameCount(
    frameCount: frames.length,
    aspectRatioPlatformValue: roll.aspectRatioPlatformValue,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  _drawPaperMatte(canvas, layout);
  for (var index = 0; index < frames.length; index += 1) {
    final frame = frames[index];
    _drawFrame(
      canvas,
      image: frame.image,
      destination: layout.tileRectAt(index),
      frameNumber: frame.frameNumber,
      scale: layout.scale,
    );
  }
  if (frames.isNotEmpty) {
    _drawHeader(
      canvas,
      layout: layout,
      roll: roll,
      presetName: presetName,
      firstCaptureAt: frames.first.capturedAt,
      lastCaptureAt: frames.last.capturedAt,
      availableFrameCount: frames.length,
    );
  }

  final picture = recorder.endRecording();
  ui.Image? sheet;
  try {
    sheet = await picture.toImage(layout.canvasWidth, layout.canvasHeight);
    final data = await sheet.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('The contact sheet could not be encoded.');
    }
    return _ContactSheetComposition(
      pngBytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      layout: layout,
      renderedFrameCount: frames.length,
    );
  } finally {
    sheet?.dispose();
    picture.dispose();
  }
}

void _drawPaperMatte(ui.Canvas canvas, ContactSheetLayout layout) {
  canvas.drawRect(
    ui.Rect.fromLTWH(
      0,
      0,
      layout.canvasWidth.toDouble(),
      layout.canvasHeight.toDouble(),
    ),
    ui.Paint()..color = const ui.Color(0xFFF0E8D8),
  );
}

void _drawHeader(
  ui.Canvas canvas, {
  required ContactSheetLayout layout,
  required FilmRoll roll,
  required String presetName,
  required DateTime firstCaptureAt,
  required DateTime lastCaptureAt,
  required int availableFrameCount,
}) {
  final metadata = ContactSheetHeaderMetadata.fromRoll(
    roll: roll,
    presetName: presetName,
    availableFrameCount: availableFrameCount,
    firstCaptureAt: firstCaptureAt,
    lastCaptureAt: lastCaptureAt,
  );
  final scale = layout.scale;
  final left = layout.pagePadding;
  final maxWidth = layout.canvasWidth - (left * 2);
  _paintText(
    canvas,
    text: 'RANA // CONTACT SHEET',
    offset: ui.Offset(left, 44 * scale),
    style: TextStyle(
      color: const ui.Color(0xFF191713),
      fontFamily: 'monospace',
      fontWeight: FontWeight.w900,
      fontSize: 36 * scale,
      letterSpacing: 1.5 * scale,
    ),
    maxWidth: maxWidth,
  );
  _paintText(
    canvas,
    text: metadata.presetName.toUpperCase(),
    offset: ui.Offset(left, 100 * scale),
    style: TextStyle(
      color: const ui.Color(0xFF8E4A13),
      fontFamily: 'monospace',
      fontWeight: FontWeight.w800,
      fontSize: 24 * scale,
      letterSpacing: 1.2 * scale,
    ),
    maxWidth: maxWidth,
  );
  _paintText(
    canvas,
    text:
        '${metadata.dateRangeLabel}  ${metadata.takenLabel}  '
        '${metadata.availableLabel}',
    offset: ui.Offset(left, 144 * scale),
    style: TextStyle(
      color: const ui.Color(0xFF4E4940),
      fontFamily: 'monospace',
      fontWeight: FontWeight.w700,
      fontSize: 16 * scale,
      letterSpacing: 0.45 * scale,
    ),
    maxWidth: maxWidth,
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(
      left,
      182 * scale,
      layout.canvasWidth - (left * 2),
      2 * scale,
    ),
    ui.Paint()..color = const ui.Color(0xFFB5651D),
  );
}

void _drawFrame(
  ui.Canvas canvas, {
  required ui.Image image,
  required ui.Rect destination,
  required int frameNumber,
  required double scale,
}) {
  canvas.drawRect(destination, ui.Paint()..color = const ui.Color(0xFF25211C));
  final source = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  canvas.drawImageRect(
    image,
    source,
    _containRect(source, destination),
    ui.Paint(),
  );

  _paintText(
    canvas,
    text: '#${frameNumber.toString().padLeft(2, '0')}',
    offset: ui.Offset(
      destination.left + (10 * scale),
      destination.top + (10 * scale),
    ),
    style: TextStyle(
      color: const ui.Color(0xFFF0E8D8),
      fontFamily: 'monospace',
      fontWeight: FontWeight.w900,
      fontSize: 13 * scale,
      shadows: const <Shadow>[
        Shadow(color: ui.Color(0x99000000), blurRadius: 2),
      ],
    ),
    maxWidth: destination.width - (20 * scale),
  );
}

ui.Rect _containRect(ui.Rect source, ui.Rect destination) {
  final sourceAspect = source.width / source.height;
  final destinationAspect = destination.width / destination.height;
  if (sourceAspect > destinationAspect) {
    final height = destination.width / sourceAspect;
    return ui.Rect.fromLTWH(
      destination.left,
      destination.center.dy - (height / 2),
      destination.width,
      height,
    );
  }
  final width = destination.height * sourceAspect;
  return ui.Rect.fromLTWH(
    destination.center.dx - (width / 2),
    destination.top,
    width,
    destination.height,
  );
}

void _paintText(
  ui.Canvas canvas, {
  required String text,
  required ui.Offset offset,
  required TextStyle style,
  double? maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  painter.paint(canvas, offset);
}

String _dateRangeLabel(DateTime start, DateTime end) {
  final first = _dateLabel(start);
  final last = _dateLabel(end);
  return first == last ? first : '$first TO $last';
}

String _dateLabel(DateTime value) {
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
