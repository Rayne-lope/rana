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
  });
}
