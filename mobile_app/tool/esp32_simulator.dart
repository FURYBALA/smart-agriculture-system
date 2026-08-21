// Local simulator for both ESP32 nodes' REST APIs, byte-for-byte matching
// the JSON contracts firmware/irrigation_node/irrigation_node.ino and
// firmware/vision_node/vision_node.ino actually serve (handleGetSensors(),
// handleGetMode(), handlePumpOn/Off(), handleLatest()) -- implementation
// in esp32_simulator_lib.dart, shared with
// test/esp32_simulator_integration_test.dart.
//
// This lets the real, unmodified Flutter app (lib/services/esp32_service.dart
// is not touched at all -- it just talks to whatever host:port it's given)
// be exercised end-to-end against realistic, controllable device behavior
// without physical ESP32/ESP32-CAM hardware. It is a development/testing
// aid, not a replacement for real hardware validation -- see
// docs/simulation.md.
//
// Run:
//   dart run tool/esp32_simulator.dart
//
// Then point mobile_app/.env at it:
//   IRRIGATION_NODE_HOST=127.0.0.1:8090
//   VISION_NODE_HOST=127.0.0.1:8091
//
// Change live behavior without restarting, from another terminal:
//   curl -X POST http://127.0.0.1:8090/simulator/scenario -d '{"scenario":"low_moisture"}'
//   curl http://127.0.0.1:8090/simulator/scenarios   # lists what's available
import 'dart:io';

import 'esp32_simulator_lib.dart';

const irrigationPort = 8090;
const visionPort = 8091;

void main() async {
  final sim = await startSimulators(irrigationPort: irrigationPort, visionPort: visionPort);

  stdout.writeln('Irrigation node simulator: http://${sim.irrigationHost}  (real API: /sensors, /mode, /pump/on, /pump/off)');
  stdout.writeln('Vision node simulator:     http://${sim.visionHost}  (real API: /latest)');
  stdout.writeln('Scenario control:          POST /simulator/scenario  {"scenario": "..."}');
  stdout.writeln('Irrigation scenarios: ${IrrigationSimulator.scenarios.keys.join(", ")}');
  stdout.writeln('Vision scenarios:     ${VisionSimulator.scenarios.keys.join(", ")}');
  stdout.writeln('Point mobile_app/.env at ${sim.irrigationHost} / ${sim.visionHost} and run the real app.');
  stdout.writeln('Ctrl+C to stop.');
}
