import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/capture_style_metadata.dart';

/// Metadata for a photo entry loaded from Android MediaStore.
@immutable
class GalleryMediaItem {
  const GalleryMediaItem({
    required this.id,
    required this.contentUri,
    required this.displayName,
    required this.dateTaken,
    required this.width,
    required this.height,
    required this.mimeType,
    required this.sizeBytes,
    required this.relativePath,
    this.styleMetadata,
  });

  factory GalleryMediaItem.fromMap(Map<String, dynamic> json) {
    final timestamp =
        (json['dateTaken'] as num?)?.toInt() ??
        (json['dateAdded'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;

    return GalleryMediaItem(
      id:
          json['id']?.toString() ??
          json['contentUri']?.toString() ??
          timestamp.toString(),
      contentUri: json['contentUri']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Rana photo',
      dateTaken: DateTime.fromMillisecondsSinceEpoch(timestamp),
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType']?.toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      relativePath: json['relativePath']?.toString(),
    );
  }

  final String id;
  final String contentUri;
  final String displayName;
  final DateTime dateTaken;
  final int width;
  final int height;
  final String? mimeType;
  final int? sizeBytes;
  final String? relativePath;
  final CaptureStyleMetadata? styleMetadata;

  GalleryMediaItem copyWith({
    CaptureStyleMetadata? styleMetadata,
  }) {
    return GalleryMediaItem(
      id: id,
      contentUri: contentUri,
      displayName: displayName,
      dateTaken: dateTaken,
      width: width,
      height: height,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      relativePath: relativePath,
      styleMetadata: styleMetadata ?? this.styleMetadata,
    );
  }

  String get captureStamp {
    final day = dateTaken.day.toString().padLeft(2, '0');
    final month = dateTaken.month.toString().padLeft(2, '0');
    final year = dateTaken.year.toString().substring(2);
    return '$day $month $year';
  }

  String get dimensionsLabel {
    if (width <= 0 || height <= 0) {
      return 'UNKNOWN SIZE';
    }
    return '${width}x$height';
  }
}
