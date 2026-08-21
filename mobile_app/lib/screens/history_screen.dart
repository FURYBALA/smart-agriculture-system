import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/diagnosis_result.dart';
import '../models/sensor_reading.dart';
import '../services/history_database.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _dateFormat = DateFormat('MMM d, h:mm a');

  // Loaded once here, not inline in build()'s FutureBuilder.future --
  // a FutureBuilder given `db.getDiagnoses()` directly re-runs that
  // query on every rebuild of this screen (any parent rebuild, theme
  // change, etc.), not just when data actually changes. HomeShell
  // also keeps this screen alive via IndexedStack rather than
  // remounting it on tab switch, so pull-to-refresh is how the user
  // sees newly-added diagnoses/snapshots without leaving and
  // returning to this tab.
  late Future<List<DiagnosisResult>> _diagnosesFuture;
  late Future<List<SensorReading>> _snapshotsFuture;

  @override
  void initState() {
    super.initState();
    _reloadDiagnoses();
    _reloadSnapshots();
  }

  void _reloadDiagnoses() {
    _diagnosesFuture = context.read<HistoryDatabase>().getDiagnoses();
  }

  void _reloadSnapshots() {
    _snapshotsFuture = context.read<HistoryDatabase>().getSensorSnapshots();
  }

  Future<void> _refreshDiagnoses() async {
    setState(_reloadDiagnoses);
    // Swallow here, not propagate: RefreshIndicator.onRefresh rethrowing
    // leaves its spinner in an inconsistent state. The FutureBuilder
    // below still sees the same (now-errored) future and renders the
    // error UI -- this just lets the pull-to-refresh gesture complete
    // cleanly instead of crashing out of it.
    try {
      await _diagnosesFuture;
    } catch (_) {}
  }

  Future<void> _refreshSnapshots() async {
    setState(_reloadSnapshots);
    try {
      await _snapshotsFuture;
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Diagnoses'), Tab(text: 'Sensor Log')]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          RefreshIndicator(
            onRefresh: _refreshDiagnoses,
            child: FutureBuilder<List<DiagnosisResult>>(
              future: _diagnosesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorList(message: 'Could not load history: ${snapshot.error}');
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: Text('No diagnoses yet.')),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final d = items[i];
                    return ListTile(
                      leading: d.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(File(d.imagePath!), width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : const CircleAvatar(child: Icon(Icons.memory)),
                      title: Text(d.diseaseName),
                      subtitle: Text(
                        '${d.source == DiagnosisSource.geminiVision ? "Gemini" : "On-device"} · ${_dateFormat.format(d.timestamp)}',
                      ),
                      trailing: Text('${(d.confidence * 100).round()}%'),
                    );
                  },
                );
              },
            ),
          ),
          RefreshIndicator(
            onRefresh: _refreshSnapshots,
            child: FutureBuilder<List<SensorReading>>(
              future: _snapshotsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorList(message: 'Could not load sensor log: ${snapshot.error}');
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: Text('No sensor snapshots yet.')),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return ListTile(
                      leading: Icon(s.pumpOn ? Icons.power : Icons.power_off, color: s.pumpOn ? Colors.green : Colors.grey),
                      title: Text(
                        '${s.temperature?.toStringAsFixed(1) ?? "--"}°C · ${s.humidity?.toStringAsFixed(0) ?? "--"}% · Soil ${s.soilMoisture}%',
                      ),
                      subtitle: Text(_dateFormat.format(s.timestamp)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Kept scrollable (AlwaysScrollableScrollPhysics) so pull-to-refresh
/// still works from an error state, not just from a loaded list.
class _ErrorList extends StatelessWidget {
  final String message;
  const _ErrorList({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Pull down to retry.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
