# Preset-Aware Mood Styling

## Research Summary

Apple's current Photographic Styles are a better reference for Rana than old
flat filters. Apple describes them as local color/highlight/shadow adjustments,
with skin-undertone awareness, live preview, later editing, and reversible
behavior. Apple Support also separates selecting a style from fine-tuning tone,
color, and intensity.

Sources:
- https://support.apple.com/guide/iphone/use-photographic-styles-iph629d2cd37/ios
- https://support.apple.com/guide/iphone/edit-photos-and-videos-iphb08064d57/26/ios/26
- https://www.apple.com/newsroom/2024/09/apple-introduces-iphone-16-and-iphone-16-plus/
- https://www.macrumors.com/guide/iphone-16-photographic-styles/

Important takeaways for Rana:
- The first-level choice should be a style or mood, not raw sliders.
- Tone, Color, and Palette remain useful fine-tuning controls after the user
  chooses a mood.
- Undertone is only color-bias direction. It should not carry brightness,
  saturation, and intensity by itself.
- Skin protection should keep warm/cool/rose shifts subtler on skin-like pixels.
- Preview and export should keep using the same shader parameter path.

## Local Implementation Read

Relevant current files:
- `lib/features/camera/controller/camera_controller.dart`
- `lib/features/camera/view/camera_screen.dart`
- `lib/features/camera/widgets/rana_styles_controls.dart`
- `lib/features/preset/model/rana_style.dart`
- `lib/features/preset/model/preset_model.dart`
- `android/app/src/main/kotlin/com/rana/app/rana/GlShaderConstants.kt`
- `assets/presets/*.json`

Current Rana already has the right pipeline shape:
- Selecting a preset seeds `CameraState.activeStyle` from `PresetModel.style`.
- `updateActiveStyle` sends the active preset plus style params to native
  preview.
- Capture/export reads the same `activeStyle` params.
- The shader applies preset/LUT first, then Rana style controls, then final
  effects.
- `Palette` is already `RanaStyle.styleStrength`.

## Design Decision

Use preset-aware deltas for quick Mood chips.

Why deltas:
- Absolute values would make Kodak Gold, Portra, Ektar, and Rana Cool converge
  toward the same generic look.
- Preset-specific override tables would be more accurate but too heavy for the
  first pass.
- Deltas preserve the selected film preset identity while giving the user a
  quick aesthetic direction.

The first pass keeps `RanaStyle` unchanged. A mood is a local config that
resolves to a normal `RanaStyle`:
- `toneDelta`
- `colorDelta` or `colorTarget`
- `undertoneXDelta` or `undertoneXTarget`
- `undertoneYDelta` or `undertoneYTarget`
- `styleStrength`, defaulting to 100

Texture stays in the model for compatibility, but Mood chips preserve the base
style texture and do not expose Texture as a primary control.

## First-Pass Mood Taxonomy

Color presets show:
- Standard
- Cool Rose
- Neutral
- Rose Gold
- Gold
- Amber
- Vibrant
- Natural
- Luminous
- Dramatic
- Quiet
- Cozy
- Ethereal
- Muted B&W
- Stark B&W

Monochrome presets show only:
- Standard
- Muted B&W
- Stark B&W

This avoids odd warm/cool color casts on Tri-X, HP5, and Rana Mono unless the
user chooses a B&W-specific mood.

## UX Flow

1. User picks a film preset, for example Kodak Gold.
2. Rana seeds Styling from the preset's own default `RanaStyle`.
3. User opens Styling and sees Mood chips above the fine-tuning controls.
4. Tapping Cool Rose applies a delta to the Kodak default, so the image becomes
   cooler/rose while staying Kodak-based.
5. User can still fine-tune Tone, Color, Palette, and Undertone afterward.
6. Reset restores the selected preset default style, not the last mood.

Manual fine-tuning after a Mood chip should clear the exact active-chip match;
the style remains a plain `RanaStyle`.

## QA Notes

Required checks:
- Kodak Gold + Gold feels warmer/golder while preserving Kodak base params.
- Kodak Gold + Cool Rose gets cooler/rose, not generic blue.
- Portra + Cozy/Ethereal stays subtle and subject-friendly.
- Rana Cool + Cool Rose can become visibly cooler because the base is already
  cool.
- Tri-X/HP5/Rana Mono only show B&W-safe moods.
- Lowering Palette after a mood reduces the style through `styleStrength`.
- Preview and export use identical tone/color/palette/undertone params.
