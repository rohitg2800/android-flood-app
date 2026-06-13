// lib/screens/news_feed_screen.dart  v3.0
// 7-day live flood-news feed.
// Auto-refreshes every 60 s from 8 sources.
// Filter bar: day range (1d/3d/7d) · source chips · severity chips.
// Timeline: items grouped by calendar day, newest first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/news_provider.dart';
import '../theme/river_theme.dart';

class NewsFeedScreen extends ConsumerWidget {
  static const String route = '/news-feed';
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync  = ref.watch(liveNewsProvider);
    final grouped    = ref.watch(filteredNewsProvider);
    final filter     = ref.watch(newsFilterProvider);
    final countdown  = ref.watch(newsCountdownProvider).when(
      data: (v) => v, loading: () => 60, error: (_, __) => 60,
    );

    final totalItems = grouped.values.fold(0, (s, l) => s + l.length);

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        title: Row(
          children: [
            const Text(
              'FLOOD NEWS',
              style: TextStyle(
                color: AppPalette.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppPalette.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '7 days',
                style: const TextStyle(
                    color: AppPalette.cyan, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppPalette.gold),
        actions: [
          if (filter.sources.isNotEmpty || filter.severities.isNotEmpty ||
              filter.days != 7)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: AppPalette.warning, size: 20),
              tooltip: 'Clear filters',
              onPressed: () => ref.read(newsFilterProvider.notifier).reset(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.cyan),
            tooltip: 'Refresh now',
            onPressed: () => ref.invalidate(liveNewsProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              _RefreshBar(countdown: countdown),
              _FilterBar(filter: filter),
            ],
          ),
        ),
      ),
      body: newsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(liveNewsProvider),
        ),
        data: (_) => totalItems == 0
            ? const _EmptyView()
            : _Timeline(grouped: grouped, totalItems: totalItems),
      ),
    );
  }
}

// ── Refresh bar ──────────────────────────────────────────────────────────────
class _RefreshBar extends StatelessWidget {
  final int countdown;
  const _RefreshBar({required this.countdown});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      color: AppPalette.abyss1,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.circle, color: AppPalette.safe, size: 6),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: countdown / 60.0,
                backgroundColor: AppPalette.abyss2,
                valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.cyan),
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('Next in ${countdown}s',
              style: const TextStyle(color: AppPalette.textGrey, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Filter bar ──────────────────────────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  final NewsFilter filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(newsFilterProvider.notifier);
    return Container(
      height: 78,
      color: AppPalette.abyss1,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: day range
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in [1, 3, 7])
                  _FilterChip(
                    label: '${d}d',
                    active: filter.days == d,
                    color: AppPalette.cyan,
                    onTap: () => notifier.setDays(d),
                  ),
                const SizedBox(width: 10),
                const _Divider(),
                const SizedBox(width: 10),
                // Source chips
                for (final s in _kSources.entries)
                  _FilterChip(
                    label: s.key,
                    active: filter.sources.contains(s.key),
                    color: s.value,
                    onTap: () => notifier.toggleSource(s.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Row 2: severity chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final sv in NewsSeverity.values)
                  _FilterChip(
                    label: _severityLabel(sv),
                    active: filter.severities.contains(sv),
                    color: _severityColor(sv),
                    onTap: () => notifier.toggleSeverity(sv),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _kSources = <String, Color>{
    'IMD':   AppPalette.cyan,
    'NDMA':  Color(0xFFF57C00),
    'CWC':   AppPalette.safe,
    'WRIS':  AppPalette.gold,
    'GDACS': Color(0xFFB39DDB),
    'PIB':   Color(0xFF80CBC4),
  };

  static String _severityLabel(NewsSeverity sv) {
    switch (sv) {
      case NewsSeverity.critical: return 'CRITICAL';
      case NewsSeverity.high:     return 'HIGH';
      case NewsSeverity.moderate: return 'MODERATE';
      case NewsSeverity.info:     return 'INFO';
    }
  }

  static Color _severityColor(NewsSeverity sv) {
    switch (sv) {
      case NewsSeverity.critical: return const Color(0xFFD32F2F);
      case NewsSeverity.high:     return const Color(0xFFF57C00);
      case NewsSeverity.moderate: return const Color(0xFFFBC02D);
      case NewsSeverity.info:     return AppPalette.textGrey;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   active;
  final Color  color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color:  active ? color.withValues(alpha: 0.22) : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.25),
            width: active ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      active ? color : AppPalette.textGrey,
            fontSize:   10,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 16, color: AppPalette.textGrey.withValues(alpha: 0.25));
}

// ── Timeline (day-grouped) ───────────────────────────────────────────────────
class _Timeline extends StatelessWidget {
  final Map<String, List<NewsItem>> grouped;
  final int totalItems;
  const _Timeline({required this.grouped, required this.totalItems});

  @override
  Widget build(BuildContext context) {
    final days = grouped.keys.toList(); // already sorted newest-first

    // Build a flat list: [dayHeader, item, item, ..., dayHeader, item, ...]
    final widgets = <Widget>[];
    for (final day in days) {
      final items = grouped[day]!;
      widgets.add(_DayHeader(dayKey: day, count: items.length));
      for (final item in items) {
        widgets.add(_NewsCard(item: item));
      }
    }

    return Column(
      children: [
        // Summary bar
        Container(
          color: AppPalette.abyss1,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '$totalItems items across ${grouped.length} day${grouped.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppPalette.textGrey, fontSize: 11),
              ),
              const Spacer(),
              Text(
                'Sources: IMD · NDMA · CWC · WRIS · GDACS · PIB',
                style: const TextStyle(color: AppPalette.textGrey, fontSize: 9),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            itemCount: widgets.length,
            itemBuilder: (_, i) => widgets[i],
          ),
        ),
      ],
    );
  }
}

// ── Day header ─────────────────────────────────────────────────────────────────
class _DayHeader extends StatelessWidget {
  final String dayKey; // yyyy-MM-dd
  final int    count;
  const _DayHeader({required this.dayKey, required this.count});

  String get _label {
    try {
      final d    = DateTime.parse(dayKey);
      final now  = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(d.year, d.month, d.day)).inDays;
      if (diff == 0) return 'TODAY  —  ${DateFormat('dd MMM').format(d)}';
      if (diff == 1) return 'YESTERDAY  —  ${DateFormat('dd MMM').format(d)}';
      return '${DateFormat('EEEE').format(d).toUpperCase()}  —  ${DateFormat('dd MMM').format(d)}';
    } catch (_) { return dayKey; }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
              color: AppPalette.cyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: const TextStyle(
              color: AppPalette.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppPalette.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  color: AppPalette.cyan, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const Expanded(child: Divider(
            color: Color(0xFF2A3040), thickness: 1, indent: 8,
          )),
        ],
      ),
    );
  }
}

// ── News card ─────────────────────────────────────────────────────────────────
class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  static const _kSourceColors = <String, Color>{
    'IMD':   AppPalette.cyan,
    'NDMA':  Color(0xFFF57C00),
    'CWC':   AppPalette.safe,
    'WRIS':  AppPalette.gold,
    'GDACS': Color(0xFFB39DDB),
    'PIB':   Color(0xFF80CBC4),
  };

  Color get _sevColor {
    switch (item.severity) {
      case NewsSeverity.critical: return const Color(0xFFD32F2F);
      case NewsSeverity.high:     return const Color(0xFFF57C00);
      case NewsSeverity.moderate: return const Color(0xFFFBC02D);
      case NewsSeverity.info:     return AppPalette.textGrey;
    }
  }

  String get _sevLabel {
    switch (item.severity) {
      case NewsSeverity.critical: return 'CRITICAL';
      case NewsSeverity.high:     return 'HIGH';
      case NewsSeverity.moderate: return 'MODERATE';
      case NewsSeverity.info:     return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sevColor = _sevColor;
    final srcColor = _kSourceColors[item.source] ?? AppPalette.textGrey;
    final timeStr  = _timeLabel(item.publishedAt);

    return GestureDetector(
      onTap: () async {
        if (item.url.isNotEmpty) {
          final uri = Uri.tryParse(item.url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: sevColor.withValues(alpha: 0.20)),
          // Left accent stripe via gradient
          gradient: LinearGradient(
            colors: [
              sevColor.withValues(alpha: 0.06),
              AppPalette.abyss2,
            ],
            stops: const [0.0, 0.12],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: source badge | severity badge | time | open-icon
            Row(
              children: [
                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: srcColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: srcColor.withValues(alpha: 0.3), width: 0.7),
                  ),
                  child: Text(
                    item.source,
                    style: TextStyle(
                        color: srcColor, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
                const SizedBox(width: 5),
                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _sevLabel,
                    style: TextStyle(
                        color: sevColor, fontSize: 9,
                        fontWeight: FontWeight.w900, letterSpacing: 0.4),
                  ),
                ),
                const Spacer(),
                Text(timeStr,
                    style: const TextStyle(color: AppPalette.textGrey, fontSize: 10)),
                if (item.url.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.open_in_new_rounded,
                      color: AppPalette.textGrey.withValues(alpha: 0.5), size: 12),
                ],
              ],
            ),
            const SizedBox(height: 7),
            // Title
            Text(
              item.title,
              style: const TextStyle(
                color:      AppPalette.textWhite,
                fontWeight: FontWeight.w700,
                fontSize:   13,
                height:     1.35,
              ),
            ),
            // Summary
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 12, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return DateFormat('HH:mm').format(t);
  }
}

// ── State views ──────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppPalette.cyan, strokeWidth: 2),
        SizedBox(height: 16),
        Text('Fetching 7-day news…',
            style: TextStyle(color: AppPalette.textGrey, fontSize: 13)),
        SizedBox(height: 6),
        Text('IMD · NDMA · CWC · WRIS · GDACS · PIB',
            style: TextStyle(color: AppPalette.textGrey, fontSize: 11)),
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'No items match the current filters.\nTry widening the date range or clearing source filters.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.textGrey, fontSize: 13, height: 1.5),
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppPalette.warning, size: 40),
          const SizedBox(height: 12),
          const Text('Could not fetch news',
              style: TextStyle(color: AppPalette.textWhite,
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.textGrey, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.cyan.withValues(alpha: 0.15)),
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.cyan, size: 16),
            label: const Text('Retry',
                style: TextStyle(color: AppPalette.cyan, fontSize: 13)),
          ),
        ],
      ),
    ),
  );
}
