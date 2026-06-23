import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';

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
}
