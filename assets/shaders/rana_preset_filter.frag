#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uTexture;
uniform vec2 uUndertone; // x: warmth (-1.0 to 1.0), y: tint (-1.0 to 1.0)
uniform float uExposure;   // -1.0 to 1.0
uniform float uContrast;   // 0.5 to 1.5
uniform float uSaturation; // 0.0 to 2.0

out vec4 fragColor;

void main() {
    vec2 st = FlutterFragCoord().xy / uSize;
    vec4 color = texture(uTexture, st);

    if (color.a == 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec3 rgb = color.rgb;

    // 1. Exposure adjustment
    rgb *= pow(2.0, uExposure);

    // 2. Undertone / Color Temperature & Tint shift
    // uUndertone.x -> Warmth (red/blue shift)
    // uUndertone.y -> Tint (magenta/green shift)
    rgb.r += uUndertone.x * 0.15;
    rgb.b -= uUndertone.x * 0.15;
    rgb.g += uUndertone.y * 0.15;

    // 3. Contrast adjustment
    rgb = (rgb - 0.5) * uContrast + 0.5;

    // 4. Saturation adjustment
    float luminance = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    rgb = mix(vec3(luminance), rgb, uSaturation);

    // Clamp output
    rgb = clamp(rgb, 0.0, 1.0);

    fragColor = vec4(rgb, color.a);
}
