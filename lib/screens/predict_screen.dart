import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../constants/bihar_constants.dart';
import '../providers/flood_providers.dart';

class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key});

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedStation = kBiharDefaultStation;
  String _selectedRiver = 'Ganga';
  double _peakLevel = 50.0;
  double _t1d = 10.0, _t2d = 15.0, _t3d = 20.0, _t4d = 18.0;
  double _t5d = 12.0, _t6d = 8.0,  _t7d = 7.0;
  double _eventDuration = 3.0;
  double _timeToPeak  = 2.0;
  double _recession   = 2.0;
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  List<String> get _stationNames =>
      kBiharStations.map((s) => s['name'] as String).toList();

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final api = ref.read(floodApiProvider);
      final res = await api.predict({
        'state':               kBiharState,
        'station':             _selectedStation,
        'Peak_Flood_Level_m':  _peakLevel,
        'Event_Duration_days': _eventDuration,
        'Time_to_Peak_days':   _timeToPeak,
        'Recession_Time_day':  _recession,
        'T1d': _t1d, 'T2d': _t2d, 'T3d': _t3d, 'T4d': _t4d,
        'T5d': _t5d, 'T6d': _t6d, 'T7d': _t7d,
      });
      setState(() { _result = res; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        backgroundColor: AppPalette.navy1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flood Prediction', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Bihar ML Model', style: TextStyle(fontSize: 12, color: AppPalette.textMuted)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Station selector
            _SectionLabel('Bihar Station'),
            _BiharStationDropdown(
              value: _selectedStation,
              stations: _stationNames,
              onChanged: (v) => setState(() => _selectedStation = v!),
            ),
            const SizedBox(height: 16),

            // Peak level
            _SectionLabel('Peak Flood Level (m)'),
            _SliderField(
              value: _peakLevel, min: 20, max: 100,
              divisions: 160,
              label: '${_peakLevel.toStringAsFixed(1)} m',
              onChanged: (v) => setState(() => _peakLevel = v),
            ),
            const SizedBox(height: 16),

            // Rainfall 7-day
            _SectionLabel('7-Day Rainfall Forecast (mm/day)'),
            _RainfallGrid(
              values: [_t1d, _t2d, _t3d, _t4d, _t5d, _t6d, _t7d],
              onChanged: (i, v) => setState(() {
                if (i == 0) _t1d = v;
                else if (i == 1) _t2d = v;
                else if (i == 2) _t3d = v;
                else if (i == 3) _t4d = v;
                else if (i == 4) _t5d = v;
                else if (i == 5) _t6d = v;
                else _t7d = v;
              }),
            ),
            const SizedBox(height: 16),

            // Duration sliders
            _SectionLabel('Event Duration (days)'),
            _SliderField(
              value: _eventDuration, min: 1, max: 30, divisions: 29,
              label: '${_eventDuration.toInt()} days',
              onChanged: (v) => setState(() => _eventDuration = v),
            ),
            _SectionLabel('Time to Peak (days)'),
            _SliderField(
              value: _timeToPeak, min: 1, max: 15, divisions: 14,
              label: '${_timeToPeak.toInt()} days',
              onChanged: (v) => setState(() => _timeToPeak = v),
            ),
            _SectionLabel('Recession Time (days)'),
            _SliderField(
              value: _recession, min: 1, max: 15, divisions: 14,
              label: '${_recession.toInt()} days',
              onChanged: (v) => setState(() => _recession = v),
            ),
            const SizedBox(height: 24),

            // Predict button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_loading ? 'Predicting…' : 'Predict Flood Severity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.blue1,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: _loading ? null : _predict,
              ),
            ),

            if (_error != null) ...[const SizedBox(height: 16), _ErrorCard(_error!)],
            if (_result != null) ...[const SizedBox(height: 20), _ResultCard(_result!, _selectedStation)],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

Widget _SectionLabel(String label) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: AppPalette.textMuted, letterSpacing: 0.5)),
);

class _BiharStationDropdown extends StatelessWidget {
  final String value;
  final List<String> stations;
  final ValueChanged<String?> onChanged;
  const _BiharStationDropdown(
      {required this.value, required this.stations, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppPalette.navy1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppPalette.navy1,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: stations.map((s) => DropdownMenuItem(
            value: s,
            child: Row(
              children: [
                const Icon(Icons.sensors_rounded, color: AppPalette.blue1, size: 16),
                const SizedBox(width: 8),
                Text(s),
              ],
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final double value, min, max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  const _SliderField({required this.value, required this.min, required this.max,
      required this.divisions, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value, min: min, max: max, divisions: divisions,
            activeColor: AppPalette.blue1,
            inactiveColor: AppPalette.navy2,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 70,
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _RainfallGrid extends StatelessWidget {
  final List<double> values;
  final void Function(int, double) onChanged;
  const _RainfallGrid({required this.values, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(values.length, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text('D${i + 1}',
                  style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
            ),
            Expanded(
              child: Slider(
                value: values[i], min: 0, max: 200, divisions: 200,
                activeColor: AppPalette.blue1,
                inactiveColor: AppPalette.navy2,
                onChanged: (v) => onChanged(i, v),
              ),
            ),
            SizedBox(
              width: 55,
              child: Text('${values[i].toInt()} mm',
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      )),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard(this.error);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: AppPalette.red),
          const SizedBox(width: 10),
          Expanded(child: Text(error,
              style: const TextStyle(fontSize: 13, color: AppPalette.red))),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String station;
  const _ResultCard(this.result, this.station);

  Color _severityColor(String s) {
    switch (s.toUpperCase()) {
      case 'LOW':      return AppPalette.green;
      case 'MODERATE': return AppPalette.gold;
      case 'SEVERE':   return AppPalette.orange;
      case 'CRITICAL': return AppPalette.red;
      default:         return AppPalette.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = (result['severity'] ?? 'UNKNOWN').toString().toUpperCase();
    final confidence = result['confidence_percent'] ?? 0;
    final riskScore = result['risk_score'] ?? 0;
    final color = _severityColor(severity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.water_damage_rounded, color: color, size: 32),
              const SizedBox(width: 12),
              Text(severity,
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$station — $kBiharState',
              style: const TextStyle(fontSize: 13, color: AppPalette.textMuted)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(label: 'Confidence', value: '$confidence%', color: color),
              _StatChip(label: 'Risk Score', value: '$riskScore', color: color),
            ],
          ),
          if (result['monitoring'] != null) ...[const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.navy2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppPalette.blue1, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result['monitoring']['action']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppPalette.textMuted)),
      ],
    );
  }
}
