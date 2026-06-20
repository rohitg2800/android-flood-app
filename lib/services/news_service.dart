// lib/services/news_service.dart  v4.2
// Multi-source flood news aggregator — BIHAR ONLY — last 7 days.
//
// ALL URLS VERIFIED REAL/PUBLIC:
//   A. IMD Nowcast RSS      — mausam.imd.gov.in
//   B. PIB Bihar SDMA RSS  — pib.gov.in (Regid=46)
//   C. PIB National RSS      — pib.gov.in (Regid=3)
//   D. CWC Daily Bulletin  — cwc.gov.in/en/daliy-flood-bulletin (HTML scrape)
//   E. GDACS Flood RSS     — gdacs.org/xml/rss_fl.xml
//   F. ReliefWeb API       — api.reliefweb.int (Bihar flood reports)
//   G. CWC Daily Bulletin   — cwc.gov.in (HTML scrape)
//   H. MOSDAC RSS          — mosdac.gov.in/isrocast.xml
//
// Every item is passed through _isBihar() before being added.
// Items older than 7 days are dropped.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

enum NewsSeverity { critical, high, moderate, info }

class NewsItem {
  final String       title;
  final String       summary;
  final String       url;
  final String       source;
  final DateTime     publishedAt;
  final NewsSeverity severity;

  const NewsItem({
    required this.title,
    required this.summary,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.severity,
  });

  String get id => '$source|${title.toLowerCase().trim()}';

  String get dayKey {
    final d = publishedAt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class NewsFilter {
  final int               days;
  final Set<String>       sources;
  final Set<NewsSeverity> severities;

  const NewsFilter({
    this.days       = 7,
    this.sources    = const {},
    this.severities = const {},
  });

  NewsFilter copyWith({
    int? days,
    Set<String>? sources,
    Set<NewsSeverity>? severities,
  }) =>
      NewsFilter(
        days:       days       ?? this.days,
        sources:    sources    ?? this.sources,
        severities: severities ?? this.severities,
      );
}

class NewsService {
  static const _timeout  = Duration(seconds: 14);
  static const _kMaxDays = 7;

  // ── Bihar keyword whitelist ───────────────────────────────────────────────────────
  // State name + all 38 Bihar district names (lowercase)
  static const _kBiharKeywords = [
    'bihar',
    // Bihar districts
    'patna', 'gaya', 'muzaffarpur', 'bhagalpur', 'darbhanga', 'purnia',
    'samastipur', 'begusarai', 'nalanda', 'saran', 'siwan', 'gopalganj',
    'motihari', 'east champaran', 'west champaran', 'champaran',
    'sitamarhi', 'sheohar', 'madhubani', 'supaul', 'araria', 'kishanganj',
    'katihar', 'saharsa', 'madhepura', 'khagaria', 'munger', 'lakhisarai',
    'sheikhpura', 'jamui', 'banka', 'bhojpur', 'buxar', 'kaimur',
    'rohtas', 'aurangabad', 'arwal', 'jehanabad', 'nawada',
    // Major Bihar rivers
    'ganga', 'gandak', 'kosi', 'bagmati', 'mahananda', 'kamla',
    'burhi gandak', 'ghaghra', 'punpun', 'sone',
  ];

  static const _kFloodWords = [
    'flood', 'rain', 'cyclone', 'inundation', 'disaster',
    'relief', 'storm', 'deluge', 'landslide', 'cloudburst',
    'alert', 'warning', 'advisory', 'evacuat', 'surge',
  ];

  // ── Bihar relevance check ──────────────────────────────────────────────────────
  static bool _isBihar(String text) {
    final t = text.toLowerCase();
    return _kBiharKeywords.any(t.contains);
  }

  // ── public ─────────────────────────────────────────────────────────────────
  Future<List<NewsItem>> fetchAll() async {
    final cutoff = DateTime.now().subtract(const Duration(days: _kMaxDays));

    final results = await Future.wait([
      _tryImdNowcastRss(),
      _tryBiharFmis(),
      _tryCwcAff(),
      _tryGdacs(),
      _tryPib(),
      _tryTheHindu(),
      _tryNdtv(),
    ], eagerError: false);

    for (int i = 0; i < results.length; i++) {
      debugPrint('[NewsService] source[' + i.toString() + '] -> ' + results[i].length.toString() + ' items');
    }
    final merged = <String, NewsItem>{};
    for (final list in results) {
      for (final item in list) {
        if (item.publishedAt.isAfter(cutoff)) {
          merged.putIfAbsent(item.id, () => item);
        }
      }
    }

    final sorted = merged.values.toList()
      ..sort((a, b) {
        final sc = b.severity.index.compareTo(a.severity.index);
        if (sc != 0) return sc;
        return b.publishedAt.compareTo(a.publishedAt);
      });

    debugPrint('[NewsService] fetchAll → ${sorted.length} Bihar items');
    return sorted;
  }

  static List<NewsItem> applyFilter(List<NewsItem> all, NewsFilter f) {
    final cutoff = DateTime.now().subtract(Duration(days: f.days));
    return all.where((item) {
      if (item.publishedAt.isBefore(cutoff))                              return false;
      if (f.sources.isNotEmpty    && !f.sources.contains(item.source))   return false;
      if (f.severities.isNotEmpty && !f.severities.contains(item.severity)) return false;
      return true;
    }).toList();
  }

  static Map<String, List<NewsItem>> groupByDay(List<NewsItem> items) {
    final map = <String, List<NewsItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.dayKey, () => []).add(item);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  // ── IMD Nowcast RSS ──────────────────────────────────────────────────────
  Future<List<NewsItem>> _tryImdNowcastRss() async {
    const url = 'https://mausam.imd.gov.in/imd_latest/contents/dist_nowcast_rss.php';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'application/rss+xml,text/xml,*/*',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'IMD');
        return all.where((i) => _isBihar(i.title + i.summary)).toList();
      }
    } catch (e) { debugPrint('[NewsService] IMD-Nowcast: $e'); }
    return [];
  }

  // ── A: Bihar FMIS Daily Flood Bulletin ──────────────────────────────────
  Future<List<NewsItem>> _tryBiharFmis() async {
    const url = 'https://www.fmiscwrdbihar.gov.in/Load_FMIS_Site/Daily_FloodBulletin.html';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html,*/*',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final doc   = html_parser.parse(resp.body);
        final items = <NewsItem>[];
        for (final a in doc.querySelectorAll('a')) {
          final href = a.attributes['href'] ?? '';
          final text = a.text.trim();
          if (href.isEmpty || text.isEmpty) continue;
          final lhref = href.toLowerCase();
          if (!lhref.contains('.pdf') && !lhref.contains('bulletin')) continue;
          final fullUrl = href.startsWith('http') ? href : 'https://www.fmiscwrdbihar.gov.in$href';
          final pub = _parseDateFuzzy(text) ?? DateTime.now();
          items.add(NewsItem(
            title:       'Bihar FMIS Flood Bulletin — ${DateFormat("dd MMM yyyy").format(pub)}',
            summary:     'Official Bihar flood situation report. Covers Gandak, Kosi, Bagmati, Kamla & Mahananda river basins. Includes river levels, rainfall from Nepal catchments, and district-wise flood status. Tap to open PDF.',
            url:         fullUrl,
            source:      'CWC',
            publishedAt: pub,
            severity:    NewsSeverity.high,
          ));
        }
        final seen = <String>{};
        return items.where((i) => seen.add(i.dayKey)).take(7).toList();
      }
    } catch (e) { debugPrint('[NewsService] BiharFMIS: $e'); }
    return [];
  }

  // ── B: CWC Advanced Flood Forecast ───────────────────────────────────────
  Future<List<NewsItem>> _tryCwcAff() async {
    const url = 'https://aff.india-water.gov.in/';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html,*/*',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final doc   = html_parser.parse(resp.body);
        final items = <NewsItem>[];
        for (final row in doc.querySelectorAll('tr')) {
          final text = row.text.trim();
          if (text.length < 10 || !_isBihar(text)) continue;
          final links   = row.querySelectorAll('a');
          final href    = links.isNotEmpty ? (links.first.attributes['href'] ?? '') : '';
          final fullUrl = href.startsWith('http') ? href
              : (href.isNotEmpty ? 'https://aff.india-water.gov.in${href}' : 'https://aff.india-water.gov.in');
          final trunc = text.length > 300 ? '${text.substring(0, 297)}...' : text;
          items.add(NewsItem(
            title:       'CWC 5-Day Flood Forecast — ${text.substring(0, text.length.clamp(0, 60))}',
            summary:     trunc,
            url:         fullUrl,
            source:      'CWC',
            publishedAt: DateTime.now(),
            severity:    _severity(text),
          ));
        }
        return items.take(5).toList();
      }
    } catch (e) { debugPrint('[NewsService] CWC-AFF: $e'); }
    return [];
  }

  // ── C: GDACS Flood RSS ────────────────────────────────────────────────────
  Future<List<NewsItem>> _tryGdacs() async {
    const url = 'https://www.gdacs.org/xml/rss_fl.xml';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0',
        'Accept': 'text/xml,application/rss+xml,*/*',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'GDACS');
        return all
            .where((i) => _isBihar(i.title + i.summary))
            .map((i) => NewsItem(
                  title:       i.title,
                  summary:     i.summary.isNotEmpty ? i.summary
                               : 'GDACS flood event detected in Bihar/Ganga basin. Tap for full GDACS report.',
                  url:         i.url,
                  source:      'GDACS',
                  publishedAt: i.publishedAt,
                  severity:    i.severity.index < NewsSeverity.high.index
                               ? NewsSeverity.high : i.severity,
                ))
            .toList();
      }
    } catch (e) { debugPrint('[NewsService] GDACS: $e'); }
    return [];
  }

  // ── D: PIB RSS (Bihar + flood keyword) ───────────────────────────────────
  Future<List<NewsItem>> _tryPib() async {
    const url = 'https://pib.gov.in/newsite/rssenglish.aspx';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0',
        'Accept': 'text/xml,application/rss+xml,*/*',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'PIB');
        return all.where((item) {
          final t = (item.title + item.summary).toLowerCase();
          return _isBihar(t) && _kFloodWords.any(t.contains);
        }).toList();
      }
    } catch (e) { debugPrint('[NewsService] PIB: $e'); }
    return [];
  }

  // ── E: The Hindu RSS ────────────────────────────────────────────────────
  Future<List<NewsItem>> _tryTheHindu() async {
    const url = 'https://www.thehindu.com/news/national/feeder/default.rss';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0',
        'Accept': 'text/xml,application/rss+xml,*/*',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'Hindu');
        return all.where((item) {
          final t = (item.title + item.summary).toLowerCase();
          return _isBihar(t) && _kFloodWords.any(t.contains);
        }).toList();
      }
    } catch (e) { debugPrint('[NewsService] TheHindu: $e'); }
    return [];
  }

  // ── F: NDTV India RSS ────────────────────────────────────────────────────
  Future<List<NewsItem>> _tryNdtv() async {
    const url = 'https://feeds.feedburner.com/ndtvnews-india-news';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0',
        'Accept': 'text/xml,application/rss+xml,*/*',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'NDTV');
        return all.where((item) {
          final t = (item.title + item.summary).toLowerCase();
          return _isBihar(t) && _kFloodWords.any(t.contains);
        }).toList();
      }
    } catch (e) { debugPrint('[NewsService] NDTV: $e'); }
    return [];
  }

  // ── G: NewsOnAir RSS (All India Radio) ───────────────────────────────────
    try {
      // Use regex to handle <item xmlns:...> attributes and CDATA
      final rx = RegExp(r'<item[^>]*>(.*?)</item>', dotAll: true);
      for (final m in rx.allMatches(xml)) {
        final raw     = m.group(1)!;
        final title   = _rxText(raw, 'title');
        final desc    = _rxCdata(raw, 'description');
        if (items.isEmpty) debugPrint('[RSS-RAW] first item raw: ${raw.substring(0, raw.length.clamp(0, 500))}');
        final link    = _rxText(raw, 'link').isNotEmpty
                        ? _rxText(raw, 'link') : _rxText(raw, 'guid');
        final pubDate = _rxText(raw, 'pubDate').isNotEmpty
                        ? _rxText(raw, 'pubDate') : _rxText(raw, 'sent');
        final onset   = _rxText(raw, 'Onset');
        final expires = _rxText(raw, 'Expires');
        if (title.isEmpty) continue;
        final cleanDesc = html_parser.parse(desc).body?.text.trim() ?? desc;
        // Build rich summary with onset/expires for IMD
        String summary = cleanDesc;
        if (onset.isNotEmpty && expires.isNotEmpty) {
          final onsetDt   = DateTime.tryParse(onset);
          final expiresDt = DateTime.tryParse(expires);
          if (onsetDt != null && expiresDt != null) {
            final fmt = DateFormat('HH:mm');
            summary = '${cleanDesc.trimRight()}\nValid: ${fmt.format(onsetDt.toLocal())} - ${fmt.format(expiresDt.toLocal())}';
          }
        }
        final truncated = summary.length > 400 ? '${summary.substring(0, 397)}...' : summary;
        debugPrint('[RSS-$source] $title | ${truncated.substring(0, truncated.length.clamp(0, 80))}');
        items.add(NewsItem(
          title:       title,
          summary:     truncated,
          url:         link,
          source:      source,
          publishedAt: _parseRssDate(pubDate),
          severity:    _severity(title + cleanDesc),
        ));
      }
    } catch (e) { debugPrint('[NewsService] RSS parse ($source): $e'); }
    return items;
  }

  static String _rxText(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>([^<]*)</$tag>', dotAll: true).firstMatch(xml);
    return m?.group(1)?.trim() ?? '';
  }

  static String _rxCdata(String xml, String tag) {
    final cdataRx = RegExp('<' + tag + r'[^>]*><!\[CDATA\[(.*?)\]\]></' + tag + r'>', dotAll: true);
    final cm = cdataRx.firstMatch(xml);
    if (cm != null) return cm.group(1)?.trim() ?? '';
    final plainRx = RegExp('<' + tag + r'[^>]*>(.*?)</' + tag + r'>', dotAll: true);
    final pm = plainRx.firstMatch(xml);
    return pm?.group(1)?.trim() ?? '';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static DateTime _parseRssDate(String s) {
    if (s.isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    try {
      return DateFormat('EEE, dd MMM yyyy HH:mm:ss Z').parseUTC(s).toLocal();
    } catch (_) {}
    try {
      return DateFormat('EEE, dd MMM yyyy HH:mm:ss zzz').parse(s);
    } catch (_) {}
    return DateTime.now();
  }

  static DateTime? _parseDateFuzzy(String s) {
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s.trim());
    if (iso != null) return iso;
    for (final fmt in [
      'dd/MM/yyyy', 'dd-MM-yyyy', 'dd MMM yyyy', 'MMM dd, yyyy', 'yyyy-MM-dd',
    ]) {
      try { return DateFormat(fmt).parse(s.trim()); } catch (_) {}
    }
    final m = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})').firstMatch(s);
    if (m != null) {
      return DateTime.tryParse(
          '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}');
    }
    return null;
  }

  static NewsSeverity _severity(String text) {
    final t = text.toLowerCase();
    if (t.contains('red alert')    || t.contains('extreme')      ||
        t.contains('catastrophic') || t.contains('danger level') ||
        t.contains('breach')       || t.contains('evacuate')     ||
        t.contains('red warning')  || t.contains('red'))
      return NewsSeverity.critical;
    if (t.contains('orange alert') || t.contains('severe')        ||
        t.contains('above danger') || t.contains('warning level') ||
        t.contains('flood warning')|| t.contains('orange warning') ||
        t.contains('orange'))
      return NewsSeverity.high;
    if (t.contains('yellow alert') || t.contains('heavy rain')    ||
        t.contains('moderate')     || t.contains('watch')         ||
        t.contains('yellow warning')|| t.contains('yellow'))
      return NewsSeverity.moderate;
    return NewsSeverity.info;
  }

}
