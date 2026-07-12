// lib/services/fcm_templates.dart  v2
// Fixed: buildPayload() switch covers all 14 AlertType values + default.
import 'alert_engine.dart';

class FcmPayload {
  final String title;
  final String body;
  final Map<String, String> data;
  const FcmPayload(
      {required this.title, required this.body, required this.data});
}

class FcmTemplates {
  FcmTemplates._();
  static final FcmTemplates instance = FcmTemplates._();

  FcmPayload buildPayload(FloodAlert alert) {
    final cur = alert.currentLevel.toStringAsFixed(2);
    final thr = alert.thresholdLevel.toStringAsFixed(2);
    final dl = alert.dangerLevel.toStringAsFixed(2);
    final riv = alert.river;
    final sta = alert.stationName;
    final dist = alert.district;

    final String title;
    final String body;

    switch (alert.type) {
      case AlertType.levelAboveHfl:
        title = '\u{1F6A8} HFL EXCEEDED — $sta';
        body =
            '$riv at $sta has exceeded HFL ($thr m). Current: $cur m. EVACUATE NOW.';
        break;
      case AlertType.levelAboveDanger:
        title = '\u{1F534} ABOVE DANGER — $sta';
        body = '$riv ($dist) above danger level $dl m. Current: $cur m.';
        break;
      case AlertType.levelAboveWarning:
        title = '\u26A0\uFE0F ABOVE WARNING — $sta';
        body =
            '$riv ($dist) crossed warning level. Current: $cur m (Threshold: $thr m).';
        break;
      case AlertType.rapidRise:
        final ror = alert.rateOfRiseMph != null
            ? '+${alert.rateOfRiseMph!.toStringAsFixed(2)} m/h'
            : 'rapid';
        title = '\u{1F4C8} RAPID RISE — $sta';
        body = '$riv ($dist) rising at $ror. Current: $cur m. Monitor closely.';
        break;
      case AlertType.forecastDanger24h:
        title = '\u{1F52E} FORECAST 24H — $sta';
        body =
            '$riv forecast to hit danger ($dl m) within 24h. Prepare evacuations.';
        break;
      case AlertType.forecastDanger48h:
        title = '\u{1F52E} FORECAST 48H — $sta';
        body = '$riv forecast to hit danger ($dl m) within 48h. Stay on alert.';
        break;
      case AlertType.rainfallExtreme:
        final rain = alert.rainfall24hMm != null
            ? '${alert.rainfall24hMm!.toStringAsFixed(1)} mm'
            : '>100 mm';
        title = '\u{1F327} EXTREME RAINFALL — $dist';
        body =
            'Extreme rainfall ($rain / 24h) near $sta. Flood risk VERY HIGH.';
        break;
      case AlertType.rainfallHeavy:
        final rain = alert.rainfall24hMm != null
            ? '${alert.rainfall24hMm!.toStringAsFixed(1)} mm'
            : '>64.5 mm';
        title = '\u{1F327} HEAVY RAINFALL — $dist';
        body = 'Heavy rainfall ($rain / 24h) near $sta. Flood risk elevated.';
        break;
      case AlertType.upstreamCritical:
        title = '\u{1F6A8} UPSTREAM CRITICAL — $riv';
        body =
            'Multiple $riv stations above danger. Downstream breach imminent. Act now.';
        break;
      case AlertType.multiRiverAlert:
        title = '\u{1F6A8} MULTI-RIVER CRISIS';
        body = '3+ rivers above warning level. State emergency. Stay safe.';
        break;
      case AlertType.breach:
        title = '\u{1F534} BREACH — $sta';
        body =
            '$riv has breached danger level at $sta. Current: $cur m (Danger: $dl m).';
        break;
      case AlertType.approaching:
        title = '\u26A0\uFE0F APPROACHING — $sta';
        body = '$riv approaching danger at $sta. Current: $cur m. Stay alert.';
        break;
      case AlertType.forecast:
        title = '\u{1F52E} FORECAST ALERT — $sta';
        body = '$riv forecast to rise further. Current: $cur m.';
        break;
      case AlertType.custom:
        title = '\u{1F514} CUSTOM ALERT — $sta';
        body = '$riv crossed custom threshold ($thr m). Current: $cur m.';
        break;
    }

    return FcmPayload(
      title: title,
      body: body,
      data: {
        'alertId': alert.id,
        'stationName': sta,
        'river': riv,
        'district': dist,
        'severity': alert.severity.name,
        'type': alert.type.name,
        'currentLevel': cur,
        'dangerLevel': dl,
        'thresholdLevel': thr,
        'issuedAt': alert.issuedAt.toIso8601String(),
        if (alert.state != null) 'state': alert.state!,
        if (alert.expiresAt != null)
          'expiresAt': alert.expiresAt!.toIso8601String(),
        if (alert.action != null) 'action': alert.action!,
      },
    );
  }

  /// Build a compact single-line push subtitle for wearables / lock screens.
  String buildShortLine(FloodAlert alert) =>
      '${alert.type.label}: ${alert.stationName} (${alert.river}) '
      '— ${alert.severity.label}';

  /// Build a topic string for FCM topic messaging.
  static String topicFor(FloodAlert alert) {
    final state = (alert.state ?? 'india').toLowerCase().replaceAll(' ', '_');
    return 'flood_${state}_${alert.severity.name}';
  }
}
