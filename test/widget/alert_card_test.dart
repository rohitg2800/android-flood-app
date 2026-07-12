// test/widget/alert_card_test.dart
// OpsFlood — Module 10: Widget tests — Alert severity card

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Minimal stub models (avoids importing the full app graph)
// ---------------------------------------------------------------------------

enum AlertSeverity { info, warning, danger, emergency }

class StubAlert {
  final String station;
  final AlertSeverity severity;
  final double level;
  final double threshold;
  const StubAlert({
    required this.station,
    required this.severity,
    required this.level,
    required this.threshold,
  });
}

// ---------------------------------------------------------------------------
// Minimal stub widget (mirrors real AlertCard API surface)
// ---------------------------------------------------------------------------

class AlertCard extends StatelessWidget {
  final StubAlert alert;
  const AlertCard({super.key, required this.alert});

  static const _colors = {
    AlertSeverity.info: Color(0xFF4FC3F7),
    AlertSeverity.warning: Color(0xFFFFB300),
    AlertSeverity.danger: Color(0xFFFF6D00),
    AlertSeverity.emergency: Color(0xFFFF1744),
  };

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('alert_card_${alert.station}'),
        color: _colors[alert.severity],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                alert.station,
                key: const Key('alert_station_name'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${alert.level.toStringAsFixed(2)} m',
                key: const Key('alert_level'),
              ),
              Text(
                alert.severity.name.toUpperCase(),
                key: const Key('alert_severity_label'),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AlertCard widget', () {
    Widget buildCard(StubAlert alert) => ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AlertCard(alert: alert),
            ),
          ),
        );

    testWidgets('renders station name', (tester) async {
      await tester.pumpWidget(buildCard(const StubAlert(
        station: 'Gandhi Ghat',
        severity: AlertSeverity.warning,
        level: 52.3,
        threshold: 50.0,
      )));

      expect(find.text('Gandhi Ghat'), findsOneWidget);
    });

    testWidgets('renders level in metres', (tester) async {
      await tester.pumpWidget(buildCard(const StubAlert(
        station: 'Harding Bridge',
        severity: AlertSeverity.danger,
        level: 61.45,
        threshold: 58.0,
      )));

      expect(find.text('61.45 m'), findsOneWidget);
    });

    testWidgets('emergency card uses red background', (tester) async {
      await tester.pumpWidget(buildCard(const StubAlert(
        station: 'Bagmati Sonepur',
        severity: AlertSeverity.emergency,
        level: 44.1,
        threshold: 40.0,
      )));

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, const Color(0xFFFF1744));
    });

    testWidgets('severity label is uppercased', (tester) async {
      await tester.pumpWidget(buildCard(const StubAlert(
        station: 'Kosi Barrage',
        severity: AlertSeverity.info,
        level: 12.5,
        threshold: 15.0,
      )));

      expect(find.text('INFO'), findsOneWidget);
    });

    testWidgets('card has correct ValueKey', (tester) async {
      const station = 'Gopalganj';
      await tester.pumpWidget(buildCard(const StubAlert(
        station: station,
        severity: AlertSeverity.warning,
        level: 28.9,
        threshold: 27.0,
      )));

      expect(
        find.byKey(const ValueKey('alert_card_Gopalganj')),
        findsOneWidget,
      );
    });
  });
}
