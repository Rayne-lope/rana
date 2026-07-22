import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/render/model/render_recipe.dart';
import 'package:rana/src/features/camera/controller/camera_recipe_builder.dart';

import 'support/render_parity_harness.dart';

void main() {
  test('preview capture and gallery satisfy P0 pixel parity thresholds', () {
    const recipe = RenderRecipeV1(
      temperature: 0.24,
      saturation: 0.16,
      contrast: 0.12,
      colorMatrix: [1.02, -0.01, 0, 0.01, 0.99, 0, 0, 0.02, 0.98],
      tone: 18,
      color: 12,
      styleStrength: 78,
      undertoneX: 0.22,
      undertoneY: -0.08,
      presetId: 'parity_fixture',
    );
    const builder = CameraRecipeBuilder();
    final fixture = ParityFixture.colorPatches();
    final preview = renderParityReference(
      fixture,
      builder.previewParamsFor(recipe),
    );
    final capture = renderParityReference(
      fixture,
      builder.captureParamsFor(recipe),
    );
    final gallery = renderParityReference(fixture, recipe.toMap());

    for (final comparison in [capture, gallery]) {
      expect(
        structuralSimilarity(preview, comparison),
        greaterThanOrEqualTo(0.98),
      );
      expect(
        meanAbsoluteError(preview, comparison),
        lessThanOrEqualTo(2 / 255),
      );
      expect(
        cropMarkerAlignmentError(preview, comparison),
        lessThanOrEqualTo(1),
      );
    }
  });
}
