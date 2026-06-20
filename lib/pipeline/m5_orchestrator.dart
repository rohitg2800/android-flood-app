// lib/pipeline/m5_orchestrator.dart
//
// MODULE 5 — Orchestrator
// Single entry point. Owns poll timer, drives M1→M2→M3→M4,
// emits PipelineSnapshot on a broadcast stream.

library pipeline.orchestrator;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'm0_canonical_model.dart';
import 'm1_source_registry.dart';
import 'm2_normaliser.dart';
import 'm3_merger.dart';
import 'm4_enricher.dart';

class Orchestrator {
  Orchestrator._();
  static final Orchestrator instance = Orchestrator._();

  static const _kPollInterval   = Duration(minutes: 5);
  static const _kBackendPushMin = Duration(seconds: 30);
  static const _kBackendEnabled = false;

  final _controller = StreamController<PipelineSnapshot>.broadcast();
  Timer?            _timer;
  PipelineSnapshot? _latest;
  bool              _running  = false;
  Future<void>?     _inFlight;
  DateTime?         _lastPush;

  Stream<PipelineSnapshot> get stream  => _controller.stream;
  PipelineSnapshot?        get latest  => _latest;
  bool                     get running => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    debugPrint('[M5:Orchestrator] starting');
    await _runCycle();
    _timer = Timer.periodic(_kPollInterval, (_) => _runCycle());
  }

  Future<void> dispose() async {
    _running = false;
    _timer?.cancel();
    await _controller.close();
  }

  Future<PipelineSnapshot?> forceRefresh() async {
    await _runCycle();
    return _latest;
  }

  Future<void> _runCycle() async {
    if (_inFlight != null) return;
    _inFlight = _executeCycle().whenComplete(() => _inFlight = null);
    await _inFlight;
  }

  Future<void> _executeCycle() async {
    final sw = Stopwatch()..start();
    try {
      final sourceResults = await SourceRegistry.instance.fetchAll();
      final health = <String, bool>{
        for (final s in sourceResults) s.sourceName: s.healthy,
      };
      final normalised = Normaliser.instance.normalise(sourceResults);
      final merged     = Merger.instance.merge(normalised);
      final enriched   = await Enricher.instance.enrich(merged);
      sw.stop();
      final snapshot = PipelineSnapshot(
        records:      enriched,
        generatedAt:  DateTime.now(),
        cycleTime:    sw.elapsed,
        sourceHealth: health,
      );
      _latest = snapshot;
      if (!_controller.isClosed) _controller.add(snapshot);
      debugPrint('[M5:Orchestrator] cycle done \${sw.elapsedMilliseconds}ms  stations=\${enriched.length}  alerts=\${snapshot.alertingCount}');
      if (_kBackendEnabled) await _pushToBackend(snapshot);
    } catch (e, st) {
      sw.stop();
      debugPrint('[M5:Orchestrator] cycle ERROR: $e\n$st');
    }
  }

  Future<void> _pushToBackend(PipelineSnapshot snap) async {
    final now = DateTime.now();
    if (_lastPush != null && now.difference(_lastPush!) < _kBackendPushMin) return;
    _lastPush = now;
    try {
      const url = 'https://opsflood-backend.up.railway.app/api/ingest';
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'stations':    snap.toStationMaps(),
          'generatedAt': snap.generatedAt.toIso8601String(),
          'alerting':    snap.alertingCount,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) { debugPrint('[M5:Orchestrator] backend push error: $e'); }
  }
}
