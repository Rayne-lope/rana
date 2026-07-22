import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/render/model/render_recipe.dart';

void main() {
  test('legacy v0 recipe migrates to v1 with bounded editable values', () {
    final recipe = RenderRecipeV1.fromMap(const <String, dynamic>{
      'tone': 140,
      'textureVal': -5,
      'undertoneX': 4,
      'presetId': 'portra',
    });

    expect(recipe.tone, 100);
    expect(recipe.texture, 0);
    expect(recipe.undertoneX, 1);
    expect(recipe.presetId, 'portra');
    expect(recipe.toMap()['recipeVersion'], currentRenderRecipeVersion);
  });

  test('recipe round trips without losing wire parameters', () {
    const recipe = RenderRecipeV1(
      temperature: 0.2,
      colorMatrix: <double>[1, 0.1, 0, 0, 1, 0, 0, 0.2, 1],
      lightLeakVariant: 2,
      aspectRatio: 'square_1_1',
      outputQuality: 'heic',
      presetId: 'test',
    );

    expect(RenderRecipeV1.fromMap(recipe.toMap()), recipe);
  });

  test('unknown version produces a structured non-destructive error', () {
    expect(
      () =>
          RenderRecipeV1.fromMap(const <String, dynamic>{'recipeVersion': 99}),
      throwsA(
        isA<UnsupportedRenderRecipeVersion>()
            .having((error) => error.code, 'code', 'UNSUPPORTED_RECIPE_VERSION')
            .having((error) => error.version, 'version', 99),
      ),
    );
  });
}
