/// Mirrors the source_policy object returned by /health.
class SourcePolicy {
  final String mode;
  final String label;
  final String description;
  final bool allowLiveCwcInApp;
  final String telemetryMode;
  final String predictionDataSource;
  final List<PublicSource> publicSources;

  const SourcePolicy({
    required this.mode,
    required this.label,
    required this.description,
    required this.allowLiveCwcInApp,
    required this.telemetryMode,
    required this.predictionDataSource,
    required this.publicSources,
  });

  factory SourcePolicy.fromJson(Map<String, dynamic> json) => SourcePolicy(
        mode: json['mode'] as String? ?? 'unknown',
        label: json['label'] as String? ?? 'Unknown Policy',
        description: json['description'] as String? ?? '',
        allowLiveCwcInApp: json['allow_live_cwc_in_app'] as bool? ?? false,
        telemetryMode: json['telemetry_mode'] as String? ?? 'unknown',
        predictionDataSource:
            json['prediction_data_source'] as String? ?? 'unknown',
        publicSources: (json['public_sources'] as List<dynamic>? ?? [])
            .map((e) => PublicSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Safe fallback when /health is unreachable.
  factory SourcePolicy.fallback() => const SourcePolicy(
        mode: 'offline',
        label: 'Server Unreachable',
        description: 'Could not read policy from backend.',
        allowLiveCwcInApp: false,
        telemetryMode: 'fallback',
        predictionDataSource: 'offline',
        publicSources: [],
      );
}

class PublicSource {
  final String label;
  final String title;
  final String url;
  final String usage;

  const PublicSource({
    required this.label,
    required this.title,
    required this.url,
    required this.usage,
  });

  factory PublicSource.fromJson(Map<String, dynamic> json) => PublicSource(
        label: json['label'] as String? ?? '',
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        usage: json['usage'] as String? ?? '',
      );
}
