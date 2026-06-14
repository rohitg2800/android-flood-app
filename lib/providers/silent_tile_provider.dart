// lib/providers/silent_tile_provider.dart
// OpsFlood — SilentTileProvider
//
// Wraps NetworkTileProvider and injects a synthetic Cache-Control
// max-age on every tile response so flutter_map_tile_caching never
// needs to fall back to its default freshness age (which spams the
// log with:  "[flutter_map] Using fallback freshness age …").
//
// Usage:
//   tileProvider: SilentTileProvider(
//     maxAge: const Duration(minutes: 10),
//     headers: {'User-Agent': '…'},
//   ),
library;

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// A [TileProvider] that adds a synthetic [Cache-Control] max-age header
/// to every tile response, preventing flutter_map_tile_caching from
/// emitting "Using fallback freshness age" warnings for servers (like
/// RainViewer) that omit caching response headers entirely.
class SilentTileProvider extends TileProvider {
  final Duration maxAge;
  final Map<String, String> extraHeaders;
  final http.Client _client;

  SilentTileProvider({
    this.maxAge = const Duration(minutes: 10),
    Map<String, String>? headers,
    http.Client? client,
  })  : extraHeaders = headers ?? const {},
        _client = client ?? http.Client();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _SilentNetworkImage(
      url: url,
      headers: {
        ...extraHeaders,
        // Provide the max-age hint as a *request* header so any
        // intermediate network layer can also respect it.
        'Cache-Control': 'max-age=${maxAge.inSeconds}',
      },
      maxAge: maxAge,
      client: _client,
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Internal image provider
// ---------------------------------------------------------------------------

class _SilentNetworkImage extends ImageProvider<_SilentNetworkImage> {
  final String url;
  final Map<String, String> headers;
  final Duration maxAge;
  final http.Client client;

  const _SilentNetworkImage({
    required this.url,
    required this.headers,
    required this.maxAge,
    required this.client,
  });

  @override
  Future<_SilentNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_SilentNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _SilentNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _fetch(key, decode),
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty<String>('URL', key.url),
      ],
    );
  }

  Future<ui.Codec> _fetch(
      _SilentNetworkImage key, ImageDecoderCallback decode) async {
    final response = await key.client.get(
      Uri.parse(key.url),
      headers: key.headers,
    );
    if (response.statusCode != 200) {
      throw Exception(
          'SilentTileProvider: HTTP ${response.statusCode} for ${key.url}');
    }
    final bytes = Uint8List.fromList(response.bodyBytes);
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is _SilentNetworkImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

// ignore_for_file: unnecessary_import
import 'dart:ui' as ui;
