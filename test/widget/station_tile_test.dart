// test/widget/station_tile_test.dart
// OpsFlood — Module 10: Widget tests — Live station tile

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Stub model & widget
// ---------------------------------------------------------------------------

class StubStation {
  final String id;
  final String name;
  final String river;
  final double level;
  final double dangerLevel;
  final bool isLive;
  const StubStation({
    required this.id,
    required this.name,
    required this.river,
    required this.level,
    required this.dangerLevel,
    this.isLive = true,
  });
}

class StationTile extends StatelessWidget {
  final StubStation station;
  final VoidCallback? onTap;
  const StationTile({super.key, required this.station, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = station.level / station.dangerLevel;
    final overDanger = pct >= 1.0;
    return ListTile(
      key: ValueKey('station_tile_${station.id}'),
      title: Text(station.name, key: const Key('station_tile_name')),
      subtitle: Text('${station.river} • ${station.level.toStringAsFixed(2)} m',
          key: const Key('station_tile_subtitle')),
      trailing: Container(
        key: const Key('station_tile_badge'),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: overDanger ? const Color(0xFFFF1744) : const Color(0xFF4CAF50),
        ),
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StationTile widget', () {
    Widget buildTile(StubStation s, {VoidCallback? onTap}) => ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StationTile(station: s, onTap: onTap),
            ),
          ),
        );

    const normal = StubStation(
      id: 'GG001',
      name: 'Gandhi Ghat',
      river: 'Ganga',
      level: 48.5,
      dangerLevel: 55.0,
    );

    const overDanger = StubStation(
      id: 'HB001',
      name: 'Harding Bridge',
      river: 'Ganga',
      level: 62.0,
      dangerLevel: 58.0,
    );

    testWidgets('renders station name', (tester) async {
      await tester.pumpWidget(buildTile(normal));
      expect(find.text('Gandhi Ghat'), findsOneWidget);
    });

    testWidgets('subtitle shows river and level', (tester) async {
      await tester.pumpWidget(buildTile(normal));
      expect(find.text('Ganga • 48.50 m'), findsOneWidget);
    });

    testWidgets('badge is green when below danger', (tester) async {
      await tester.pumpWidget(buildTile(normal));
      final badge =
          tester.widget<Container>(find.byKey(const Key('station_tile_badge')));
      final dec = badge.decoration as BoxDecoration;
      expect(dec.color, const Color(0xFF4CAF50));
    });

    testWidgets('badge is red when over danger level', (tester) async {
      await tester.pumpWidget(buildTile(overDanger));
      final badge =
          tester.widget<Container>(find.byKey(const Key('station_tile_badge')));
      final dec = badge.decoration as BoxDecoration;
      expect(dec.color, const Color(0xFFFF1744));
    });

    testWidgets('onTap fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTile(normal, onTap: () => tapped = true));
      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    testWidgets('has correct ValueKey', (tester) async {
      await tester.pumpWidget(buildTile(normal));
      expect(
        find.byKey(const ValueKey('station_tile_GG001')),
        findsOneWidget,
      );
    });
  });
}
