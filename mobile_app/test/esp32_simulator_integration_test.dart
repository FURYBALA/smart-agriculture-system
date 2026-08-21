// Runs the real, unmodified Esp32Service (lib/services/esp32_service.dart)
// against the real simulator (tool/esp32_simulator_lib.dart) over actual
// loopback HTTP -- not mocked http.Client, not a fake service
// implementation. This is the closest thing to an end-to-end firmware
// integration test achievable without physical ESP32 hardware: real
// production networking code, real JSON parsing, real error-handling
// branches, exercised against a server that speaks the exact contract the
// real firmware's REST handlers do.
//
// What this does NOT prove: that the real firmware behaves this way on
// actual hardware, or that Wi-Fi/timing/electrical behavior works. See
// docs/simulation.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/services/esp32_service.dart';

import '../tool/esp32_simulator_lib.dart';

void main() {
  late RunningSimulators sim;
  late Esp32Service service;

  setUp(() async {
    sim = await startSimulators();
    service = Esp32Service(irrigationHost: sim.irrigationHost, visionHost: sim.visionHost);
  });

  tearDown(() async {
    await sim.close();
  });

  group('irrigation node', () {
    test('fetchSensors parses a normal reading', () async {
      final reading = await service.fetchSensors();
      expect(reading.temperature, 27.0);
      expect(reading.humidity, 55.0);
      expect(reading.mode, 'auto');
      expect(reading.pumpOn, false);
    });

    test('fetchSensors handles a DHT11 read failure (null temperature/humidity)', () async {
      sim.irrigation.scenario = 'sensor_failure';
      sim.irrigation.temperature = null;
      sim.irrigation.humidity = null;

      final reading = await service.fetchSensors();
      expect(reading.temperature, isNull);
      expect(reading.humidity, isNull);
    });

    test('fetchSensors throws Esp32Exception on malformed JSON', () async {
      sim.irrigation.scenario = 'malformed';
      expect(() => service.fetchSensors(), throwsA(isA<Esp32Exception>()));
    });

    test('setPump is rejected with 409 while in AUTO mode', () async {
      expect(sim.irrigation.mode, 'auto');
      expect(() => service.setPump(true), throwsA(isA<Esp32Exception>()));
    });

    test('switching to manual then setPump(true) actually turns the pump on', () async {
      await service.setMode('manual');
      expect(await service.fetchMode(), 'manual');

      await service.setPump(true);
      final reading = await service.fetchSensors();
      expect(reading.pumpOn, true);

      await service.setPump(false);
      final after = await service.fetchSensors();
      expect(after.pumpOn, false);
    });

    test('setMode rejects an invalid mode the same way the real firmware does', () async {
      expect(() => service.setMode('turbo'), throwsA(isA<Esp32Exception>()));
    });

    test('pingIrrigationNode is true when the simulator is reachable', () async {
      expect(await service.pingIrrigationNode(), true);
    });
  });

  group('vision node', () {
    test('fetchLatestVisionResult reports hasResult:false right after boot', () async {
      sim.vision.scenario = 'no_result';
      final result = await service.fetchLatestVisionResult();
      expect(result.hasResult, false);
    });

    test('fetchLatestVisionResult parses a disease classification', () async {
      sim.vision.scenario = 'disease_detected';
      final result = await service.fetchLatestVisionResult();
      expect(result.hasResult, true);
      expect(result.diseaseClass, 'Early_Blight');
      expect(result.confidence, closeTo(0.767, 0.001));
    });

    test('fetchLatestVisionResult surfaces the documented weak-class confidence, not a fabricated one', () async {
      sim.vision.scenario = 'low_confidence';
      final result = await service.fetchLatestVisionResult();
      expect(result.diseaseClass, 'Spider_Mite');
      // Matches training_metadata.json's quantized_spotcheck_per_class_accuracy
      // for Spider_Mite (0.4) -- the simulator intentionally reflects the
      // real, documented weak point rather than an optimistic number.
      expect(result.confidence, closeTo(0.40, 0.001));
    });

    test('pingVisionNode is true when the simulator is reachable', () async {
      expect(await service.pingVisionNode(), true);
    });
  });
}
