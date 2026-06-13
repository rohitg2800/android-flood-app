// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EquinoxApp(),
      ),
    );
    // Just verify the widget tree builds without crashing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
