// Library backing tool/esp32_simulator.dart (the CLI dev tool) and
// test/esp32_simulator_integration_test.dart (which runs the real
// Esp32Service against these classes directly, on ephemeral test ports,
// with no subprocess involved). See tool/esp32_simulator.dart's header
// comment for what this simulates and why.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> respondJson(HttpRequest req, int status, Object body) async {
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(body));
  await req.response.close();
}

Future<void> respondRaw(HttpRequest req, int status, String rawBody) async {
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  req.response.write(rawBody);
  await req.response.close();
}

Future<Map<String, dynamic>?> readJsonBody(HttpRequest req) async {
  try {
    final text = await utf8.decoder.bind(req).join();
    if (text.isEmpty) return null;
    return jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Mirrors firmware/irrigation_node/irrigation_node.ino's REST surface:
/// GET /sensors, GET/POST /mode, POST /pump/on, POST /pump/off.
class IrrigationSimulator {
  String scenario = 'normal';
  final _rand = Random();

  String mode = 'auto';
  bool pumpOn = false;
  int soilMoisturePct = 45;
  double? temperature = 27.0;
  double? humidity = 55.0;

  static const scenarios = {
    'normal': 'Healthy mid-range readings, pump off, AUTO mode',
    'low_moisture': 'Soil below the dry threshold (< 30%) -- AUTO would start the pump',
    'pump_running': 'Pump currently on',
    'sensor_failure': 'temperature/humidity read as null, matching a DHT11 read failure',
    'malformed': '/sensors returns invalid JSON, to exercise Esp32Service error handling',
  };

  Future<void> handle(HttpRequest req) async {
    final path = req.uri.path;
    try {
      if (path == '/simulator/scenarios' && req.method == 'GET') {
        return respondJson(req, 200, scenarios);
      }
      if (path == '/simulator/scenario' && req.method == 'POST') {
        final body = await readJsonBody(req);
        final requested = body?['scenario'] as String?;
        if (requested == null || !scenarios.containsKey(requested)) {
          return respondJson(req, 400, {'error': 'unknown scenario', 'available': scenarios.keys.toList()});
        }
        scenario = requested;
        _applyScenario();
        return respondJson(req, 200, {'scenario': scenario});
      }

      if (path == '/sensors' && req.method == 'GET') {
        return _handleGetSensors(req);
      }
      if (path == '/mode' && req.method == 'GET') {
        return respondJson(req, 200, {'mode': mode});
      }
      if (path == '/mode' && req.method == 'POST') {
        return _handleSetMode(req);
      }
      if (path == '/pump/on' && req.method == 'POST') {
        return _handlePump(req, true);
      }
      if (path == '/pump/off' && req.method == 'POST') {
        return _handlePump(req, false);
      }
      return respondJson(req, 404, {'error': 'not found'});
    } catch (e) {
      return respondJson(req, 500, {'error': 'simulator error: $e'});
    }
  }

  void _applyScenario() {
    switch (scenario) {
      case 'low_moisture':
        soilMoisturePct = 18;
        temperature = 31.0;
        humidity = 40.0;
        break;
      case 'pump_running':
        soilMoisturePct = 22;
        pumpOn = true;
        break;
      case 'sensor_failure':
        temperature = null;
        humidity = null;
        break;
      case 'normal':
      case 'malformed':
      default:
        soilMoisturePct = 45;
        temperature = 27.0;
        humidity = 55.0;
        pumpOn = false;
        break;
    }
  }

  Future<void> _handleGetSensors(HttpRequest req) async {
    final jitteredSoil = (soilMoisturePct + _rand.nextInt(3) - 1).clamp(0, 100);

    if (scenario == 'malformed') {
      return respondRaw(req, 200, '{"temperature": 27.0, "humidity": ');
    }

    return respondJson(req, 200, {
      'temperature': temperature,
      'humidity': humidity,
      'soilMoisture': jitteredSoil,
      'pumpOn': pumpOn,
      'mode': mode,
    });
  }

  Future<void> _handleSetMode(HttpRequest req) async {
    final body = await readJsonBody(req);
    final requested = body?['mode'] as String?;
    if (requested != 'auto' && requested != 'manual') {
      return respondJson(req, 400, {'error': 'mode must be auto or manual'});
    }
    mode = requested!;
    return respondJson(req, 200, {'mode': mode});
  }

  Future<void> _handlePump(HttpRequest req, bool on) async {
    if (mode != 'manual') {
      return respondJson(req, 409, {'error': 'switch to manual mode first'});
    }
    pumpOn = on;
    return respondJson(req, 200, {'pumpOn': pumpOn});
  }
}

/// Mirrors firmware/vision_node/vision_node.ino's /latest endpoint.
class VisionSimulator {
  String scenario = 'healthy';
  final DateTime startedAt = DateTime.now();

  static const scenarios = {
    'no_result': 'Just booted -- no inference has completed yet (hasResult: false)',
    'healthy': 'Latest classification: Healthy, high confidence',
    'disease_detected': 'Latest classification: Early_Blight, moderate confidence',
    'low_confidence': "A weak-class result (Spider_Mite), matching the real model's documented weak point -- see docs/dataset.md",
  };

  Future<void> handle(HttpRequest req) async {
    final path = req.uri.path;
    try {
      if (path == '/simulator/scenarios' && req.method == 'GET') {
        return respondJson(req, 200, scenarios);
      }
      if (path == '/simulator/scenario' && req.method == 'POST') {
        final body = await readJsonBody(req);
        final requested = body?['scenario'] as String?;
        if (requested == null || !scenarios.containsKey(requested)) {
          return respondJson(req, 400, {'error': 'unknown scenario', 'available': scenarios.keys.toList()});
        }
        scenario = requested;
        return respondJson(req, 200, {'scenario': scenario});
      }
      if (path == '/latest' && req.method == 'GET') {
        return _handleLatest(req);
      }
      return respondJson(req, 404, {'error': 'not found'});
    } catch (e) {
      return respondJson(req, 500, {'error': 'simulator error: $e'});
    }
  }

  Future<void> _handleLatest(HttpRequest req) async {
    if (scenario == 'no_result') {
      return respondJson(req, 200, {'class': 'unknown', 'confidence': 0.0, 'hasResult': false, 'ageMs': 0});
    }

    final ageMs = DateTime.now().difference(startedAt).inMilliseconds % 20000;
    switch (scenario) {
      case 'disease_detected':
        return respondJson(req, 200, {'class': 'Early_Blight', 'confidence': 0.767, 'hasResult': true, 'ageMs': ageMs});
      case 'low_confidence':
        return respondJson(req, 200, {'class': 'Spider_Mite', 'confidence': 0.40, 'hasResult': true, 'ageMs': ageMs});
      case 'healthy':
      default:
        return respondJson(req, 200, {'class': 'Healthy', 'confidence': 0.867, 'hasResult': true, 'ageMs': ageMs});
    }
  }
}

class RunningSimulators {
  final HttpServer irrigationServer;
  final HttpServer visionServer;
  final IrrigationSimulator irrigation;
  final VisionSimulator vision;

  RunningSimulators(this.irrigationServer, this.visionServer, this.irrigation, this.vision);

  String get irrigationHost => '${irrigationServer.address.host}:${irrigationServer.port}';
  String get visionHost => '${visionServer.address.host}:${visionServer.port}';

  Future<void> close() async {
    await irrigationServer.close(force: true);
    await visionServer.close(force: true);
  }
}

/// Binds both simulators. Pass port: 0 for an OS-assigned ephemeral port
/// (what tests use, so parallel test runs never collide); the CLI tool
/// passes fixed ports so .env can point at a stable address.
Future<RunningSimulators> startSimulators({int irrigationPort = 0, int visionPort = 0}) async {
  final irrigation = IrrigationSimulator();
  final vision = VisionSimulator();

  final irrigationServer = await HttpServer.bind(InternetAddress.loopbackIPv4, irrigationPort);
  final visionServer = await HttpServer.bind(InternetAddress.loopbackIPv4, visionPort);

  irrigationServer.listen((req) => irrigation.handle(req));
  visionServer.listen((req) => vision.handle(req));

  return RunningSimulators(irrigationServer, visionServer, irrigation, vision);
}
