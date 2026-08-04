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

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<HistoryDatabase>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Diagnoses'), Tab(text: 'Sensor Log')]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          FutureBuilder<List<DiagnosisResult>>(
            future: db.getDiagnoses(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              if (items.isEmpty) return const Center(child: Text('No diagnoses yet.'));
              return ListView.builder(
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
          FutureBuilder<List<SensorReading>>(
            future: db.getSensorSnapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              if (items.isEmpty) return const Center(child: Text('No sensor snapshots yet.'));
              return ListView.builder(
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
        ],
      ),
    );
  }
}
