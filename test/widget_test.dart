// This is a basic Flutter widget test for the Network Info app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:network_info_app/main.dart';

void main() {
  testWidgets('Network Info App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app title is displayed.
    expect(find.text('Network Information'), findsOneWidget);

    // Verify that the loading state is shown initially.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for the network info to load (simulate async operations).
    await tester.pumpAndSettle();

    // Verify that network info cards are displayed.
    expect(find.text('Connection Status'), findsOneWidget);
    expect(find.text('Public IP Address'), findsOneWidget);
    expect(find.text('Local IP Address'), findsOneWidget);
    expect(find.text('WiFi SSID'), findsOneWidget);
    expect(find.text('WiFi BSSID'), findsOneWidget);

    // Verify that the refresh button is present.
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    // Test refresh functionality.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    // Verify that loading indicator appears briefly during refresh.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Network Info Cards are displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that all info cards are present.
    expect(find.byType(Card),
        findsNWidgets(5)); // 5 cards for different network info
    expect(find.byType(ListTile), findsNWidgets(5));

    // Verify that the auto-refresh indicator is shown.
    expect(find.text('Auto-refresh every 10 seconds'), findsOneWidget);
    expect(find.byIcon(Icons.autorenew), findsOneWidget);
  });

  testWidgets('Pull to refresh works', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Find the RefreshIndicator and simulate pull-to-refresh.
    await tester.fling(
        find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
    await tester.pump();

    // Verify that refresh indicator is shown.
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
  });
}
