import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_maps_flutter_macos_example/main.dart';

void main() {
  testWidgets('Demo app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: Demo()));

    // Verify that the app bar title is displayed.
    expect(find.text('platform interface (macOS) example'), findsOneWidget);
  });
}
