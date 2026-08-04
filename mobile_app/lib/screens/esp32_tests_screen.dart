import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/esp32_service.dart';

enum _TestState { idle, running, passed, failed }

class Esp32TestsScreen extends StatefulWidget {
  const Esp32TestsScreen({super.key});

  @override
  State<Esp32TestsScreen> createState() => _Esp32TestsScreenState();
}

class _Esp32TestsScreenState extends State<Esp32TestsScreen> {
  _TestState _irrigationState = _TestState.idle;
  _TestState _visionState = _TestState.idle;

  Future<void> _testIrrigation() async {
    setState(() => _irrigationState = _TestState.running);
    final ok = await context.read<Esp32Service>().pingIrrigationNode();
    setState(() => _irrigationState = ok ? _TestState.passed : _TestState.failed);
  }

  Future<void> _testVision() async {
    setState(() => _visionState = _TestState.running);
    final ok = await context.read<Esp32Service>().pingVisionNode();
    setState(() => _visionState = ok ? _TestState.passed : _TestState.failed);
  }

  Future<void> _testAll() async {
    await Future.wait([_testIrrigation(), _testVision()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Connectivity')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DeviceTestTile(
            title: 'Irrigation Node',
            subtitle: 'Sensors + pump — ${AppConfig.irrigationNodeHost}',
            state: _irrigationState,
            onTest: _testIrrigation,
          ),
          const SizedBox(height: 12),
          _DeviceTestTile(
            title: 'Vision Node (ESP32-CAM)',
            subtitle: 'On-device disease detection — ${AppConfig.visionNodeHost}',
            state: _visionState,
            onTest: _testVision,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _testAll,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Test All'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Both devices must be on the same Wi-Fi network as this phone. '
            'Host addresses are set in mobile_app/.env — read each device\'s '
            'IP from its Serial Monitor output on boot.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _DeviceTestTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final _TestState state;
  final VoidCallback onTest;

  const _DeviceTestTile({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _StateIcon(state: state),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: onTest, child: const Text('Test')),
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  final _TestState state;
  const _StateIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _TestState.idle:
        return const Icon(Icons.circle_outlined, color: Colors.grey);
      case _TestState.running:
        return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
      case _TestState.passed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case _TestState.failed:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}
