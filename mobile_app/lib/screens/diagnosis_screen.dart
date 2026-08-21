import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/diagnosis_result.dart';
import '../services/esp32_service.dart';
import '../services/gemini_service.dart';
import '../services/history_database.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  DiagnosisResult? _result;
  bool _loading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _image = file;
      _result = null;
      _error = null;
    });
  }

  Future<void> _diagnoseWithGemini() async {
    final gemini = context.read<GeminiService?>();
    if (_image == null) return;
    if (gemini == null) {
      setState(() => _error = 'No Gemini API key configured. Add one to mobile_app/.env.');
      return;
    }

    final history = context.read<HistoryDatabase>();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await File(_image!.path).readAsBytes();
      final result = await gemini.diagnoseLeafImage(bytes);
      final withImage = DiagnosisResult(
        source: result.source,
        diseaseName: result.diseaseName,
        confidence: result.confidence,
        symptomDescription: result.symptomDescription,
        correctiveMeasures: result.correctiveMeasures,
        imagePath: _image!.path,
        timestamp: result.timestamp,
      );
      await history.saveDiagnosis(withImage);
      if (!mounted) return;
      setState(() => _result = withImage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Diagnosis failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _diagnoseOnDevice() async {
    final esp32 = context.read<Esp32Service>();
    final history = context.read<HistoryDatabase>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final latest = await esp32.fetchLatestVisionResult();
      if (!latest.hasResult) {
        setState(() => _error =
            'The vision node has no result yet -- point the ESP32-CAM at a leaf and wait a few seconds.');
        return;
      }
      if (latest.ageMs > 60000) {
        setState(() => _error =
            'Vision node result is ${(latest.ageMs / 1000).round()}s old -- point the ESP32-CAM at a leaf and try again.');
        return;
      }
      final result = DiagnosisResult(
        source: DiagnosisSource.onDeviceEsp32Cam,
        diseaseName: latest.diseaseClass,
        confidence: latest.confidence,
        symptomDescription: 'Classified on-device by the ESP32-CAM TinyML model.',
        correctiveMeasures:
            'For detailed symptoms and treatment steps, use "Diagnose with Gemini" on a clear photo of the same leaf.',
        timestamp: DateTime.now(),
      );
      await history.saveDiagnosis(result);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the vision node: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disease Diagnosis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _image == null
                  ? const Center(child: Text('No image selected'))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_image!.path), fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_image == null || _loading) ? null : _diagnoseWithGemini,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Diagnose with Gemini Vision'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _diagnoseOnDevice,
            icon: const Icon(Icons.memory),
            label: const Text('Use on-device ESP32-CAM result instead'),
          ),
          if (_loading) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final DiagnosisResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isHealthy = result.diseaseName.toLowerCase().contains('healthy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isHealthy ? Icons.check_circle : Icons.warning_amber, color: isHealthy ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.diseaseName, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                result.source == DiagnosisSource.geminiVision
                    ? 'Gemini Vision · ${(result.confidence * 100).round()}% confidence'
                    : 'On-device ESP32-CAM · ${(result.confidence * 100).round()}% confidence',
              ),
            ),
            const SizedBox(height: 12),
            Text('Symptoms', style: Theme.of(context).textTheme.labelLarge),
            Text(result.symptomDescription),
            const SizedBox(height: 12),
            Text('Corrective measures', style: Theme.of(context).textTheme.labelLarge),
            Text(result.correctiveMeasures),
          ],
        ),
      ),
    );
  }
}
