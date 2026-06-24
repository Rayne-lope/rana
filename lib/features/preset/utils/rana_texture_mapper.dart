/// Helper mapper to map style texture value (0-100)
/// to actual film rendering parameters.
class RanaTextureMapper {
  /// Maps texture value (0-100) to mapped grain intensity,
  /// grain size, dust intensity, and softness.
  static Map<String, double> mapTexture(
    double texture, {
    double presetGrain = 0.0,
    double presetDust = 0.0,
  }) {
    if (texture <= 0.0) {
      return {
        'grain': presetGrain,
        'dust': presetDust,
        'grainSize': 1.0,
        'softness': 0.0,
      };
    }

    final grain = texture / 100.0;
    final dust = (texture / 100.0) * 0.2;
    final grainSize = 0.5 + (texture / 100.0) * 0.8;
    final softness = (texture / 100.0) * 0.3;

    return {
      'grain': grain,
      'dust': dust,
      'grainSize': grainSize,
      'softness': softness,
    };
  }
}
