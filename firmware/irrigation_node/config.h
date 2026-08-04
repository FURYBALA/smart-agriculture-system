#pragma once

// ============================================================
//  Wi-Fi — the Flutter app polls this node's REST API over the
//  local network, so it needs to join the same Wi-Fi.
// ============================================================
#define WIFI_SSID     "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"

// ============================================================
//  Hardware pins (ESP32 Dev Board — plain ESP32, not ESP32-CAM.
//  This node has no camera; that's the separate vision_node.)
// ============================================================
#define DHT_PIN    4
#define DHT_TYPE   DHT11
#define SOIL_PIN   34   // ADC-capable pin
#define RELAY_PIN  27

// Most low-cost single-channel relay boards are active-LOW.
#define RELAY_ACTIVE_LOW true

// ============================================================
//  Soil sensor calibration — every unit reads differently.
//  Measure your own dry/wet raw ADC values before trusting the
//  percentage thresholds below.
// ============================================================
#define SOIL_RAW_DRY  4095
#define SOIL_RAW_WET  1800

// ============================================================
//  Irrigation thresholds — Table 3.5 in the project report:
//    < 30%   dry      -> pump ON
//    30-60%  optimal  -> pump OFF
//    > 60%   wet       -> pump OFF
// ============================================================
#define SOIL_DRY_THRESHOLD_PCT 30
#define SOIL_WET_THRESHOLD_PCT 60

#define PUMP_RUN_MS        5000UL
#define PUMP_COOLDOWN_MS 300000UL   // 5 min minimum between waterings

#define SENSOR_READ_INTERVAL_MS 10000UL

#define HTTP_SERVER_PORT 80
