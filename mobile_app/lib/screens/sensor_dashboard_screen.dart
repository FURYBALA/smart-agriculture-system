import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_reading.dart';
import '../services/esp32_service.dart';
import '../services/history_database.dart';

class SensorDashboardScreen extends StatefulWidget {
  const SensorDashboardScreen({super.key});

  @override
  State<SensorDashboardScreen> createState() => _SensorDashboardScreenState();
}

class _SensorDashboardScreenState extends State<SensorDashboardScreen> {
  Timer? _pollTimer;
  SensorReading? _reading;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final esp32 = context.read<Esp32Service>();
    try {
      final reading = await esp32.fetchSensors();
      if (!mounted) return;
      setState(() {
        _reading = reading;
        _error = null;
        _loading = false;
      });
      // Snapshot into history so trends are visible later.
      await context.read<HistoryDatabase>().saveSensorSnapshot(reading);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the irrigation node.\n$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Dashboard')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _refresh)
                : _DashboardBody(reading: _reading!),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final SensorReading reading;
  const _DashboardBody({required this.reading});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.thermostat,
                label: 'Temp',
                value: reading.temperature == null ? '--' : '${reading.temperature!.toStringAsFixed(1)}°C',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.water_drop,
                label: 'Humidity',
                value: reading.humidity == null ? '--' : '${reading.humidity!.toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.grass,
                label: 'Soil',
                value: '${reading.soilMoisture}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              reading.pumpOn ? Icons.power : Icons.power_off,
              color: reading.pumpOn ? Colors.green : Colors.grey,
            ),
            title: Text('Pump: ${reading.pumpOn ? "ON" : "OFF"}'),
            subtitle: Text('Mode: ${reading.mode == "auto" ? "Automatic" : "Manual"}'),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetricCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
