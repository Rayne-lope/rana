/// Typed path constants for every asset directory and known placeholder files.
///
/// Always use these constants when referencing assets — never hard-code
/// strings.
///
/// ```dart
/// final data = await rootBundle.loadString(AssetConstants.placeholderPreset);
/// ```
abstract final class AssetConstants {
  // ── Directories ────────────────────────────────────────────────────────────

  /// Root directory for film preset configs (LUT paths, shader params, etc.).
  static const String presetsDir = 'assets/presets/';

  /// Root directory for overlay PNG textures (light leaks, dust, scratches).
  static const String overlaysDir = 'assets/overlays/';

  /// Root directory for stamp fonts (vintage date stamp TTF/OTF files).
  static const String stampsDir = 'assets/stamps/';

  /// Root directory for app icons and decorative icons.
  static const String iconsDir = 'assets/icons/';

  // ── Known files ────────────────────────────────────────────────────────────

  /// Placeholder preset JSON — schema template for Phase 3 real presets.
  static const String placeholderPreset = 'assets/presets/placeholder.json';
}
