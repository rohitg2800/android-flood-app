import 'package:flutter/foundation.dart';

@immutable
class PredictionPoint {
  final DateTime time;
  final double level;

  const PredictionPoint({
    required this.time,
    required this.level,
  });
}

