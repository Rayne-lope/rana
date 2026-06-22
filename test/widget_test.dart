import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/main.dart';

void main() {
  testWidgets('RanaApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: RanaApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);

    // Drain the pending splash timer so the test framework is happy.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });
}
