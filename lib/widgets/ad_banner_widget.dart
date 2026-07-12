// lib/widgets/ad_banner_widget.dart
// OpsFlood — Reusable AdMob banner widget
//
// Usage:
//   AdBannerWidget()   ← drop anywhere in a Column/Sliver
//
// Test unit ID is used by default (safe for debug builds).
// Before publishing to Play Store, replace kAdUnitId with
// your real unit ID from AdMob console.

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/river_theme.dart';

// ── Ad Unit IDs ────────────────────────────────────────────────────────────
// Google's official test banner ID — will NOT generate real revenue.
// Replace with your real ca-app-pub-XXXX/XXXX ID before Play Store release.
const String kAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _ad;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: kAdUnitId,
      size: AdSize.banner, // 320×50 — non-intrusive
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob banner failed: $error');
          ad.dispose();
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _ad == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      clipBehavior: Clip.hardEdge,
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
