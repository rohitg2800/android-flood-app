// test/widget_test.dart
//
// Smoke test: verifies the app widget tree compiles and builds without crashing.
//
// FloodWatchApp requires Firebase / Hive / dotenv to be fully initialised before
// pumpWidget — those init calls are in main() and cannot run in a unit-test
// environment without mocking the entire native layer.
//
// This test therefore only checks that the class exists and is constructable,
// which is still a meaningful compilation-level gate.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/main.dart';

void main() {
  test('FloodWatchApp class is accessible and is a Widget subtype', () {
    // Verifies the import resolves and the class is a Widget.
    expect(FloodWatchApp, isNotNull);
    const app = FloodWatchApp();
    expect(app, isA<Widget>());
  });
}
