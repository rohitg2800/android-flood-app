// lib/services/alert_share_service.dart  v2.3  (exhaustive switch fixed)
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

  static String buildEnglishMessage(FloodAlert alert) =>
      instance.buildMessage(alert).english;
  static String buildHindiMessage(FloodAlert alert) =>
      instance.buildMessage(alert).hindi;
  static Future<bool> shareViaWhatsApp(FloodAlert alert) =>
      instance._shareViaWhatsApp(alert);
  static Future<void> shareGeneric({required String message}) =>
      Share.share(message);

  AlertMessage buildMessage(FloodAlert alert) {
    final sev   = alert.severity;
    final type  = alert.type;
    final sta   = alert.station ?? alert.stationName;
    final river = alert.river;
    final dist  = alert.district;
    final cur   = alert.currentLevel.toStringAsFixed(2);
    final thr   = alert.thresholdLevel.toStringAsFixed(2);
    final ror   = alert.rateOfRise != null
        ? '+${alert.rateOfRise!.toStringAsFixed(2)} m/h' : null;
    final rain  = alert.rainfall24h != null
        ? '${alert.rainfall24h!.toStringAsFixed(1)} mm' : null;
    final ts    = _timestamp();
    final src   = '\uD83D\uDD17 OpsFlood Bihar Flood Intelligence';
    final app   = 'https://opsflood.app';

    final String sevPrefixEn, sevPrefixHi, emoji;
    switch (sev) {
      case AlertSeverity.emergency:
        sevPrefixEn = '\u{1F6A8} EMERGENCY FLOOD ALERT';
        sevPrefixHi = '\u{1F6A8} \u0906\u092A\u093E\u0924\u0915\u093E\u0932\u0940\u0928 \u092C\u093E\u0922\u093C \u0905\u0932\u0930\u094D\u091F';
        emoji = '\u{1F6A8}'; break;
      case AlertSeverity.critical:
        sevPrefixEn = '\uD83D\uDD34 CRITICAL FLOOD ALERT';
        sevPrefixHi = '\uD83D\uDD34 \u0917\u0902\u092D\u0940\u0930 \u092C\u093E\u0922\u093C \u0905\u0932\u0930\u094D\u091F';
        emoji = '\uD83D\uDD34'; break;
      case AlertSeverity.warning:
        sevPrefixEn = '\u26A0\uFE0F FLOOD WARNING';
        sevPrefixHi = '\u26A0\uFE0F \u092C\u093E\u0922\u093C \u091A\u0947\u0924\u093E\u0935\u0928\u0940';
        emoji = '\u26A0\uFE0F'; break;
      case AlertSeverity.info:
        sevPrefixEn = '\u2139\uFE0F FLOOD ADVISORY';
        sevPrefixHi = '\u2139\uFE0F \u092C\u093E\u0922\u093C \u0938\u0942\u091A\u0928\u093E';
        emoji = '\u2139\uFE0F'; break;
    }

    final String bodyEn, bodyHi;
    switch (type) {
      case AlertType.levelAboveHfl:
        bodyEn = 'Water level at $sta ($river, $dist) has exceeded HFL.\nCurrent: $cur m  |  HFL: $thr m\n\uD83D\uDFE5 IMMEDIATE EVACUATION required.';
        bodyHi = '$sta ($river, $dist) \u092E\u0947\u0902 \u091C\u0932\u0938\u094D\u0924\u0930 HFL \u0938\u0947 \u0909\u092A\u0930\u0964\n\u0935\u0930\u094D\u0924\u092E\u093E\u0928: $cur \u092E\u0940\u0964  |  HFL: $thr \u092E\u0940\u0964\n\uD83D\uDFE5 \u0924\u0924\u094D\u0915\u093E\u0932 \u0928\u093F\u0915\u093E\u0938\u0940 \u0906\u0935\u0936\u094D\u092F\u0915\u0964'; break;
      case AlertType.levelAboveDanger:
        bodyEn = 'Water level at $sta ($river, $dist) is ABOVE DANGER LEVEL.\nCurrent: $cur m  |  Danger: $thr m';
        bodyHi = '$sta ($river, $dist) \u092E\u0947\u0902 \u091C\u0932\u0938\u094D\u0924\u0930 \u0916\u0924\u0930\u0947 \u0915\u0940 \u0938\u0940\u092E\u093E \u0938\u0947 \u0909\u092A\u0930\u0964\n\u0935\u0930\u094D\u0924\u092E\u093E\u0928: $cur \u092E\u0940\u0964  |  \u0916\u0924\u0930\u093E: $thr \u092E\u0940\u0964'; break;
      case AlertType.levelAboveWarning:
        bodyEn = 'Water level at $sta ($river, $dist) crossed WARNING LEVEL.\nCurrent: $cur m  |  Warning: $thr m';
        bodyHi = '$sta ($river, $dist) \u092E\u0947\u0902 \u091C\u0932\u0938\u094D\u0924\u0930 \u091A\u0947\u0924\u093E\u0935\u0928\u0940 \u0938\u094D\u0924\u0930 \u092A\u093E\u0930\u0964\n\u0935\u0930\u094D\u0924\u092E\u093E\u0928: $cur \u092E\u0940\u0964  |  \u091A\u0947\u0924\u093E\u0935\u0928\u0940: $thr \u092E\u0940\u0964'; break;
      case AlertType.rapidRise:
        bodyEn = 'RAPID RISE at $sta ($river, $dist). Rate: ${ror ?? "rapid"}';
        bodyHi = '$sta ($river, $dist) \u092E\u0947\u0902 \u0924\u0947\u091C \u0935\u0943\u0926\u094D\u0927\u093F\u0964 \u0926\u0930: ${ror ?? "\u0924\u0940\u0935\u094D\u0930"}'; break;
      case AlertType.forecastDanger24h:
        bodyEn = 'FORECAST: $sta danger level in 24h. Forecast: $cur m  |  Danger: $thr m';
        bodyHi = '\u092A\u0942\u0930\u094D\u0935\u093E\u0928\u0941\u092E\u093E\u0928: $sta 24 \u0918\u0902\u091F\u0947 \u092E\u0947\u0902 \u0916\u0924\u0930\u0947 \u0915\u0940 \u0938\u0940\u092E\u093E \u092A\u093E\u0930 \u0915\u0930 \u0938\u0915\u0924\u093E \u0939\u0948\u0964'; break;
      case AlertType.forecastDanger48h:
        bodyEn = 'FORECAST: $sta may reach danger in 48h. Forecast: $cur m  |  Danger: $thr m';
        bodyHi = '\u092A\u0942\u0930\u094D\u0935\u093E\u0928\u0941\u092E\u093E\u0928: $sta 48 \u0918\u0902\u091F\u0947 \u092E\u0947\u0902 \u0916\u0924\u0930\u0947 \u0915\u0940 \u0938\u0940\u092E\u093E \u092A\u093E\u0930 \u0915\u0930 \u0938\u0915\u0924\u093E \u0939\u0948\u0964'; break;
      case AlertType.rainfallExtreme:
        bodyEn = 'EXTREME RAINFALL near $sta ($dist). 24h: ${rain ?? ">100 mm"}';
        bodyHi = '$sta ($dist) \u0915\u0947 \u092A\u093E\u0938 \u0905\u0924\u094D\u092F\u0927\u093F\u0915 \u0935\u0930\u094D\u0937\u093E\u0964 24 \u0918\u0902\u091F\u0947: ${rain ?? ">100 \u092E\u092E\u0940"}'; break;
      case AlertType.rainfallHeavy:
        bodyEn = 'HEAVY RAINFALL near $sta ($dist). 24h: ${rain ?? ">64.5 mm"}';
        bodyHi = '$sta ($dist) \u0915\u0947 \u092A\u093E\u0938 \u092D\u093E\u0930\u0940 \u0935\u0930\u094D\u0937\u093E\u0964 24 \u0918\u0902\u091F\u0947: ${rain ?? ">64.5 \u092E\u092E\u0940"}'; break;
      case AlertType.upstreamCritical:
        bodyEn = 'UPSTREAM CRITICAL: Multiple $river stations above danger. Downstream breach risk HIGH.';
        bodyHi = '\u0905\u092A\u0938\u094D\u091F\u094D\u0930\u0940\u092E \u0906\u092A\u093E\u0924: $river \u092A\u0930 \u0915\u0908 \u0938\u094D\u0925\u093E\u0928 \u0916\u0924\u0930\u0947 \u0915\u0940 \u0938\u0940\u092E\u093E \u0938\u0947 \u0909\u092A\u0930\u0964'; break;
      case AlertType.multiRiverAlert:
        bodyEn = 'MULTI-RIVER CRISIS: 3+ rivers above warning. State emergency.';
        bodyHi = '\u092C\u093F\u0939\u093E\u0930 \u092E\u0947\u0902 3+ \u0928\u0926\u093F\u092F\u093E\u0901 \u091A\u0947\u0924\u093E\u0935\u0928\u0940 \u0938\u094D\u0924\u0930 \u0938\u0947 \u0909\u092A\u0930\u0964 \u0930\u093E\u091C\u094D\u092F\u0935\u094D\u092F\u093E\u092A\u0940 \u0906\u092A\u093E\u0924\u0964'; break;
      default:
        bodyEn = alert.message;
        bodyHi = alert.message;
    }

    final footer   = '\u23F1 $ts\n$src\n$app';
    final english  = '$sevPrefixEn\n\n$bodyEn\n\n$footer';
    final hindi    = '$sevPrefixHi\n\n$bodyHi\n\n$footer';
    final combined = '$english\n\n\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n\n$hindi';
    final shortLine = '$emoji ${type.label}: $sta ($river) \u2014 ${sev.label.toUpperCase()}';

    return AlertMessage(
        combined: combined, english: english,
        hindi: hindi, shortLine: shortLine);
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
