import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'alerts_bloc.dart';
import 'alerts_state.dart';
import 'alerts_event.dart';
import 'alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AlertsBloc>().add(LoadAlerts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flood Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AlertsBloc>().add(LoadAlerts()),
          ),
        ],
      ),
      body: BlocBuilder<AlertsBloc, AlertsState>(
        builder: (ctx, state) {
          if (state is AlertsLoading) return const Center(child: CircularProgressIndicator());
          if (state is AlertsError) return Center(child: Text('Error: ${state.message}'));
          if (state is AlertsLoaded) {
            if (state.alerts.isEmpty) {
              return const Center(child: Text('No active alerts ✔'));
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<AlertsBloc>().add(LoadAlerts()),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.alerts.length,
                itemBuilder: (ctx, i) => AlertCard(alert: state.alerts[i]),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
