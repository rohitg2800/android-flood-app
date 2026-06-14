// lib/providers/silent_tile_provider.dart
// OpsFlood — SilentTileProvider v2
//
// Wraps NetworkTileProvider with an http.Client that injects a synthetic
// `Cache-Control: max-age=<N>` header into every tile *response* before
// flutter_map_tile_caching reads it.  This prevents the log spam:
//
//   [flutter_map] Using fallback freshness age (168:00:00.000000) to cache …
//     This indicates the tile server did not send enough information …
//
// The tile server (e.g. RainViewer nowcast) never sends Cache-Control or
// Expires, so without this the caching layer always falls back to 168 h
// and logs a warning for every single tile.
library;

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// _InjectingClient — wraps any http.Client and adds headers to responses
// ---------------------------------------------------------------------------

class _InjectingClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _inject;

  _InjectingClient(this._inner, this._inject);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final merged = Map<String, String>.from(response.headers)
      ..addAll(_inject);
    return http.StreamedResponse(
      response.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request:       response.request,
      headers:       merged,
      isRedirect:    response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase:  response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// ---------------------------------------------------------------------------
// SilentTileProvider
// ---------------------------------------------------------------------------

/// A [TileProvider] for tile servers that omit caching response headers.
///
/// It injects a synthetic `Cache-Control: max-age=<seconds>` into every
/// tile response so [flutter_map_tile_caching] can compute a real freshness
/// age without falling back to its 168 h default.
///
/// Usage:
/// ```dart
/// tileProvider: SilentTileProvider(
///   maxAge: const Duration(minutes: 10),
/// ),
/// ```
class SilentTileProvider extends NetworkTileProvider {
  SilentTileProvider({
    Duration maxAge = const Duration(minutes: 10),
    Map<String, String>? headers,
  }) : super(
          headers: headers ?? const {},
          httpClient: _InjectingClient(
            http.Client(),
            {'cache-control': 'max-age=${maxAge.inSeconds}'},
          ),
        );
}
