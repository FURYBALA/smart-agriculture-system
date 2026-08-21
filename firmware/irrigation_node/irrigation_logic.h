// Pure, hardware-independent decision logic for the irrigation node:
// soil-ADC-to-percent conversion and pump start/stop/cutoff decisions.
//
// No Arduino.h, no digitalWrite/millis/analogRead calls -- every function
// here takes its inputs (including "now") as plain parameters and returns
// a decision or a converted value. irrigation_node.ino calls these and
// does the actual hardware I/O around them.
//
// This split exists so the decision logic -- the part a wiring mistake or
// a mode-switch race can silently get wrong -- can be exercised with a
// plain host C++ compiler in firmware/test/test_irrigation_logic.cpp,
// without an ESP32 board. See docs/host-testing.md.
#pragma once

namespace irrigation_logic {

struct PumpState {
  bool pumpOn = false;
  unsigned long pumpStartedAt = 0;
  unsigned long pumpLastFinishedAt = 0;

  // Tracks *who* turned the pump on, not the current mode -- gating the
  // safety timer on currentMode alone has a hole: AUTO starts the pump,
  // then the user switches to MANUAL mid-cycle before the timer fires.
  // Tracking the pump's own origin means an auto-started pump still gets
  // shut off on schedule regardless of any mode switch in between, while
  // a manually-started pump is never subject to the timer.
  bool pumpStartedByAuto = false;
};

// Reproduces Arduino's map() formula exactly (same integer arithmetic,
// same truncation direction), then clamps to [0, 100] the way
// constrain() does in irrigation_node.ino's readSensors(). rawDry can be
// numerically greater than rawWet (a drier reading is a *higher* raw ADC
// value on this sensor) -- the formula handles that inverted range the
// same way Arduino's map() does.
inline int convertSoilRawToPercent(int raw, int rawDry, int rawWet) {
  long pct = (long)(raw - rawDry) * (100 - 0) / (rawWet - rawDry) + 0;
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  return (int)pct;
}

// True when AUTO mode should command the pump on.
inline bool shouldAutoStart(int soilMoisturePct, int dryThresholdPct) {
  return soilMoisturePct < dryThresholdPct;
}

// True when AUTO mode should command a currently-running pump off because
// the soil is wet enough again.
inline bool shouldAutoStop(int soilMoisturePct, int wetThresholdPct, bool pumpOn) {
  return pumpOn && soilMoisturePct >= wetThresholdPct;
}

// True if startPump() is allowed to actually turn the pump on right now:
// not already on, and past the cooldown since it last finished a run.
inline bool canStartPump(const PumpState& s, unsigned long now, unsigned long cooldownMs) {
  if (s.pumpOn) return false;
  if (s.pumpLastFinishedAt == 0) return true;
  return (now - s.pumpLastFinishedAt) >= cooldownMs;
}

// True if the AUTO safety timer should cut the pump now. Only ever true
// for a pump AUTO itself started (pumpStartedByAuto) -- see PumpState's
// doc comment above for why that's tracked instead of the current mode.
inline bool shouldAutoCutoff(const PumpState& s, unsigned long now, unsigned long runMs) {
  if (!s.pumpOn || !s.pumpStartedByAuto) return false;
  return (now - s.pumpStartedAt) >= runMs;
}

}  // namespace irrigation_logic
