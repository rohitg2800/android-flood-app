// lib/screens/evacuation_routes_screen.dart
// OpsFlood — Evacuation Routes Screen (Phase 6 full implementation)
//
// FIX (14 Jun 2026): route constant changed '/evacuation-routes' → '/evacuation'
// to match Routes.evacuation in app_router.dart and main.dart onGenerateRoute.
// The old value caused main.dart's onGenerateRoute to fall through to
// default: SplashScreen(), making the app appear to restart.
library;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/evacuation_routes_data.dart';
import '../theme/river_theme.dart';
import '../app_router.dart'; // Routes.evacuation

class EvacuationRoutesScreen extends StatefulWidget {
  // ── FIXED: was '/evacuation-routes', now matches Routes.evacuation ──
  static const String route = Routes.evacuation; // '/evacuation'
  const EvacuationRoutesScreen({super.key});

  @override
  State<EvacuationRoutesScreen> createState() => _EvacuationRoutesScreenState();
}

class _EvacuationRoutesScreenState extends State<EvacuationRoutesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDistrict = 'All';
  String _riskFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DistrictEvacuationInfo> get _filtered {
    var list = EvacuationRoutesData.districts;
    if (_riskFilter != 'All') {
      list = list.where((d) => d.floodRisk == _riskFilter).toList();
    }
    if (_selectedDistrict != 'All') {
      list = list.where((d) => d.district == _selectedDistrict).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        title: Row(
          children: [
            Icon(Icons.directions_run, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Text('Evacuation Routes'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk),
            tooltip: 'Emergency: 112',
            onPressed: () => _callNumber('112'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: t.textPrimary,
          unselectedLabelColor: t.textSecondary,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(icon: Icon(Icons.route), text: 'Routes'),
            Tab(icon: Icon(Icons.location_city), text: 'Shelters'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(t),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRoutesTab(t),
                _buildSheltersTab(t),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.emergency),
        label: const Text('Call 112'),
        onPressed: () => _callNumber('112'),
      ),
    );
  }

  Widget _buildFilterBar(RiverColors t) {
    final districts = ['All', ...EvacuationRoutesData.districtNames];
    const risks = ['All', 'HIGH', 'MEDIUM', 'LOW'];
    return Container(
      color: t.navBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedDistrict,
              dropdownColor: t.navBg,
              style: TextStyle(color: t.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'District',
                labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: t.textSecondary.withValues(alpha: 0.3)),
                ),
                border: const OutlineInputBorder(),
              ),
              items: districts
                  .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDistrict = v ?? 'All'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _riskFilter,
              dropdownColor: t.navBg,
              style: TextStyle(color: t.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Risk Level',
                labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: t.textSecondary.withValues(alpha: 0.3)),
                ),
                border: const OutlineInputBorder(),
              ),
              items: risks
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r, style: TextStyle(color: _riskColor(r)))))
                  .toList(),
              onChanged: (v) => setState(() => _riskFilter = v ?? 'All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesTab(RiverColors t) {
    final districts = _filtered;
    if (districts.isEmpty) {
      return Center(
        child: Text('No routes match filters.',
            style: TextStyle(color: t.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: districts.length,
      itemBuilder: (ctx, i) {
        final d = districts[i];
        return _DistrictRoutesCard(district: d, theme: t);
      },
    );
  }

  Widget _buildSheltersTab(RiverColors t) {
    final districts = _filtered;
    if (districts.isEmpty) {
      return Center(
        child: Text('No shelters match filters.',
            style: TextStyle(color: t.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: districts.length,
      itemBuilder: (ctx, i) {
        final d = districts[i];
        return _DistrictSheltersCard(district: d, theme: t);
      },
    );
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// District Routes Card
// ─────────────────────────────────────────────────────────────
class _DistrictRoutesCard extends StatelessWidget {
  final DistrictEvacuationInfo district;
  final RiverColors theme;
  const _DistrictRoutesCard({
    required this.district,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Card(
      color: t.cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _RiskBadge(risk: district.floodRisk),
        title: Text(
          district.district,
          style: TextStyle(
              color: t.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${district.division} Division · ${district.routes.length} route(s)',
          style: TextStyle(color: t.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.call, color: Colors.green, size: 20),
              tooltip: 'Control Room',
              onPressed: () => _call(district.controlRoomPhone),
            ),
          ],
        ),
        children: district.routes
            .map((r) => _RouteDetailTile(route: r, theme: t))
            .toList(),
      ),
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ─────────────────────────────────────────────────────────────
// Route Detail Tile
// ─────────────────────────────────────────────────────────────
class _RouteDetailTile extends StatelessWidget {
  final EvacuationRoute route;
  final RiverColors theme;
  const _RouteDetailTile({required this.route, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: route.isFloodProne
              ? Colors.red.withValues(alpha: 0.4)
              : Colors.green.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                route.isFloodProne ? Icons.warning_amber : Icons.check_circle,
                color: route.isFloodProne ? Colors.orange : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${route.from} → ${route.to}',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.straighten, color: t.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text('${route.distanceKm} km',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              Icon(Icons.signpost, color: t.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(route.highway,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            route.description,
            style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.4),
          ),
          if (route.waypoints.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: route.waypoints
                  .map((wp) => Chip(
                        label: Text(wp,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white)),
                        backgroundColor: Colors.blueGrey.shade700,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 0),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.map_outlined, size: 14),
                label: const Text('Open Map', style: TextStyle(fontSize: 12)),
                onPressed: () => _openMap(),
              ),
              TextButton.icon(
                icon: const Icon(Icons.share, size: 14),
                label: const Text('Share', style: TextStyle(fontSize: 12)),
                onPressed: () => _share(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMap() async {
    final query = Uri.encodeComponent('${route.from}, Bihar India');
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share() async {
    final text = '🚨 Evacuation Route [${route.id}]\n'
        'From: ${route.from}\n'
        'To: ${route.to}\n'
        'Via: ${route.highway} (${route.distanceKm} km)\n\n'
        '${route.description}\n\n'
        'Waypoints: ${route.waypoints.join(' → ')}\n\n'
        'OpsFlood Flood Alert App';
    await Share.share(text, subject: 'OpsFlood Evacuation Route ${route.id}');
  }
}

// ─────────────────────────────────────────────────────────────
// District Shelters Card
// ─────────────────────────────────────────────────────────────
class _DistrictSheltersCard extends StatelessWidget {
  final DistrictEvacuationInfo district;
  final RiverColors theme;
  const _DistrictSheltersCard({
    required this.district,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Card(
      color: t.cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _RiskBadge(risk: district.floodRisk),
        title: Text(
          district.district,
          style: TextStyle(
              color: t.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${district.shelters.length} shelter(s) · DM: ${district.dmPhone}',
          style: TextStyle(color: t.textSecondary, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.call, color: Colors.green, size: 20),
          tooltip: 'Call DM',
          onPressed: () => _call(district.dmPhone),
        ),
        children: district.shelters
            .map((s) => _ShelterTile(shelter: s, theme: t))
            .toList(),
      ),
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ─────────────────────────────────────────────────────────────
// Shelter Tile
// ─────────────────────────────────────────────────────────────
class _ShelterTile extends StatelessWidget {
  final EvacuationShelter shelter;
  final RiverColors theme;
  const _ShelterTile({required this.shelter, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.blueAccent.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.home_filled, color: Colors.blueAccent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shelter.name,
                  style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  shelter.address,
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, color: t.textSecondary, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      'Capacity: ${shelter.capacity}',
                      style: TextStyle(color: t.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green, size: 20),
                tooltip: shelter.phone,
                onPressed: () => _call(shelter.phone),
              ),
              IconButton(
                icon: const Icon(Icons.directions,
                    color: Colors.blueAccent, size: 20),
                tooltip: 'Navigate',
                onPressed: () => _navigate(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigate() async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${shelter.lat},${shelter.lng}');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─────────────────────────────────────────────────────────────
// Risk Badge
// ─────────────────────────────────────────────────────────────
class _RiskBadge extends StatelessWidget {
  final String risk;
  const _RiskBadge({required this.risk});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (risk) {
      case 'HIGH':
        color = Colors.red;
        break;
      case 'MEDIUM':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water, color: color, size: 16),
          Text(
            risk == 'HIGH'
                ? 'H'
                : risk == 'MEDIUM'
                    ? 'M'
                    : 'L',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
