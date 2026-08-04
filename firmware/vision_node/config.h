#pragma once

#define WIFI_SSID     "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"

constexpr unsigned long kCaptureIntervalMs = 5000;
constexpr int kHttpServerPort = 80;

// Sized for this model (4 conv blocks + dense head at 96x96x3 input).
// Increase if AllocateTensors() reports "arena too small" on your build.
constexpr int kTensorArenaSize = 250 * 1024;
