// lib/services/alert_share_service.dart  v2.2  (share_plus ^10 compat)
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'alert_engine.dart';

class AlertMessage {
  final String combined;
  final String english;
  final String hindi;
  final String shortLine;
  const AlertMessage({
    required this.combined,
    required this.english,
    required this.hindi,
    required this.shortLine,
  });
}

class AlertShareService {
  AlertShareService._();
  static final AlertShareService instance = AlertShareService._();

  // ── Static convenience wrappers used by alert_share_button.dart ──────
  static String buildEnglishMessage(FloodAlert alert) =>
      instance.buildMessage(alert).english;
  static String buildHindiMessage(FloodAlert alert) =>
      instance.buildMessage(alert).hindi;
  // Fix: return Future<bool> so callers can use the result
  static Future<bool> shareViaWhatsApp(FloodAlert alert) =>
      instance._shareViaWhatsApp(alert);
  static Future<void> shareGeneric({required String message}) =>
      Share.share(message);

  AlertMessage buildMessage(FloodAlert alert) {
    final sev   = alert.severity;
    final type  = alert.type;
    final sta   = alert.station;
    final river = alert.river;
    final dist  = alert.district;
    final cur   = alert.currentLevel.toStringAsFixed(2);
    final thr   = alert.thresholdLevel.toStringAsFixed(2);
    final ror   = alert.rateOfRise != null
        ? '+${alert.rateOfRise!.toStringAsFixed(2)} m/h' : null;
    final rain  = alert.rainfall24h != null
        ? '${alert.rainfall24h!.toStringAsFixed(1)} mm' : null;
    final ts  = _timestamp();
    final src = '🔗 OpsFlood Bihar Flood Intelligence';
    final app = 'https://opsflood.app';

    final String sevPrefixEn, sevPrefixHi, emoji;
    switch (sev) {
      case AlertSeverity.emergency:
        sevPrefixEn = '🚨 EMERGENCY FLOOD ALERT';
        sevPrefixHi = '🚨 आपातकालीन बाढ़ अलर्ट'; emoji = '🚨'; break;
      case AlertSeverity.critical:
        sevPrefixEn = '🔴 CRITICAL FLOOD ALERT';
        sevPrefixHi = '🔴 गंभीर बाढ़ अलर्ट'; emoji = '🔴'; break;
      case AlertSeverity.warning:
        sevPrefixEn = '⚠️ FLOOD WARNING';
        sevPrefixHi = '⚠️ बाढ़ चेतावनी'; emoji = '⚠️'; break;
      case AlertSeverity.info:
        sevPrefixEn = 'ℹ️ FLOOD ADVISORY';
        sevPrefixHi = 'ℹ️ बाढ़ सूचना'; emoji = 'ℹ️'; break;
    }

    final String bodyEn, bodyHi;
    switch (type) {
      case AlertType.levelAboveHfl:
        bodyEn = 'Water level at $sta ($river, $dist) has exceeded the HIGHEST FLOOD LEVEL (HFL).\nCurrent: $cur m  |  HFL: $thr m\n🟥 IMMEDIATE EVACUATION required.';
        bodyHi = '$sta ($river, $dist) में जलस्तर HFL से ऊपर।\nवर्तमान: $cur मी।  |  HFL: $thr मी।\n🟥 तत्काल निकासी आवश्यक।'; break;
      case AlertType.levelAboveDanger:
        bodyEn = 'Water level at $sta ($river, $dist) is ABOVE DANGER LEVEL.\nCurrent: $cur m  |  Danger: $thr m';
        bodyHi = '$sta ($river, $dist) में जलस्तर खतरे की सीमा से ऊपर।\nवर्तमान: $cur मी।  |  खतरा: $thr मी।'; break;
      case AlertType.levelAboveWarning:
        bodyEn = 'Water level at $sta ($river, $dist) crossed WARNING LEVEL.\nCurrent: $cur m  |  Warning: $thr m';
        bodyHi = '$sta ($river, $dist) में जलस्तर चेतावनी स्तर पार।\nवर्तमान: $cur मी।  |  चेतावनी: $thr मी।'; break;
      case AlertType.rapidRise:
        final rorStr = ror ?? 'तीव्र';
        bodyEn = 'RAPID RISE at $sta ($river, $dist). Rate: ${ror ?? "rapid"}';
        bodyHi = '$sta ($river, $dist) में तेज वृद्धि। दर: $rorStr'; break;
      case AlertType.forecastDanger24h:
        bodyEn = 'FORECAST: $sta danger level in 24h. Forecast: $cur m  |  Danger: $thr m';
        bodyHi = 'पूर्वानुमान: $sta 24 घंटे में खतरे की सीमा पार कर सकता है।'; break;
      case AlertType.forecastDanger48h:
        bodyEn = 'FORECAST: $sta may reach danger in 48h. Forecast: $cur m  |  Danger: $thr m';
        bodyHi = 'पूर्वानुमान: $sta 48 घंटे में खतरे की सीमा पार कर सकता है।'; break;
      case AlertType.rainfallExtreme:
        bodyEn = 'EXTREME RAINFALL near $sta ($dist). 24h: ${rain ?? ">100 mm"}';
        bodyHi = '$sta ($dist) के पास अत्यधिक वर्षा। 24 घंटे: ${rain ?? ">100 ममी"}'; break;
      case AlertType.rainfallHeavy:
        bodyEn = 'HEAVY RAINFALL near $sta ($dist). 24h: ${rain ?? ">64.5 mm"}';
        bodyHi = '$sta ($dist) के पास भारी वर्षा। 24 घंटे: ${rain ?? ">64.5 ममी"}'; break;
      case AlertType.upstreamCritical:
        bodyEn = 'UPSTREAM CRITICAL: Multiple $river stations above danger. Downstream breach risk HIGH.';
        bodyHi = 'अपस्ट्रीम आपात: $river पर कई स्थान खतरे की सीमा से ऊपर।'; break;
      case AlertType.multiRiverAlert:
        bodyEn = 'MULTI-RIVER CRISIS: 3+ rivers above warning. State emergency.';
        bodyHi = 'बिहार में 3+ नदियाँ चेतावनी स्तर से ऊपर। राज्यव्यापी आपात।'; break;
    }

    final footer = '⏱ $ts\n$src\n$app';
    final english  = '$sevPrefixEn\n\n$bodyEn\n\n$footer';
    final hindi    = '$sevPrefixHi\n\n$bodyHi\n\n$footer';
    final combined = '$english\n\n────────────────────\n\n$hindi';
    final shortLine = '$emoji ${type.label}: $sta ($river) — ${sev.label.toUpperCase()}';

    return AlertMessage(combined: combined, english: english, hindi: hindi, shortLine: shortLine);
  }

  Future<void> shareViaSheet(FloodAlert alert) async {
    final msg = buildMessage(alert);
    await Share.share(msg.combined, subject: msg.shortLine);
  }

  Future<bool> _shareViaWhatsApp(FloodAlert alert) async {
    final msg     = buildMessage(alert);
    final encoded = Uri.encodeComponent(msg.combined);
    final uri     = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    final webUri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Future<void> copyToClipboard(FloodAlert alert) async {
    final msg = buildMessage(alert);
    await Clipboard.setData(ClipboardData(text: msg.combined));
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2,'0')}-'
        '${now.month.toString().padLeft(2,'0')}-'
        '${now.year}  '
        '${now.hour.toString().padLeft(2,'0')}:'
        '${now.minute.toString().padLeft(2,'0')} IST';
  }
}
