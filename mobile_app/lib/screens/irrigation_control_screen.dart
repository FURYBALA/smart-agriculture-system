import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/esp32_service.dart';

class IrrigationControlScreen extends StatefulWidget {
  const IrrigationControlScreen({super.key});

  @override
  State<IrrigationControlScreen> createState() => _IrrigationControlScreenState();
}

class _IrrigationControlScreenState extends State<IrrigationControlScreen> {
  String _mode = 'auto';
  bool _pumpOn = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final esp32 = context.read<Esp32Service>();
    try {
      final mode = await esp32.fetchMode();
      final sensors = await esp32.fetchSensors();
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _pumpOn = sensors.pumpOn;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the irrigation node.');
    }
  }

  Future<void> _setMode(String mode) async {
    setState(() => _busy = true);
    try {
      await context.read<Esp32Service>().setMode(mode);
      if (!mounted) return;
      setState(() => _mode = mode);
    } catch (e) {
      _showError('Failed to switch mode: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPump(bool on) async {
    setState(() => _busy = true);
    try {
      await context.read<Esp32Service>().setPump(on);
      if (!mounted) return;
      setState(() => _pumpOn = on);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Irrigation')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mode', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'auto', label: Text('Automatic'), icon: Icon(Icons.auto_mode)),
                            ButtonSegment(value: 'manual', label: Text('Manual'), icon: Icon(Icons.pan_tool)),
                          ],
                          selected: {_mode},
                          onSelectionChanged: _busy ? null : (s) => _setMode(s.first),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mode == 'auto'
                              ? 'Pump activates automatically based on soil moisture thresholds.'
                              : 'You control the pump directly below.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pump', style: Theme.of(context).textTheme.titleMedium),
                            Text(_pumpOn ? 'ON' : 'OFF'),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: (_mode != 'manual' || _busy) ? null : () => _setPump(!_pumpOn),
                          icon: Icon(_pumpOn ? Icons.stop : Icons.play_arrow),
                          label: Text(_pumpOn ? 'Turn OFF' : 'Turn ON'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _pumpOn ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_mode != 'manual')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Switch to Manual mode to control the pump directly.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
    );
  }
}
