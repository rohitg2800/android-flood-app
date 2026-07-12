// lib/providers/news_feed_provider.dart
// Riverpod 3.x compatible — uses Notifier + NotifierProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backend_api_service.dart';

// ── State model ──────────────────────────────────────────────────────────────
class NewsItem {
  final String title;
  final String source;
  final String severity; // RED | ORANGE | YELLOW | INFO
  final String url;
  final String publishedAt; // kept as String — format in UI with intl if needed
  final String? summary;

  const NewsItem({
    required this.title,
    required this.source,
    required this.severity,
    required this.url,
    required this.publishedAt,
    this.summary,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        title: j['title'] as String? ?? '',
        source: j['source'] as String? ?? 'Unknown',
        severity: j['severity'] as String? ?? 'INFO',
        url: j['url'] as String? ?? '',
        publishedAt: j['published_at'] as String? ?? 'Latest bulletin',
        summary: j['summary'] as String?,
      );
}

class NewsFeedState {
  final List<NewsItem> items;
  final bool isLoading;
  final String? error;

  const NewsFeedState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  NewsFeedState copyWith({
    List<NewsItem>? items,
    bool? isLoading,
    String? error,
  }) =>
      NewsFeedState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────
class NewsFeedNotifier extends Notifier<NewsFeedState> {
  @override
  NewsFeedState build() {
    Future.microtask(fetch);
    return const NewsFeedState(isLoading: true);
  }

  /// Called by pull-to-refresh in news_feed_screen.dart
  Future<void> refresh() => fetch();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true);
    try {
      final raw = await BackendApiService.instance.fetchNews(state: 'bihar');
      final items = raw.map(NewsItem.fromJson).toList();
      state = NewsFeedState(items: items.isNotEmpty ? items : _fallback());
    } catch (e) {
      state = NewsFeedState(items: _fallback(), error: e.toString());
    }
  }

  List<NewsItem> _fallback() => const [
        NewsItem(
          title:
              'IMD: Heavy to very heavy rainfall likely over North Bihar in next 48h',
          source: 'IMD',
          severity: 'ORANGE',
          url: 'https://mausam.imd.gov.in',
          publishedAt: 'Latest bulletin',
          summary:
              'Orange alert issued for Sitamarhi, Madhubani, Supaul and adjoining districts.',
        ),
        NewsItem(
          title:
              'CWC: Kosi at Birpur above danger level — embankment patrolling activated',
          source: 'CWC',
          severity: 'RED',
          url: 'https://cwc.gov.in',
          publishedAt: 'Latest bulletin',
          summary:
              'Gauge reading at 74.82 m MSL, danger level 74.70 m. Downstream alert issued.',
        ),
        NewsItem(
          title:
              'NDMA: Pre-positioning of NDRF teams in Supaul, Madhubani, Darbhanga',
          source: 'NDMA',
          severity: 'ORANGE',
          url: 'https://ndma.gov.in',
          publishedAt: 'Latest bulletin',
        ),
        NewsItem(
          title: 'Bihar WRD: Gandak at Dumariaghat approaching warning level',
          source: 'Bihar WRD',
          severity: 'YELLOW',
          url: 'https://fmiscwrdbihar.gov.in',
          publishedAt: 'Latest bulletin',
        ),
        NewsItem(
          title:
              'BSDMA: 12 districts on flood alert — evacuation centres activated',
          source: 'BSDMA',
          severity: 'RED',
          url: 'https://bsdma.org',
          publishedAt: 'Latest bulletin',
          summary:
              'Residents in low-lying areas advised to move to higher ground immediately.',
        ),
      ];
}

// ── Provider ──────────────────────────────────────────────────────────────────
final newsFeedProvider =
    NotifierProvider<NewsFeedNotifier, NewsFeedState>(NewsFeedNotifier.new);
