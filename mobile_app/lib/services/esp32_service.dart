import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

/// Talks to the two ESP32 nodes' local REST APIs (see
/// firmware/irrigation_node and firmware/vision_node). Both devices
/// must be on the same Wi-Fi network as the phone -- there is no
/// cloud relay for these, by design, so irrigation control keeps
/// working even if the internet is down.
class Esp32Service {
  final String irrigationHost;
  final String visionHost;
  static const _timeout = Duration(seconds: 5);

  Esp32Service({required this.irrigationHost, required this.visionHost});

  Uri _irrigationUri(String path) => Uri.parse('http://$irrigationHost$path');
  Uri _visionUri(String path) => Uri.parse('http://$visionHost$path');

  Future<SensorReading> fetchSensors() async {
    final res = await http.get(_irrigationUri('/sensors')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Esp32Exception('Sensor read failed (${res.statusCode})');
    }
    return SensorReading.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String> fetchMode() async {
    final res = await http.get(_irrigationUri('/mode')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Esp32Exception('Mode read failed (${res.statusCode})');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['mode'] as String;
  }

  Future<void> setMode(String mode) async {
    final res = await http
        .post(
          _irrigationUri('/mode'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mode': mode}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Esp32Exception('Failed to set mode (${res.statusCode})');
    }
  }

  Future<void> setPump(bool on) async {
    final path = on ? '/pump/on' : '/pump/off';
    final res = await http.post(_irrigationUri(path)).timeout(_timeout);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      throw Esp32Exception(body?['error'] as String? ?? 'Pump command failed');
    }
  }

  /// Latest on-device disease classification from the vision node --
  /// a free, offline-capable alternative to cloud (Gemini) diagnosis.
  Future<({String diseaseClass, double confidence, int ageMs})> fetchLatestVisionResult() async {
    final res = await http.get(_visionUri('/latest')).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Esp32Exception('Vision node read failed (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      diseaseClass: json['class'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      ageMs: (json['ageMs'] as num).toInt(),
    );
  }

  /// Used by the ESP32 Connectivity Testing screen.
  Future<bool> pingIrrigationNode() async {
    try {
      final res = await http.get(_irrigationUri('/sensors')).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pingVisionNode() async {
    try {
      final res = await http.get(_visionUri('/latest')).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class Esp32Exception implements Exception {
  final String message;
  Esp32Exception(this.message);
  @override
  String toString() => message;
}
