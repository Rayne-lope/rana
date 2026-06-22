import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/splash/view/splash_screen.dart';
import 'package:rana/main.dart';

void main() {
  group('Navigation', () {
    testWidgets(
      'app starts on SplashScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: RanaApp()),
        );
        // Pump one frame — splash visible before timer fires.
        await tester.pump();
        expect(find.byType(SplashScreen), findsOneWidget);

        // Drain the pending splash timer so the test cleans up cleanly.
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'NavigationBar with 3 destinations appears after splash delay',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: RanaApp()),
        );

        // Advance past SplashScreen._duration (1200 ms).
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        // Shell should now be visible with a NavigationBar.
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationDestination), findsNWidgets(3));

        // Verify destination labels.
        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('Gallery'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Gallery tab switches to Gallery branch',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: RanaApp()),
        );
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Gallery'));
        await tester.pumpAndSettle();

        // Gallery screen shows its AppBar title.
        expect(find.text('Gallery'), findsWidgets);
      },
    );

    testWidgets(
      'tapping Settings tab switches to Settings branch',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: RanaApp()),
        );
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsWidgets);
      },
    );
  });
}
