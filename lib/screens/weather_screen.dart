import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../constants/bihar_constants.dart';
import '../providers/flood_providers.dart';

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  String _selectedDistrict = kBiharDefaultStation;

  // Bihar district cities for weather lookup
  static const List<String> _biharCities = [
    'Patna', 'Muzaffarpur', 'Bhagalpur', 'Darbhanga', 'Gaya',
    'Supaul', 'Sitamarhi', 'Gopalganj', 'Samastipur', 'Khagaria',
    'Katihar', 'Kishanganj', 'Araria', 'Saran', 'Hajipur',
    'Munger', 'Buxar', 'Siwan', 'Begusarai', 'Vaishali',
  ];

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider(_selectedDistrict));

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        backgroundColor: AppPalette.navy1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weather', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Bihar Districts', style: TextStyle(fontSize: 12, color: AppPalette.textMuted)),
          ],
        ),
      ),
      body: Column(
        children: [
          // City selector
          Container(
            color: AppPalette.navy1,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _biharCities.map((city) {
                  final selected = city == _selectedDistrict;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(city),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedDistrict = city),
                      selectedColor: AppPalette.blue1.withOpacity(0.25),
                      backgroundColor: AppPalette.navy2,
                      labelStyle: TextStyle(
                        color: selected ? AppPalette.blue1 : AppPalette.textMuted,
                        fontSize: 12,
                      ),
                      side: BorderSide(color: selected ? AppPalette.blue1 : AppPalette.divider),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Weather content
          Expanded(
            child: weather.when(
              data: (data) => _WeatherContent(data: data, city: _selectedDistrict),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppPalette.blue1)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: AppPalette.textMuted, size: 48),
                    const SizedBox(height: 12),
                    Text('Could not load weather for $_selectedDistrict',
                        style: const TextStyle(color: AppPalette.textMuted)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(weatherProvider),
                      child: const Text('Retry', style: TextStyle(color: AppPalette.blue1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final String city;
  const _WeatherContent({required this.data, required this.city});

  @override
  Widget build(BuildContext context) {
    final main = data['main'] as Map<String, dynamic>? ?? {};
    final weather = (data['weather'] as List?)?.firstOrNull as Map<String, dynamic>? ?? {};
    final wind = data['wind'] as Map<String, dynamic>? ?? {};
    final rain = data['rain'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Main weather card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppPalette.blue1.withOpacity(0.3), AppPalette.navy1],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.blue1.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(city, style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Bihar, India', style: const TextStyle(
                  fontSize: 13, color: AppPalette.textMuted)),
              const SizedBox(height: 16),
              Text('${main['temp']?.toStringAsFixed(1) ?? '--'}°C',
                  style: const TextStyle(
                      fontSize: 52, fontWeight: FontWeight.w300, color: Colors.white)),
              Text(weather['description']?.toString().toUpperCase() ?? '',
                  style: const TextStyle(fontSize: 13, color: AppPalette.textMuted, letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            Expanded(child: _WeatherStat(
                icon: Icons.water_drop_rounded, label: 'Humidity',
                value: '${main['humidity'] ?? '--'}%', color: AppPalette.blue1)),
            const SizedBox(width: 10),
            Expanded(child: _WeatherStat(
                icon: Icons.air_rounded, label: 'Wind',
                value: '${wind['speed'] ?? '--'} m/s', color: AppPalette.green)),
            const SizedBox(width: 10),
            Expanded(child: _WeatherStat(
                icon: Icons.compress_rounded, label: 'Pressure',
                value: '${main['pressure'] ?? '--'} hPa', color: AppPalette.gold)),
          ],
        ),
        const SizedBox(height: 10),

        // Rainfall alert if raining
        if (rain != null) ...[const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.blue1.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.blue1.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.umbrella_rounded, color: AppPalette.blue1, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active Rainfall',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${rain['1h'] ?? rain['3h'] ?? '--'} mm — Flood risk elevated',
                        style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _WeatherStat({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.navy1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppPalette.textMuted)),
        ],
      ),
    );
  }
}
