import 'dart:math' as math;

import 'package:rana/features/render/model/render_recipe.dart';

final class ParityFixture {
  ParityFixture._(this.width, this.height, this.rgb, this.cropMarkers);

  factory ParityFixture.colorPatches({int width = 24, int height = 18}) {
    const patches = <List<double>>[
      [0.9, 0.1, 0.1],
      [0.1, 0.8, 0.2],
      [0.1, 0.2, 0.9],
      [0.9, 0.8, 0.1],
      [0.7, 0.2, 0.8],
      [0.1, 0.8, 0.8],
      [0.18, 0.18, 0.18],
      [0.5, 0.5, 0.5],
      [0.85, 0.85, 0.85],
    ];
    final pixels = List<double>.filled(width * height * 3, 0);
    final markers = <int>{};
    for (var y = 0; y < height; y += 1) {
      for (var x = 0; x < width; x += 1) {
        final patchX = (x * 3 ~/ width).clamp(0, 2);
        final patchY = (y * 3 ~/ height).clamp(0, 2);
        final color = patches[patchY * 3 + patchX];
        final pixel = y * width + x;
        final offset = pixel * 3;
        pixels.setRange(offset, offset + 3, color);
        final isMarker =
            (x < 2 || x >= width - 2) && (y < 2 || y >= height - 2);
        if (isMarker) {
          markers.add(pixel);
          pixels.setRange(offset, offset + 3, const [1.0, 0.0, 1.0]);
        }
      }
    }
    return ParityFixture._(width, height, pixels, markers);
  }

  final int width;
  final int height;
  final List<double> rgb;
  final Set<int> cropMarkers;
}

final class ParityImage {
  const ParityImage(this.width, this.height, this.rgb, this.cropMarkers);

  final int width;
  final int height;
  final List<double> rgb;
  final Set<int> cropMarkers;
}

ParityImage renderParityReference(
  ParityFixture fixture,
  Map<String, dynamic> wireRecipe,
) {
  final recipe = RenderRecipeV1.fromMap(wireRecipe);
  final result = List<double>.filled(fixture.rgb.length, 0);
  final matrix = recipe.colorMatrix;
  final saturation = (1 + recipe.saturation + recipe.color / 100).clamp(
    0.0,
    2.0,
  );
  final contrast = (1 + recipe.contrast + recipe.tone / 200).clamp(0.0, 2.0);
  final strength = recipe.styleStrength / 100;
  for (var offset = 0; offset < fixture.rgb.length; offset += 3) {
    final inputR = fixture.rgb[offset];
    final inputG = fixture.rgb[offset + 1];
    final inputB = fixture.rgb[offset + 2];
    var r = matrix[0] * inputR + matrix[1] * inputG + matrix[2] * inputB;
    var g = matrix[3] * inputR + matrix[4] * inputG + matrix[5] * inputB;
    var b = matrix[6] * inputR + matrix[7] * inputG + matrix[8] * inputB;
    final luminance = r * 0.2126 + g * 0.7152 + b * 0.0722;
    r = luminance + (r - luminance) * saturation;
    g = luminance + (g - luminance) * saturation;
    b = luminance + (b - luminance) * saturation;
    r += (recipe.temperature * 0.05 + recipe.undertoneX * 0.03) * strength;
    g += recipe.undertoneY * 0.02 * strength;
    b -= recipe.temperature * 0.05 * strength;
    result[offset] = ((r - 0.5) * contrast + 0.5).clamp(0.0, 1.0);
    result[offset + 1] = ((g - 0.5) * contrast + 0.5).clamp(0.0, 1.0);
    result[offset + 2] = ((b - 0.5) * contrast + 0.5).clamp(0.0, 1.0);
  }
  return ParityImage(
    fixture.width,
    fixture.height,
    result,
    Set<int>.unmodifiable(fixture.cropMarkers),
  );
}

double meanAbsoluteError(ParityImage a, ParityImage b) {
  if (a.rgb.length != b.rgb.length) return double.infinity;
  var error = 0.0;
  for (var index = 0; index < a.rgb.length; index += 1) {
    error += (a.rgb[index] - b.rgb[index]).abs();
  }
  return error / a.rgb.length;
}

double structuralSimilarity(ParityImage a, ParityImage b) {
  if (a.rgb.length != b.rgb.length || a.rgb.isEmpty) return 0;
  final luminanceA = <double>[];
  final luminanceB = <double>[];
  for (var offset = 0; offset < a.rgb.length; offset += 3) {
    luminanceA.add(
      a.rgb[offset] * 0.2126 +
          a.rgb[offset + 1] * 0.7152 +
          a.rgb[offset + 2] * 0.0722,
    );
    luminanceB.add(
      b.rgb[offset] * 0.2126 +
          b.rgb[offset + 1] * 0.7152 +
          b.rgb[offset + 2] * 0.0722,
    );
  }
  final meanA =
      luminanceA.reduce((left, right) => left + right) / luminanceA.length;
  final meanB =
      luminanceB.reduce((left, right) => left + right) / luminanceB.length;
  var varianceA = 0.0;
  var varianceB = 0.0;
  var covariance = 0.0;
  for (var index = 0; index < luminanceA.length; index += 1) {
    final deltaA = luminanceA[index] - meanA;
    final deltaB = luminanceB[index] - meanB;
    varianceA += deltaA * deltaA;
    varianceB += deltaB * deltaB;
    covariance += deltaA * deltaB;
  }
  final divisor = math.max(1, luminanceA.length - 1);
  varianceA /= divisor;
  varianceB /= divisor;
  covariance /= divisor;
  const c1 = 0.0001;
  const c2 = 0.0009;
  return ((2 * meanA * meanB + c1) * (2 * covariance + c2)) /
      ((meanA * meanA + meanB * meanB + c1) * (varianceA + varianceB + c2));
}

int cropMarkerAlignmentError(ParityImage a, ParityImage b) {
  if (a.width != b.width || a.height != b.height) return 1 << 20;
  if (a.cropMarkers.length != b.cropMarkers.length) return 1 << 20;
  var maximum = 0;
  final first = a.cropMarkers.toList()..sort();
  final second = b.cropMarkers.toList()..sort();
  for (var index = 0; index < first.length; index += 1) {
    final ax = first[index] % a.width;
    final ay = first[index] ~/ a.width;
    final bx = second[index] % b.width;
    final by = second[index] ~/ b.width;
    maximum = math.max(maximum, math.max((ax - bx).abs(), (ay - by).abs()));
  }
  return maximum;
}
