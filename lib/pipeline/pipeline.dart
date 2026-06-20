// lib/pipeline/pipeline.dart  — BARREL EXPORT
//
// Single import for the entire unified pipeline:
//   import 'pipeline/pipeline.dart';
//
// Then in main.dart:
//   await Orchestrator.instance.start();

export 'm0_canonical_model.dart';
export 'm1_source_registry.dart' show SourceRegistry, SourceResult;
export 'm2_normaliser.dart'      show Normaliser;
export 'm3_merger.dart'          show Merger;
export 'm4_enricher.dart'        show Enricher;
export 'm5_orchestrator.dart'    show Orchestrator;
export 'm6_adapters.dart';
