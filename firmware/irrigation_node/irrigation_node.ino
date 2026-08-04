/*
  Irrigation Node — ESP32
  ------------------------
  Reads soil moisture + DHT11 temperature/humidity, drives a relay
  pump automatically against the thresholds in the project report
  (Table 3.5), and exposes a small REST API over Wi-Fi so the Flutter
  app's Sensor Dashboard and Irrigation Control screens can read
  status and send manual commands.

  Board: ESP32 Dev Board (plain ESP32 — the camera-based disease
  detection runs on a separate ESP32-CAM, see firmware/vision_node).

  Required libraries (Arduino Library Manager):
    - DHT sensor library (Adafruit) + Adafruit Unified Sensor
    - ArduinoJson

  REST API:
    GET  /sensors      -> { temperature, humidity, soilMoisture, pumpOn, mode }
    GET  /mode         -> { mode: "auto" | "manual" }
    POST /mode         -> body { "mode": "auto" | "manual" }
    POST /pump/on      -> manual pump on (only honored in manual mode)
    POST /pump/off     -> manual pump off
*/

#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include "config.h"

DHT dht(DHT_PIN, DHT_TYPE);
WebServer server(HTTP_SERVER_PORT);

enum Mode { MODE_AUTO, MODE_MANUAL };
Mode currentMode = MODE_AUTO;

float temperatureC = NAN;
float humidityPct = NAN;
int soilMoisturePct = 0;

bool pumpOn = false;
unsigned long pumpStartedAt = 0;
unsigned long pumpLastFinishedAt = 0;
unsigned long lastSensorReadAt = 0;

void setPumpOutput(bool on) {
  bool level = RELAY_ACTIVE_LOW ? !on : on;
  digitalWrite(RELAY_PIN, level ? HIGH : LOW);
  pumpOn = on;
}

void startPump() {
  if (pumpOn) return;
  unsigned long sinceLastRun = millis() - pumpLastFinishedAt;
  if (pumpLastFinishedAt != 0 && sinceLastRun < PUMP_COOLDOWN_MS) return;
  setPumpOutput(true);
  pumpStartedAt = millis();
}

void servicePumpTimer() {
  if (!pumpOn) return;
  if (millis() - pumpStartedAt >= PUMP_RUN_MS) {
    setPumpOutput(false);
    pumpLastFinishedAt = millis();
  }
}

void readSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (!isnan(h) && !isnan(t)) {
    humidityPct = h;
    temperatureC = t;
  }

  int raw = analogRead(SOIL_PIN);
  long pct = map(raw, SOIL_RAW_DRY, SOIL_RAW_WET, 0, 100);
  soilMoisturePct = constrain((int)pct, 0, 100);
}

void applyAutoIrrigationLogic() {
  if (currentMode != MODE_AUTO) return;
  if (soilMoisturePct < SOIL_DRY_THRESHOLD_PCT) {
    startPump();
  } else if (soilMoisturePct >= SOIL_WET_THRESHOLD_PCT && pumpOn) {
    setPumpOutput(false);
    pumpLastFinishedAt = millis();
  }
}

// ---- REST handlers ----

void handleGetSensors() {
  JsonDocument doc;
  doc["temperature"] = isnan(temperatureC) ? nullptr : temperatureC;
  doc["humidity"] = isnan(humidityPct) ? nullptr : humidityPct;
  doc["soilMoisture"] = soilMoisturePct;
  doc["pumpOn"] = pumpOn;
  doc["mode"] = currentMode == MODE_AUTO ? "auto" : "manual";

  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

void handleGetMode() {
  JsonDocument doc;
  doc["mode"] = currentMode == MODE_AUTO ? "auto" : "manual";
  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

void handleSetMode() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"missing body\"}");
    return;
  }
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, server.arg("plain"));
  if (err) {
    server.send(400, "application/json", "{\"error\":\"invalid json\"}");
    return;
  }
  String mode = doc["mode"] | "";
  if (mode == "auto") {
    currentMode = MODE_AUTO;
  } else if (mode == "manual") {
    currentMode = MODE_MANUAL;
  } else {
    server.send(400, "application/json", "{\"error\":\"mode must be auto or manual\"}");
    return;
  }
  handleGetMode();
}

void handlePumpOn() {
  if (currentMode != MODE_MANUAL) {
    server.send(409, "application/json", "{\"error\":\"switch to manual mode first\"}");
    return;
  }
  setPumpOutput(true);
  server.send(200, "application/json", "{\"pumpOn\":true}");
}

void handlePumpOff() {
  if (currentMode != MODE_MANUAL) {
    server.send(409, "application/json", "{\"error\":\"switch to manual mode first\"}");
    return;
  }
  setPumpOutput(false);
  pumpLastFinishedAt = millis();
  server.send(200, "application/json", "{\"pumpOn\":false}");
}

void handleNotFound() {
  server.send(404, "application/json", "{\"error\":\"not found\"}");
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Connected. IP address: ");
  Serial.println(WiFi.localIP());
  Serial.println("^ point the Flutter app's ESP32 host setting at this IP.");
}

void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(RELAY_PIN, OUTPUT);
  setPumpOutput(false);
  pinMode(SOIL_PIN, INPUT);
  dht.begin();

  connectWiFi();

  server.on("/sensors", HTTP_GET, handleGetSensors);
  server.on("/mode", HTTP_GET, handleGetMode);
  server.on("/mode", HTTP_POST, handleSetMode);
  server.on("/pump/on", HTTP_POST, handlePumpOn);
  server.on("/pump/off", HTTP_POST, handlePumpOff);
  server.onNotFound(handleNotFound);
  server.begin();

  Serial.println("REST API server started.");
}

void loop() {
  server.handleClient();

  if (millis() - lastSensorReadAt >= SENSOR_READ_INTERVAL_MS) {
    lastSensorReadAt = millis();
    readSensors();
    applyAutoIrrigationLogic();
    Serial.printf("Temp: %.1f C | Humidity: %.1f %% | Soil: %d %% | Pump: %s | Mode: %s\n",
                  temperatureC, humidityPct, soilMoisturePct,
                  pumpOn ? "ON" : "OFF",
                  currentMode == MODE_AUTO ? "auto" : "manual");
  }

  servicePumpTimer();
}
