// Host-side test for firmware/irrigation_node/irrigation_logic.h --
// compiles and runs on a plain desktop C++ compiler (no ESP32 board, no
// Arduino toolchain). See docs/host-testing.md.
//
// Build: g++ -std=c++17 -I../irrigation_node test_irrigation_logic.cpp -o test_irrigation_logic
// Run:   ./test_irrigation_logic
#include <cstdio>
#include "irrigation_logic.h"

using namespace irrigation_logic;

static int failures = 0;

#define CHECK(cond)                                                        \
  do {                                                                     \
    if (!(cond)) {                                                         \
      std::fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
      failures++;                                                          \
    }                                                                      \
  } while (0)

void test_convertSoilRawToPercent() {
  // SOIL_RAW_DRY=4095, SOIL_RAW_WET=1800 in config.h -- a higher raw ADC
  // reading means drier soil on this sensor.
  CHECK(convertSoilRawToPercent(4095, 4095, 1800) == 0);    // fully dry
  CHECK(convertSoilRawToPercent(1800, 4095, 1800) == 100);  // fully wet

  int mid = convertSoilRawToPercent((4095 + 1800) / 2, 4095, 1800);
  CHECK(mid >= 45 && mid <= 55);

  // Readings beyond the calibrated range clamp instead of going
  // negative or over 100.
  CHECK(convertSoilRawToPercent(4095 + 500, 4095, 1800) == 0);
  CHECK(convertSoilRawToPercent(1800 - 500, 4095, 1800) == 100);
}

void test_shouldAutoStart_shouldAutoStop() {
  CHECK(shouldAutoStart(29, 30) == true);
  CHECK(shouldAutoStart(30, 30) == false);

  CHECK(shouldAutoStop(60, 60, true) == true);
  CHECK(shouldAutoStop(59, 60, true) == false);
  CHECK(shouldAutoStop(60, 60, false) == false);  // pump already off -- nothing to stop
}

void test_canStartPump_cooldown() {
  PumpState s;
  CHECK(canStartPump(s, 1000, 300000) == true);  // never run before -> no cooldown to wait out

  s.pumpLastFinishedAt = 1000;
  CHECK(canStartPump(s, 1000 + 299999, 300000) == false);  // still cooling down
  CHECK(canStartPump(s, 1000 + 300000, 300000) == true);   // cooldown just elapsed

  s.pumpOn = true;
  CHECK(canStartPump(s, 1000 + 999999, 300000) == false);  // already running
}

void test_shouldAutoCutoff_originTracking() {
  PumpState autoStarted;
  autoStarted.pumpOn = true;
  autoStarted.pumpStartedAt = 1000;
  autoStarted.pumpStartedByAuto = true;
  CHECK(shouldAutoCutoff(autoStarted, 1000 + 4999, 5000) == false);
  CHECK(shouldAutoCutoff(autoStarted, 1000 + 5000, 5000) == true);

  // This is the exact regression irrigation_node.ino's pump-timer
  // origin-tracking fix exists for: a manually-started pump must never
  // be cut off by the auto safety timer, no matter how long it's run.
  PumpState manuallyStarted;
  manuallyStarted.pumpOn = true;
  manuallyStarted.pumpStartedAt = 1000;
  manuallyStarted.pumpStartedByAuto = false;
  CHECK(shouldAutoCutoff(manuallyStarted, 1000 + 999999, 5000) == false);

  // Not running at all -> never a cutoff, regardless of origin/timing.
  PumpState idle;
  CHECK(shouldAutoCutoff(idle, 1000 + 999999, 5000) == false);
}

int main() {
  test_convertSoilRawToPercent();
  test_shouldAutoStart_shouldAutoStop();
  test_canStartPump_cooldown();
  test_shouldAutoCutoff_originTracking();

  if (failures == 0) {
    std::printf("All irrigation_logic tests passed.\n");
    return 0;
  }
  std::fprintf(stderr, "%d irrigation_logic test(s) FAILED.\n", failures);
  return 1;
}
