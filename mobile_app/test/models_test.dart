// Round-trip and wire-format tests for the two local persistence models.
// No device, network, or platform channel needed -- these are pure
// Dart data classes, unlike widget_test.dart's app-shell smoke test.

import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/diagnosis_result.dart';
import 'package:plant_doctor/models/sensor_reading.dart';

void main() {
  group('DiagnosisResult', () {
    test('toMap/fromMap round-trips every field', () {
      final original = DiagnosisResult(
        id: 7,
        source: DiagnosisSource.onDeviceEsp32Cam,
        diseaseName: 'Early_Blight',
        confidence: 0.812,
        symptomDescription: 'Concentric brown rings on lower leaves.',
        correctiveMeasures: 'Remove affected leaves; apply copper fungicide.',
        imagePath: '/data/user/0/plant_doctor/leaf.jpg',
        timestamp: DateTime.parse('2026-03-05T14:30:00.000'),
      );

      final restored = DiagnosisResult.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.source, original.source);
      expect(restored.diseaseName, original.diseaseName);
      expect(restored.confidence, original.confidence);
      expect(restored.symptomDescription, original.symptomDescription);
      expect(restored.correctiveMeasures, original.correctiveMeasures);
      expect(restored.imagePath, original.imagePath);
      expect(restored.timestamp, original.timestamp);
    });

    test('toMap/fromMap round-trips a null imagePath (Gemini text-only result)', () {
      final original = DiagnosisResult(
        source: DiagnosisSource.geminiVision,
        diseaseName: 'Healthy',
        confidence: 0.95,
        symptomDescription: 'No visible lesions.',
        correctiveMeasures: 'None needed.',
        timestamp: DateTime.parse('2026-03-05T09:00:00.000'),
      );

      final restored = DiagnosisResult.fromMap(original.toMap());

      expect(restored.imagePath, isNull);
      expect(restored.id, isNull);
    });

    test('fromMap falls back to geminiVision for an unrecognized source string', () {
      // sqflite stores the enum name as plain text (source.name) -- if
      // a future app version adds/renames a DiagnosisSource value, an
      // old row from before the change must not crash the History
      // screen. firstWhere's orElse is what prevents that.
      final map = {
        'id': 1,
        'source': 'someFutureSourceNotYetDefined',
        'diseaseName': 'Healthy',
        'confidence': 1.0,
        'symptomDescription': '',
        'correctiveMeasures': '',
        'imagePath': null,
        'timestamp': '2026-03-05T09:00:00.000',
      };

      final restored = DiagnosisResult.fromMap(map);

      expect(restored.source, DiagnosisSource.geminiVision);
    });
  });

  group('SensorReading', () {
    test('toMap/fromMap round-trips pumpOn as SQLite integer, not bool', () {
      final original = SensorReading(
        temperature: 27.5,
        humidity: 61.0,
        soilMoisture: 42,
        pumpOn: true,
        mode: 'auto',
        timestamp: DateTime.parse('2026-03-05T14:30:00.000'),
      );

      final map = original.toMap();
      expect(map['pumpOn'], 1); // sqflite has no native bool column type

      final restored = SensorReading.fromMap(map);
      expect(restored.pumpOn, true);
      expect(restored.temperature, 27.5);
      expect(restored.humidity, 61.0);
      expect(restored.soilMoisture, 42);
      expect(restored.mode, 'auto');
      expect(restored.timestamp, original.timestamp);
    });

    test('toMap/fromMap round-trips null temperature/humidity (DHT11 read failure)', () {
      final original = SensorReading(
        temperature: null,
        humidity: null,
        soilMoisture: 10,
        pumpOn: false,
        mode: 'manual',
        timestamp: DateTime.parse('2026-03-05T14:30:00.000'),
      );

      final restored = SensorReading.fromMap(original.toMap());

      expect(restored.temperature, isNull);
      expect(restored.humidity, isNull);
      expect(restored.pumpOn, false);
    });

    test('fromJson parses a full /sensors response from the irrigation node', () {
      final reading = SensorReading.fromJson({
        'temperature': 26.4,
        'humidity': 58.0,
        'soilMoisture': 35,
        'pumpOn': true,
        'mode': 'auto',
      });

      expect(reading.temperature, 26.4);
      expect(reading.humidity, 58.0);
      expect(reading.soilMoisture, 35);
      expect(reading.pumpOn, true);
      expect(reading.mode, 'auto');
    });

    test('fromJson applies safe defaults when the DHT11 read failed (nulls) and fields are missing', () {
      // Mirrors firmware/irrigation_node/irrigation_node.ino's
      // handleGetSensors(): temperature/humidity serialize to JSON
      // null (not omitted) when isnan(), so num? casts must accept
      // null here rather than throwing.
      final reading = SensorReading.fromJson({
        'temperature': null,
        'humidity': null,
        'soilMoisture': 20,
      });

      expect(reading.temperature, isNull);
      expect(reading.humidity, isNull);
      expect(reading.soilMoisture, 20);
      expect(reading.pumpOn, false); // default when the key is absent
      expect(reading.mode, 'auto'); // default when the key is absent
    });
  });
}
