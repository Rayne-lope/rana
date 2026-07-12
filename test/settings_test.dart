import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('gridLinesProvider toggles grid lines correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial value is true (on)
    expect(container.read(gridLinesProvider), true);

    // Toggle it
    container.read(gridLinesProvider.notifier).update((state) => !state);
    expect(container.read(gridLinesProvider), false);

    // Toggle it again
    container.read(gridLinesProvider.notifier).update((state) => !state);
    expect(container.read(gridLinesProvider), true);
  });

  test('output quality defaults to high JPEG for existing installs', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(outputQualityProvider.future),
      OutputQuality.highJpeg,
    );
  });

  test('output quality ignores invalid persisted values', () async {
    SharedPreferences.setMockInitialValues({
      'rana.output_quality.v1': 'unknown_format',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(outputQualityProvider.future),
      OutputQuality.highJpeg,
    );
  });

  test('output quality persists the selected HEIC preference', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(outputQualityProvider.future);
    await container
        .read(outputQualityProvider.notifier)
        .setQuality(OutputQuality.efficientHeic);

    expect(
      container.read(outputQualityProvider).valueOrNull,
      OutputQuality.efficientHeic,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('rana.output_quality.v1'), 'efficient_heic');
  });

  test('output capabilities exposes device unavailability reason', () {
    const capabilities = OutputCapabilities(
      isHeicSupported: false,
      unavailableReason: 'android_version',
    );

    expect(capabilities.unavailableMessage, 'Requires Android 9 or later');
  });
}
