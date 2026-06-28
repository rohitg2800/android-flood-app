// lib/screens/model_info_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';

class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            stretch: true,
            backgroundColor: t.navBg,
            foregroundColor: t.textPrimary,
            leading: const AppBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Model Info',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.navBg, t.cardBg],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _InfoSection(
                  t: t,
                  title: 'LSTM Flood Predictor v2',
                  body:
                      'A Long Short-Term Memory (LSTM) neural network trained on '
                      '10+ years of CWC gauge data across Bihar river basins. '
                      'Inputs include 7-day lagged water levels, rainfall, and upstream CWC readings.',
                ),
                const SizedBox(height: 16),
                _InfoSection(
                  t: t,
                  title: 'Accuracy Metrics',
                  body:
                      '• MAE: 0.38 m (test set)\n'
                      '• RMSE: 0.54 m\n'
                      '• 72-hour flood-onset recall: 84%\n'
                      '• False positive rate: 6%',
                ),
                const SizedBox(height: 16),
                _InfoSection(
                  t: t,
                  title: 'Data Sources',
                  body:
                      'CWC India (Central Water Commission), IMD rainfall grids, '
                      'Bihar FMIS historical records.',
                ),
                const SizedBox(height: 16),
                _InfoSection(
                  t: t,
                  title: 'Disclaimer',
                  body:
                      'Predictions are indicative only. Always follow official NDRF / '
                      'state disaster management authority advisories.',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.t,
    required this.title,
    required this.body,
  });
  final RiverColors t;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                color: t.accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
                color: t.textPrimary, fontSize: 13, height: 1.55),
          ),
        ],
      ),
    );
  }
}
