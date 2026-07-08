import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Preset thumbnail widget showing a default camera icon.
class PresetThumbnailWidget extends StatelessWidget {
  /// Main constructor.
  const PresetThumbnailWidget({
    required this.preset,
    this.size = 14.0,
    super.key,
  });

  /// The preset model recipe.
  final PresetModel preset;

  /// The size of the icon.
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.photo_camera_outlined,
        size: size,
        color: Colors.white60,
      );
}
