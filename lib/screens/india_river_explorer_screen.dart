// lib/screens/india_river_explorer_screen.dart
// OpsFlood — Phase 10: India River Explorer
// National-level river selector → routes into Bihar map flow for Bihar rivers,
// or shows a detail card for non-Bihar rivers.

import 'package:flutter/material.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import 'bihar_river_map_screen.dart';

class IndiaRiverExplorerScreen extends StatefulWidget {
  static const String route = '/india-river-explorer';
  const IndiaRiverExplorerScreen({super.key});

  @override
  State<IndiaRiverExplorerScreen> createState() =>
      _IndiaRiverExplorerScreenState();
}

class _IndiaRiverExplorerScreenState extends State<IndiaRiverExplorerScreen> {
  String _searchQuery = '';
  String? _selectedSystem;

  static const List<_RiverEntry> _rivers = [
    // ── Bihar / Ganga System ──
    _RiverEntry(
        'Ganga',
        'Bihar / UP',
        'Ganga System',
        3200,
        true,
        Colors.blue,
        Icons.water,
        'Mainstem of the Gangetic plain; flood risk zone Bihar–UP border.'),
    _RiverEntry(
        'Gandak',
        'Bihar / Nepal',
        'Ganga System',
        630,
        true,
        Colors.cyan,
        Icons.water,
        'Narayani in Nepal; highly dynamic, breaches Gopalganj–Saran every year.'),
    _RiverEntry(
        'Kosi',
        'Bihar / Nepal',
        'Ganga System',
        720,
        true,
        Color(0xFFB71C1C),
        Icons.crisis_alert,
        'The Sorrow of Bihar — avulsion-prone, drains 60k km².'),
    _RiverEntry(
        'Bagmati',
        'Bihar / Nepal',
        'Ganga System',
        597,
        true,
        Colors.teal,
        Icons.water,
        'Flows through Sitamarhi & Darbhanga; frequent embankment breaches.'),
    _RiverEntry(
        'Kamla',
        'Bihar / Nepal',
        'Ganga System',
        328,
        true,
        Colors.lightBlue,
        Icons.water,
        'Originates in Mahabharat range; flash-flood prone in Madhubani.'),
    _RiverEntry(
        'Burhi Gandak',
        'Bihar',
        'Ganga System',
        320,
        true,
        Colors.indigo,
        Icons.water,
        'Flows through Muzaffarpur; high sedimentation rate.'),
    _RiverEntry(
        'Mahananda',
        'Bihar / WB',
        'Ganga System',
        360,
        true,
        Colors.purple,
        Icons.water,
        'Drains Kishanganj & Katihar; joins Ganga at Manihari.'),
    _RiverEntry('Son', 'Bihar / MP', 'Ganga System', 784, true, Colors.amber,
        Icons.water, 'Major southern tributary; flows through Rohtas & Arrah.'),
    _RiverEntry('Punpun', 'Bihar', 'Ganga System', 200, true, Colors.lime,
        Icons.water, 'Drains Gaya & Patna; floods Patna’s southern fringe.'),
    _RiverEntry(
        'Falgu',
        'Bihar',
        'Ganga System',
        122,
        false,
        Colors.brown,
        Icons.water,
        'Sacred river at Gaya; seasonal — surface flow only in monsoon.'),
    // ── National Major Rivers ──
    _RiverEntry(
        'Brahmaputra',
        'Assam / Arunachal',
        'Brahmaputra System',
        2900,
        false,
        Colors.deepOrange,
        Icons.water,
        'One of Asia’s largest rivers; severe annual flooding in Assam.'),
    _RiverEntry(
        'Yamuna',
        'UP / Delhi',
        'Ganga System',
        1376,
        false,
        Colors.green,
        Icons.water,
        'Largest tributary of Ganga; Delhi flood risk during heavy monsoon.'),
    _RiverEntry(
        'Narmada',
        'MP / Gujarat',
        'Deccan System',
        1312,
        false,
        Colors.orange,
        Icons.water,
        'Flows west to Arabian Sea; Sardar Sarovar controls flood releases.'),
    _RiverEntry(
        'Godavari',
        'Telangana / AP',
        'Deccan System',
        1465,
        false,
        Colors.deepPurple,
        Icons.water,
        'Dakshin Ganga; severe flooding in Bhadrachalam & Rajamahendravaram.'),
    _RiverEntry(
        'Krishna',
        'Karnataka / AP',
        'Deccan System',
        1400,
        false,
        Colors.teal,
        Icons.water,
        'Major Peninsular river; flash floods in Srisailam region.'),
    _RiverEntry(
        'Mahanadi',
        'Chhattisgarh / Odisha',
        'East Coast',
        900,
        false,
        Colors.cyan,
        Icons.water,
        'Drains into Bay of Bengal; Hirakud Dam regulates peak flows.'),
    _RiverEntry(
        'Cauvery',
        'Karnataka / TN',
        'Deccan System',
        800,
        false,
        Colors.amber,
        Icons.water,
        'Inter-state river; flooding in Mettur–Cauvery Delta zone.'),
    _RiverEntry(
        'Indus',
        'Ladakh / Punjab',
        'Indus System',
        3180,
        false,
        Colors.blueGrey,
        Icons.water,
        'Trans-Himalayan river; Pakistan-boundary issue limits data sharing.'),
    _RiverEntry(
        'Chenab',
        'J&K / Punjab',
        'Indus System',
        960,
        false,
        Colors.lightGreen,
        Icons.water,
        'Flash floods common in Akhnoor & Reasi sections.'),
  ];

  List<_RiverEntry> get _filtered {
    final q = _searchQuery.toLowerCase();
    return _rivers.where((r) {
      final matchesQ = q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.region.toLowerCase().contains(q);
      final matchesSys = _selectedSystem == null || r.system == _selectedSystem;
      return matchesQ && matchesSys;
    }).toList();
  }

  Set<String> get _systems => _rivers.map((r) => r.system).toSet();

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final filtered = _filtered;
    final biharCount = filtered.where((r) => r.isBiharRiver).length;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
        title: Row(
          children: [
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.travel_explore_rounded,
                    color: Color(0xFF06B6D4), size: 17)),
            const SizedBox(width: 10),
            Text('India River Explorer',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildHeader(t, biharCount, filtered.length),
          _buildSearchAndFilter(t),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No rivers match your search.',
                        style: TextStyle(color: t.textSecondary, fontSize: 14)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _RiverCard(
                      river: filtered[i],
                      theme: t,
                      onTap: () => _onRiverTap(ctx, filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(RiverColors t, int bihar, int total) {
    return Container(
      color: t.navBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _StatPill(
              label: 'Total Rivers',
              value: '${_rivers.length}',
              color: t.accent,
              theme: t),
          const SizedBox(width: 10),
          _StatPill(
              label: 'Bihar Rivers',
              value: '${_rivers.where((r) => r.isBiharRiver).length}',
              color: Colors.blue,
              theme: t),
          const SizedBox(width: 10),
          _StatPill(
              label: 'Showing', value: '$total', color: Colors.teal, theme: t),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(RiverColors t) {
    return Container(
      color: t.navBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: t.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search river or region…',
              hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 18),
              filled: true,
              fillColor: t.cardBg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SystemChip(
                  label: 'All',
                  selected: _selectedSystem == null,
                  theme: t,
                  onTap: () => setState(() => _selectedSystem = null),
                ),
                ..._systems.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _SystemChip(
                        label: s,
                        selected: _selectedSystem == s,
                        theme: t,
                        onTap: () => setState(() => _selectedSystem = s),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onRiverTap(BuildContext ctx, _RiverEntry river) {
    if (river.isBiharRiver) {
      Navigator.pushNamed(ctx, BiharRiverMapScreen.route);
    } else {
      _showNationalRiverSheet(ctx, river);
    }
  }

  void _showNationalRiverSheet(BuildContext ctx, _RiverEntry r) {
    final t = RiverColors.of(ctx);
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: t.navBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: t.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(r.icon, color: r.color, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text('${r.region} • ${r.system}',
                        style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SheetStat(
                    label: 'Length', value: '${r.lengthKm} km', theme: t),
                const SizedBox(width: 16),
                _SheetStat(
                    label: 'Bihar Data',
                    value: r.isBiharRiver ? 'Live' : 'N/A',
                    theme: t),
              ],
            ),
            const SizedBox(height: 14),
            Text(r.description,
                style:
                    TextStyle(color: t.textPrimary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('View Bihar Flood Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(ctx, BiharRiverMapScreen.route);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────────────

class _RiverEntry {
  final String name;
  final String region;
  final String system;
  final int lengthKm;
  final bool isBiharRiver;
  final Color color;
  final IconData icon;
  final String description;
  const _RiverEntry(this.name, this.region, this.system, this.lengthKm,
      this.isBiharRiver, this.color, this.icon, this.description);
}

// ── Widgets ──────────────────────────────────────────────────────────────────────

class _RiverCard extends StatelessWidget {
  final _RiverEntry river;
  final RiverColors theme;
  final VoidCallback onTap;
  const _RiverCard(
      {required this.river, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final r = river;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF0F141B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: r.isBiharRiver
                    ? r.color.withValues(alpha: 0.30)
                    : const Color(0xFF232934))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: r.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: r.color.withValues(alpha: 0.5)),
              ),
              child: Icon(r.icon, color: r.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.name,
                          style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      if (r.isBiharRiver)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.5)),
                          ),
                          child: const Text('LIVE',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  Text(
                    '${r.region} • ${r.system} • ${r.lengthKm} km',
                    style: TextStyle(color: t.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(r.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.textPrimary.withValues(alpha: 0.75),
                          fontSize: 11,
                          height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              r.isBiharRiver ? Icons.map_outlined : Icons.info_outline,
              color: t.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final RiverColors theme;
  const _StatPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.theme});
  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  final String label;
  final bool selected;
  final RiverColors theme;
  final VoidCallback onTap;
  const _SystemChip(
      {required this.label,
      required this.selected,
      required this.theme,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.18) : t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? t.accent : t.divider.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? t.accent : t.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  final String label;
  final String value;
  final RiverColors theme;
  const _SheetStat(
      {required this.label, required this.value, required this.theme});
  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11)),
        Text(value,
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
