// lib/providers/sos_provider.dart  v2.0
//
// v2.0 (14 Jun 2026) — district field in SosState, callContact returns bool

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sos_service.dart';

enum SosPhase { idle, confirming, sending, sent, failed }

class SosState {
  final SosPhase phase;
  final double? lat;
  final double? lng;
  final String? district; // Bihar district detected from GPS
  final String? errorMessage;

  const SosState({
    this.phase = SosPhase.idle,
    this.lat,
    this.lng,
    this.district,
    this.errorMessage,
  });

  SosState copyWith({
    SosPhase? phase,
    double? lat,
    double? lng,
    String? district,
    String? errorMessage,
  }) =>
      SosState(
        phase: phase ?? this.phase,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        district: district ?? this.district,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class SosNotifier extends Notifier<SosState> {
  final _service = SosService();

  @override
  SosState build() => const SosState();

  void startConfirming() {
    if (state.phase != SosPhase.idle) return;
    state = state.copyWith(phase: SosPhase.confirming);
  }

  void cancelConfirm() {
    if (state.phase == SosPhase.confirming) {
      state = state.copyWith(phase: SosPhase.idle);
    }
  }

  Future<void> confirm() async {
    if (state.phase != SosPhase.confirming) return;
    state = state.copyWith(phase: SosPhase.sending);

    final result = await _service.dispatch();
    if (result is SosSuccess) {
      state = SosState(
        phase: SosPhase.sent,
        lat: result.lat,
        lng: result.lng,
        district: result.district,
      );
    } else {
      state = SosState(
        phase: SosPhase.failed,
        errorMessage: (result as SosFailure).reason,
      );
    }
  }

  void reset() => state = const SosState();

  /// Returns true if call was launched, false if dialler unavailable.
  Future<bool> callContact(EmergencyContact c) => _service.call(c);
}

final sosProvider = NotifierProvider<SosNotifier, SosState>(SosNotifier.new);
