// lib/screens/community_screen.dart
// OpsFlood — Phase 10: Community Screen — district threads + safety tips

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../app_router.dart';

class CommunityScreen extends StatefulWidget {
  static const String route = '/community';
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _selectedDistrict = 'All Districts';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t  = RiverColors.of(context);
    final ct = core_theme.RiverTheme.maybeOf(context)?.colors ?? core_theme.RiverTheme.of(context).colors;
    return Scaffold(
      backgroundColor: ct.scaffoldBg,
      appBar: AppBar(
        backgroundColor: ct.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ct.textPrimary,
        title: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.people_outline, color: Color(0xFF2DD4BF), size: 16),
            ),
            const SizedBox(width: 10),
            Text('Community', style: TextStyle(color: ct.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: ct.accent,
          labelColor: ct.accent,
          unselectedLabelColor: ct.textSecondary,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.forum_outlined, size: 16),
                text: 'District Threads'),
            Tab(icon: Icon(Icons.health_and_safety_outlined, size: 16),
                text: 'Safety Tips'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _selectedDistrict,
              dropdownColor: t.navBg,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down,
                  color: t.textSecondary, size: 18),
              style: TextStyle(
                  color: t.textPrimary, fontSize: 12),
              items: ['All Districts', ..._biharDistricts]
                  .map((d) => DropdownMenuItem(
                      value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedDistrict = v ?? 'All Districts'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Quick action strip ──────────────────────────────────
          Container(
            color: ct.scaffoldBg,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              _QuickTile(icon: Icons.report_problem_rounded, label: 'Report Incident', color: const Color(0xFFFF8C42), onTap: () => context.go(Routes.incidentReport)),
              const SizedBox(width: 10),
              _QuickTile(icon: Icons.group_rounded, label: 'Crowd Reports', color: const Color(0xFF4CB3FF), onTap: () => context.go(Routes.crowdReports)),
              const SizedBox(width: 10),
              _QuickTile(icon: Icons.newspaper_rounded, label: 'News Feed', color: const Color(0xFF3ACC8A), onTap: () => context.go(Routes.news)),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ThreadsTab(selectedDistrict: _selectedDistrict),
                const _SafetyTipsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — District Threads
// ─────────────────────────────────────────────────────────────────────────────

class _ThreadsTab extends StatefulWidget {
  final String selectedDistrict;
  const _ThreadsTab({required this.selectedDistrict});
  @override
  State<_ThreadsTab> createState() => _ThreadsTabState();
}

class _ThreadsTabState extends State<_ThreadsTab> {
  List<_Thread> _threads = [];
  bool _loading = true;
  static const _key = 'community_threads_v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final loaded = raw.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return _Thread.fromJson(m);
      } catch (_) { return null; }
    }).whereType<_Thread>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (loaded.isEmpty) {
      final seeded = _sampleThreads();
      final encoded = seeded.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_key, encoded);
      setState(() { _threads = seeded; _loading = false; });
    } else {
      setState(() { _threads = loaded; _loading = false; });
    }
  }

  Future<void> _addThread(_Thread thread) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(thread.toJson()));
    await prefs.setStringList(_key, raw);
    setState(() => _threads.insert(0, thread));
  }

  Future<void> _upvote(int idx) async {
    final updated = _threads[idx].copyWithUpvote();
    final prefs = await SharedPreferences.getInstance();
    _threads[idx] = updated;
    await prefs.setStringList(
        _key, _threads.map((t) => jsonEncode(t.toJson())).toList());
    setState(() {});
  }

  List<_Thread> get _filtered => _threads
      .where((t) =>
          widget.selectedDistrict == 'All Districts' ||
          t.district == widget.selectedDistrict)
      .toList();

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? _Empty(theme: t)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _ThreadCard(
                      thread: filtered[i],
                      theme: t,
                      onUpvote: () {
                        final realIdx = _threads.indexOf(filtered[i]);
                        if (realIdx >= 0) _upvote(realIdx);
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        mini: true,
        tooltip: 'New Thread',
        child: const Icon(Icons.edit),
        onPressed: () => _showNewThreadDialog(context, t),
      ),
    );
  }

  void _showNewThreadDialog(BuildContext ctx, RiverColors t) {
    String district = widget.selectedDistrict == 'All Districts'
        ? _biharDistricts.first
        : widget.selectedDistrict;
    String message = '';
    String author = '';
    showDialog<void>(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          backgroundColor: t.navBg,
          title: Text('New Thread',
              style: TextStyle(color: t.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: district,
                isExpanded: true,
                dropdownColor: t.navBg,
                style: TextStyle(color: t.textPrimary, fontSize: 13),
                items: _biharDistricts
                    .map((d) => DropdownMenuItem(
                        value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) =>
                    setS(() => district = v ?? district),
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                maxLength: 300,
                style: TextStyle(
                    color: t.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Share a situation update, ask for help\u2026',
                  hintStyle: TextStyle(
                      color: t.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: t.cardBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) => message = v,
              ),
              const SizedBox(height: 8),
              TextField(
                style: TextStyle(
                    color: t.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Your name (optional)',
                  hintStyle: TextStyle(
                      color: t.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: t.cardBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) => author = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: Text('Cancel',
                  style: TextStyle(color: t.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal),
              onPressed: () {
                if (message.trim().length < 5) return;
                _addThread(_Thread(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  district: district,
                  message: message.trim(),
                  author: author.trim().isEmpty
                      ? 'Anonymous'
                      : author.trim(),
                  createdAt: DateTime.now(),
                  upvotes: 0,
                ));
                Navigator.pop(ctx2);
              },
              child: const Text('Post',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final _Thread thread;
  final RiverColors theme;
  final VoidCallback onUpvote;
  const _ThreadCard(
      {required this.thread,
      required this.theme,
      required this.onUpvote});

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Td3Card(
      showGloss: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.4)),
                  ),
                  child: Text(thread.district,
                      style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Text(_timeAgo(thread.createdAt),
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(thread.message,
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 13,
                    height: 1.45)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 12, color: t.textSecondary),
                const SizedBox(width: 4),
                Text(thread.author,
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 11)),
                const Spacer(),
                GestureDetector(
                  onTap: onUpvote,
                  child: Row(
                    children: [
                      Icon(Icons.thumb_up_outlined,
                          size: 14, color: t.accent),
                      const SizedBox(width: 4),
                      Text('${thread.upvotes}',
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final RiverColors theme;
  const _Empty({required this.theme});
  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 60, color: t.textSecondary),
          const SizedBox(height: 12),
          Text('No threads yet',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Be the first to post an update for your district.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Thread {
  final String id;
  final String district;
  final String message;
  final String author;
  final DateTime createdAt;
  final int upvotes;

  const _Thread({
    required this.id,
    required this.district,
    required this.message,
    required this.author,
    required this.createdAt,
    required this.upvotes,
  });

  _Thread copyWithUpvote() => _Thread(
      id: id, district: district, message: message,
      author: author, createdAt: createdAt, upvotes: upvotes + 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'district': district,
        'message': message,
        'author': author,
        'createdAt': createdAt.toIso8601String(),
        'upvotes': upvotes,
      };

  factory _Thread.fromJson(Map<String, dynamic> j) => _Thread(
        id: j['id'] ?? '',
        district: j['district'] ?? '',
        message: j['message'] ?? '',
        author: j['author'] ?? 'Anonymous',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        upvotes: j['upvotes'] ?? 0,
      );
}

List<_Thread> _sampleThreads() => [
  _Thread(
    id: '1', district: 'Darbhanga',
    message: 'Bagmati embankment breach reported near Hayaghat. '
        'Water level 3m above danger level. Local admin has been notified.',
    author: 'Ramesh Kumar',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    upvotes: 14,
  ),
  _Thread(
    id: '2', district: 'Sitamarhi',
    message: 'Relief camp operational at Govt High School, Sitamarhi. '
        'Food & medicine available. Capacity 300 persons.',
    author: 'Block Officer (Unofficial)',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    upvotes: 28,
  ),
  _Thread(
    id: '3', district: 'Muzaffarpur',
    message: 'NH-57 flooded between Bochaha and Gaighat. '
        'Vehicles diverted via Motipur\u2013Ahiyapur route.',
    author: 'Anonymous',
    createdAt: DateTime.now().subtract(const Duration(hours: 9)),
    upvotes: 7,
  ),
  _Thread(
    id: '4', district: 'Supaul',
    message: 'Kosi river rising rapidly. Last reading 53.12m vs DL 50.40m. '
        'Villagers in low-lying areas advised to move to higher ground.',
    author: 'Priya Singh',
    createdAt: DateTime.now().subtract(const Duration(hours: 14)),
    upvotes: 41,
  ),
  _Thread(
    id: '5', district: 'Gopalganj',
    message: 'Gandak breached near Majhaulia. Rescue boats operational. '
        'Contact SDRF helpline: 0641-2221234.',
    author: 'Civil Defence Volunteer',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    upvotes: 19,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Safety Tips
// ─────────────────────────────────────────────────────────────────────────────

class _SafetyTipsTab extends StatelessWidget {
  const _SafetyTipsTab();

  static const List<_TipSection> _sections = [
    _TipSection(
      title: 'Before a Flood',
      icon: Icons.offline_bolt_outlined,
      color: Colors.amber,
      tips: [
        'Store 3 days of drinking water & dry food in waterproof containers.',
        'Keep important documents (Aadhaar, land records) in a sealed plastic bag.',
        'Identify the nearest relief camp and evacuation route.',
        'Charge all mobile devices; keep a power bank ready.',
        'Move livestock, LPG cylinders and valuables to higher floors.',
        'Know your local SDRF/NDRF helpline numbers.',
      ],
    ),
    _TipSection(
      title: 'During a Flood',
      icon: Icons.warning_amber_outlined,
      color: Colors.deepOrange,
      tips: [
        'Do NOT walk or drive through flowing floodwater \u2014 15 cm can knock you down.',
        'Disconnect all electrical appliances before water enters your home.',
        'Move to the highest floor; do not enter the attic without a roof escape.',
        'Signal for help using bright cloth, torch or mobile.',
        'Avoid contact with floodwater \u2014 it may be contaminated.',
        'Follow only official evacuation orders \u2014 avoid rumours.',
      ],
    ),
    _TipSection(
      title: 'After a Flood',
      icon: Icons.check_circle_outline,
      color: Colors.green,
      tips: [
        'Return home only after authorities declare it safe.',
        'Boil all drinking water for at least 5 minutes.',
        'Beware of snakes and insects that shelter in debris.',
        'Document damage with photos for insurance/relief claims.',
        'Disinfect walls, floors and utensils with a bleach solution.',
        'Watch for signs of cholera, typhoid or leptospirosis.',
      ],
    ),
    _TipSection(
      title: 'Emergency Contacts \u2014 Bihar',
      icon: Icons.phone_in_talk_outlined,
      color: Colors.blue,
      tips: [
        'NDRF Helpline: 011-24363260',
        'Bihar SDMA: 0612-2217305',
        'Police: 100  |  Ambulance: 108  |  Fire: 101',
        'Flood Control Room (Patna): 0612-2215028',
        'NDMA India SMS Alert: send FLOOD to 7738299899',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _sections.map((s) => _TipSectionCard(s: s, theme: t)).toList(),
    );
  }
}

class _TipSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> tips;
  const _TipSection(
      {required this.title,
      required this.icon,
      required this.color,
      required this.tips});
}

class _TipSectionCard extends StatefulWidget {
  final _TipSection s;
  final RiverColors theme;
  const _TipSectionCard(
      {required this.s, required this.theme});
  @override
  State<_TipSectionCard> createState() => _TipSectionCardState();
}

class _TipSectionCardState extends State<_TipSectionCard> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final s = widget.s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Td3Card(
        showGloss: false,
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(s.icon, color: s.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.title,
                          style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: t.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              Divider(
                  height: 1,
                  color: t.divider.withValues(alpha: 0.4)),
              ...s.tips.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 12,
                                  height: 1.5)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

const List<String> _biharDistricts = [
  'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur',
  'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj',
  'Jamui', 'Jehanabad', 'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj',
  'Lakhisarai', 'Madhepura', 'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda',
  'Nawada', 'Patna', 'Purnia', 'Rohtas', 'Saharsa', 'Samastipur', 'Saran',
  'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali',
  'West Champaran',
];

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ),
    );
  }
}
