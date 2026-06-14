// lib/providers/sos_provider.dart
// Phase 5 — SOS State Management
//
// SosPhase tracks the lifecycle:
//   idle       → user has not started SOS
//   confirming → hold-guard is counting down (0–3 s)
//   sending    → awaiting GPS + SMS/call launch
//   sent       → successfully dispatched
//   failed     → SosService returned SosFailure

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sos_service.dart';

enum SosPhase { idle, confirming, sending, sent, failed }

class SosState {
  final SosPhase phase;
  final double?  lat;
  final double?  lng;
  final String?  errorMessage;

  const SosState({
    this.phase        = SosPhase.idle,
    this.lat,
    this.lng,
    this.errorMessage,
  });

  SosState copyWith({
    SosPhase? phase,
    double?   lat,
    double?   lng,
    String?   errorMessage,
  }) =>
      SosState(
        phase:        phase        ?? this.phase,
        lat:          lat          ?? this.lat,
        lng:          lng          ?? this.lng,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class SosNotifier extends StateNotifier<SosState> {
  SosNotifier() : super(const SosState());

  final _service = SosService();

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
        lat:   result.lat,
        lng:   result.lng,
      );
    } else {
      state = SosState(
        phase:        SosPhase.failed,
        errorMessage: (result as SosFailure).reason,
      );
    }
  }

  void reset() => state = const SosState();

  Future<void> callContact(EmergencyContact c) =>
      _service.call(c);
}

final sosProvider =
    StateNotifierProvider<SosNotifier, SosState>(
        (_) => SosNotifier());
