// lib/screens/evacuation_routes_screen.dart
// OpsFlood — Module 12: Flood Evacuation Routes
//
// Features:
//  • District picker (38 Bihar districts)
//  • List of official evacuation routes per district
//  • Nearest shelters with capacity + distance
//  • “Get Directions” — launches maps_launcher / url_launcher
//  • “Share Route” — share_plus
//  • Offline-friendly (static route data bundled in code)
//  • Emergency contacts strip at bottom

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class EvacShelter {
  final String name;
  final String address;
  final int    capacity;
  final double lat;
  final double lng;
  final String distanceKm;
  const EvacShelter({
    required this.name,
    required this.address,
    required this.capacity,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });
}

class EvacRoute {
  final String routeId;
  final String name;
  final String from;
  final String to;
  final String distanceKm;
  final String etaMin;
  final String description;
  final String roadType;      // NH, SH, district road
  final bool   currentlyOpen;
  final List<EvacShelter> shelters;
  const EvacRoute({
    required this.routeId,
    required this.name,
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.etaMin,
    required this.description,
    required this.roadType,
    required this.currentlyOpen,
    required this.shelters,
  });
}

class EvacDistrict {
  final String name;
  final List<EvacRoute> routes;
  const EvacDistrict({required this.name, required this.routes});
}

// ---------------------------------------------------------------------------
// Static route data (38 Bihar districts — 3 districts shown as sample;
// extend list for all 38)
// ---------------------------------------------------------------------------

const _districts = [
  EvacDistrict(name: 'Patna', routes: [
    EvacRoute(
      routeId: 'PNR1',
      name:    'Gandhi Ghat → Patna Sahib Relief Camp',
      from: 'Gandhi Ghat, Patna', to: 'Patna Sahib Ground',
      distanceKm: '8.4', etaMin: '22',
      description: 'Take NH-30 east, avoid embankment road after km 4.',
      roadType: 'NH-30', currentlyOpen: true,
      shelters: [
        EvacShelter(name: 'Patna Sahib School', address: 'Patna Sahib, Patna 800008',
            capacity: 1200, lat: 25.627, lng: 85.220, distanceKm: '8.4'),
        EvacShelter(name: 'Rajendra Nagar Ground', address: 'Rajendra Nagar, Patna',
            capacity: 800,  lat: 25.604, lng: 85.107, distanceKm: '5.1'),
      ],
    ),
    EvacRoute(
      routeId: 'PNR2',
      name:    'Digha → NIT Patna Shelter',
      from: 'Digha Ghat, Patna', to: 'NIT Patna Campus',
      distanceKm: '6.1', etaMin: '18',
      description: 'Use Ashok Rajpath. Avoid river road completely.',
      roadType: 'Ashok Rajpath', currentlyOpen: true,
      shelters: [
        EvacShelter(name: 'NIT Patna', address: 'Ashok Rajpath, Patna',
            capacity: 2000, lat: 25.627, lng: 85.153, distanceKm: '6.1'),
      ],
    ),
  ]),
  EvacDistrict(name: 'Darbhanga', routes: [
    EvacRoute(
      routeId: 'DBR1',
      name:    'Baheri → Darbhanga Town Relief',
      from: 'Baheri Block HQ', to: 'Darbhanga Stadium',
      distanceKm: '22.0', etaMin: '45',
      description: 'SH-52 north towards Darbhanga. Bridge at km 14 may be submerged — use diversion via Jale.',
      roadType: 'SH-52', currentlyOpen: false,
      shelters: [
        EvacShelter(name: 'Darbhanga Stadium', address: 'Station Rd, Darbhanga',
            capacity: 3000, lat: 26.152, lng: 85.896, distanceKm: '22.0'),
        EvacShelter(name: 'LN Mithila Univ', address: 'Kameshwarnagar, Darbhanga',
            capacity: 1500, lat: 26.166, lng: 85.904, distanceKm: '24.1'),
      ],
    ),
  ]),
  EvacDistrict(name: 'Muzaffarpur', routes: [
    EvacRoute(
      routeId: 'MZR1',
      name:    'Katra → Muzaffarpur Town',
      from: 'Katra Ghat', to: 'Tirhut Academy Ground',
      distanceKm: '12.5', etaMin: '30',
      description: 'Use NH-28 bypass. Do NOT use Katra river road — submerged.',
      roadType: 'NH-28', currentlyOpen: true,
      shelters: [
        EvacShelter(name: 'Tirhut Academy', address: 'Court Compound, Muzaffarpur',
            capacity: 2500, lat: 26.120, lng: 85.364, distanceKm: '12.5'),
      ],
    ),
  ]),
  EvacDistrict(name: 'Bhagalpur', routes: [
    EvacRoute(
      routeId: 'BGR1',
      name:    'Nathnagar → Bhagalpur Collectorate',
      from: 'Nathnagar Ghat', to: 'Bhagalpur Collectorate',
      distanceKm: '9.3', etaMin: '25',
      description: 'Take Sultanganj Road (NH-80) inland away from Ganga.',
      roadType: 'NH-80', currentlyOpen: true,
      shelters: [
        EvacShelter(name: 'BNMU Campus', address: 'T.M. Bhagalpur Univ, Bhagalpur',
            capacity: 1800, lat: 25.255, lng: 86.989, distanceKm: '9.3'),
      ],
    ),
  ]),
  EvacDistrict(name: 'Supaul', routes: [
    EvacRoute(
      routeId: 'SPR1',
      name:    'Birpur → Supaul HQ',
      from: 'Birpur Block', to: 'Supaul Collectorate',
      distanceKm: '18.0', etaMin: '40',
      description: 'Kosi Embankment Road East. Stay on high embankment; do not descend.',
      roadType: 'Embankment Road', currentlyOpen: true,
      shelters: [
        EvacShelter(name: 'Supaul Collectorate Ground', address: 'Civil Lines, Supaul',
            capacity: 2200, lat: 26.123, lng: 86.607, distanceKm: '18.0'),
      ],
    ),
  ]),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class EvacuationRoutesScreen extends ConsumerStatefulWidget {
  static const String route = '/evacuation';
  const EvacuationRoutesScreen({super.key});

  @override
  ConsumerState<EvacuationRoutesScreen> createState() =>
      _EvacuationRoutesScreenState();
}

class _EvacuationRoutesScreenState
    extends ConsumerState<EvacuationRoutesScreen> {
  int _districtIdx = 0;

  EvacDistrict get _district => _districts[_districtIdx];

  Future<void> _openMaps(EvacShelter s) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareRoute(EvacRoute r) async {
    final msg =
        '🚨 Evacuation Route: ${r.name}\n'
        '📍 From: ${r.from}\n'
        '🎯 To:   ${r.to}\n'
        '🛣️ Road: ${r.roadType}\n'
        '📍 Distance: ${r.distanceKm} km  |⏱ ETA: ${r.etaMin} min\n'
        'ℹ️ ${r.description}\n\n'
        'Shelters:\n'
        '${r.shelters.map((s) => "  • ${s.name} (capacity: ${s.capacity})").join("\n")}\n\n'
        'Shared via OpsFlood Bihar Flood Monitor';
    await Share.share(msg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚫 Evacuation Routes'),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ─ Offline notice
          Container(
            width: double.infinity,
            color: const Color(0xFF1B5E20),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt,
                    size: 14, color: Colors.greenAccent),
                SizedBox(width: 6),
                Text(
                  'Route data available offline',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12),
                ),
              ],
            ),
          ),

          // ─ District picker
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              itemCount: _districts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final sel = i == _districtIdx;
                return ChoiceChip(
                  label: Text(_districts[i].name),
                  selected: sel,
                  onSelected: (_) =>
                      setState(() => _districtIdx = i),
                );
              },
            ),
          ),

          // ─ Route list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _district.routes.length,
              itemBuilder: (ctx, i) =>
                  _RouteCard(
                    route:     _district.routes[i],
                    onOpenMaps: _openMaps,
                    onShare:    _shareRoute,
                  ),
            ),
          ),

          // ─ Emergency strip
          _EmergencyStrip(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route Card
// ---------------------------------------------------------------------------

class _RouteCard extends StatelessWidget {
  final EvacRoute route;
  final Future<void> Function(EvacShelter) onOpenMaps;
  final Future<void> Function(EvacRoute)   onShare;
  const _RouteCard({
    required this.route,
    required this.onOpenMaps,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final open  = route.currentlyOpen;
    final color = open
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF1744);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(route.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withOpacity(.15),
                      borderRadius:
                          BorderRadius.circular(20)),
                  child: Text(
                    open ? '✅ Open' : '❌ Closed',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Route details
            _infoRow(Icons.location_on,       'From: ${route.from}'),
            _infoRow(Icons.flag,              'To:   ${route.to}'),
            _infoRow(Icons.route,             '${route.distanceKm} km  •  ${route.etaMin} min ETA'),
            _infoRow(Icons.directions_car,    route.roadType),
            _infoRow(Icons.info_outline,      route.description),

            const Divider(height: 20),

            // Shelters
            Text('Shelters (${route.shelters.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
            const SizedBox(height: 6),
            ...route.shelters.map((s) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                      Icons.home_work_outlined,
                      size: 18,
                      color: Color(0xFF1565C0)),
                  title: Text(s.name,
                      style:
                          const TextStyle(fontSize: 12)),
                  subtitle: Text(
                      '${s.address}  •  Cap: ${s.capacity}  •  ${s.distanceKm} km',
                      style:
                          const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.directions,
                        size: 20,
                        color: Color(0xFF1565C0)),
                    tooltip: 'Get Directions',
                    onPressed: () => onOpenMaps(s),
                  ),
                )),

            // Action buttons
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon:  const Icon(Icons.share, size: 16),
                  label: const Text('Share Route'),
                  onPressed: () => onShare(route),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14,
                color: const Color(0xFF78909C)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Emergency Strip
// ---------------------------------------------------------------------------

class _EmergencyStrip extends StatelessWidget {
  final _contacts = const [
    ('🚮 Police',    'tel:100'),
    ('🚑 Ambulance', 'tel:108'),
    ('🟡 NDRF',     'tel:1078'),
    ('🔴 SDRF',     'tel:0612-2294000'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A237E),
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _contacts
            .map((c) => InkWell(
                  onTap: () async {
                    final uri = Uri.parse(c.$2);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.$1,
                          style: const TextStyle(
                              color:    Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
