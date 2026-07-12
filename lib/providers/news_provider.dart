// lib/providers/news_provider.dart  v2.0
// ─ liveNewsProvider     : StreamProvider — full 7-day fetch, refreshes every 60 s
// ─ newsFilterProvider   : NotifierProvider — user-controlled filter state
// ─ filteredNewsProvider : Provider — applies filter + groups by day
// ─ newsCountdownProvider: StreamProvider — seconds until next refresh
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/news_service.dart';

export '../services/news_service.dart' show NewsItem, NewsFilter, NewsSeverity;

// ── Service singleton ──────────────────────────────────────────────────────────
final newsServiceProvider = Provider<NewsService>((_) => NewsService());

// ── Raw 7-day fetch stream (60 s refresh) ─────────────────────────────────
final liveNewsProvider = StreamProvider<List<NewsItem>>((ref) async* {
  final svc = ref.watch(newsServiceProvider);
  yield await svc.fetchAll();
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 60))) {
    yield await svc.fetchAll();
  }
});

// ── User filter state ───────────────────────────────────────────────────────
class NewsFilterNotifier extends Notifier<NewsFilter> {
  @override
  NewsFilter build() => const NewsFilter();

  void setDays(int d) => state = state.copyWith(days: d);
  void toggleSource(String s) {
    final set = Set<String>.from(state.sources);
    set.contains(s) ? set.remove(s) : set.add(s);
    state = state.copyWith(sources: set);
  }

  void toggleSeverity(NewsSeverity sv) {
    final set = Set<NewsSeverity>.from(state.severities);
    set.contains(sv) ? set.remove(sv) : set.add(sv);
    state = state.copyWith(severities: set);
  }

  void reset() => state = const NewsFilter();
  void setLanguage(String lang) => state = state.copyWith(language: lang);
}

final newsFilterProvider =
    NotifierProvider<NewsFilterNotifier, NewsFilter>(NewsFilterNotifier.new);

// ── Filtered + day-grouped result ───────────────────────────────────────────
/// Map<dayKey, List<NewsItem>> — only call inside newsAsync.when(data:)
final filteredNewsProvider = Provider<Map<String, List<NewsItem>>>((ref) {
  final filter = ref.watch(newsFilterProvider);
  final newsAsync = ref.watch(liveNewsProvider);
  final all = newsAsync.when(
    data: (v) => v,
    loading: () => <NewsItem>[],
    error: (_, __) => <NewsItem>[],
  );
  final filtered = NewsService.applyFilter(all, filter);
  return NewsService.groupByDay(filtered);
});

// ── Countdown ticker ───────────────────────────────────────────────────────────
final newsCountdownProvider = StreamProvider<int>((ref) async* {
  var count = 60;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 1))) {
    yield count;
    count--;
    if (count < 0) count = 60;
  }
});
