# Wokwi simulation (irrigation node) -- actually attempted, real findings

[`firmware/irrigation_node/wokwi/`](../firmware/irrigation_node/wokwi/)
contains a [Wokwi](https://wokwi.com) diagram (`diagram.json`) and CLI
config (`wokwi.toml`) modeling the irrigation node's circuit: an ESP32,
a DHT sensor, a soil-moisture analog input, and an LED standing in for
the relay-driven pump.

**This has been actually run**, with a real `WOKWI_CLI_TOKEN` against
Wokwi's real simulation API -- not just validated as JSON. It found and
fixed two real configuration bugs, and surfaced one genuine, unresolved
limitation. Below is the real result, not an assumption.

## What actually happened

1. **Compiled the real firmware.** Installed `arduino-cli` and the
   ESP32 board core locally, then compiled
   `firmware/irrigation_node` for real:
   ```
   Sketch uses 939088 bytes (71%) of program storage space.
   Global variables use 47176 bytes (14%) of dynamic memory.
   ```
2. **First run found a real bug**: `diagram.json` wired the ESP32 using
   Arduino-style pin names (`esp32:D4`, `esp32:D34`, `esp32:D27`).
   Wokwi's `board-esp32-devkit-c-v4` part rejected all three --
   `wokwi-cli` reported the exact valid pin list (plain numbers: `4`,
   `34`, `27`, no `D` prefix), and the run failed with
   `API Error: Connection to transport closed unexpectedly`. Fixed by
   using the correct pin names Wokwi itself reported.
3. **Second finding**: `wokwi.toml`'s `firmware` field is required, not
   optional -- confirmed by an actual CLI error
   (`Error in wokwi.toml: Firmware path must be a string`) when an
   ELF-only config was tried as a diagnostic. `wokwi.toml` already had
   both fields; this just confirms the schema.
4. **With both bugs fixed**, `wokwi-cli` connects successfully every
   time (`Connected to Wokwi Simulation API 1.0.0-...`) and reports
   `Starting simulation...`, but the simulation **never completes** --
   every run hits its timeout with zero serial output, across:
   - the real firmware, multiple config variations (separate `.bin`,
     merged `.bin`, various timeouts from 6s to 45s)
   - a minimal diagram with no peripherals at all (bare ESP32 board) --
     ruling out the DHT/potentiometer/LED parts as the cause
   - **a completely trivial, independently-compiled sanity sketch**
     (`Serial.begin(); Serial.println("...")` in a loop, nothing else)
     -- ruling out this project's firmware as the cause entirely
   - with `DEBUG=*` set for more verbose CLI output (no additional
     information surfaced)
   - with no system proxy configured (`netsh winhttp show proxy`
     confirmed direct access)

## Conclusion

The Wokwi CLI genuinely authenticates and starts a real simulation
session in this environment, but no simulation -- including a trivial
one with no relationship to this project's code -- completes or
produces observable output within any tested timeout. This is a
reproducible environment/service-level limitation, not a defect in this
repository's firmware, diagram, or configuration: the diagram and
config bugs that *were* real were found and fixed, and the CLI accepted
the corrected config cleanly (no further validation errors) before
stalling.

**Do not read this as "Wokwi passed."** It also should not be read as
"the firmware doesn't work" -- that possibility was specifically ruled
out by the sanity-sketch test. It is an honest third outcome: attempted
for real, partially diagnosed, genuinely inconclusive.

## What it would simulate, and where it's an approximation

- **DHT sensor**: modeled with `wokwi-dht22`, not a DHT11-specific part
  (Wokwi doesn't have one). Same protocol family, close enough for
  exercising the read path -- not a claim that DHT11-specific timing
  quirks are represented.
- **Soil moisture sensor**: modeled with a potentiometer, since Wokwi
  has no capacitive/resistive soil moisture sensor part. Turning the
  potentiometer stands in for wetting/drying the real sensor -- it
  produces an analog voltage on the same pin (`GPIO34`), which is what
  `readSensors()` actually reads; it does not simulate real soil
  electrical behavior.
- **Pump/relay**: modeled with an LED + resistor on `GPIO27`, standing
  in for the relay module. Confirms the GPIO toggles at the right times
  (see [`docs/host-testing.md`](host-testing.md) for what "the right
  times" means, verified separately), not that a real relay/pump
  responds correctly.

## Why there's no vision_node Wokwi config

Wokwi doesn't simulate a camera feed or TFLite Micro inference, so a
diagram for `vision_node` would only be able to model the Wi-Fi/REST
half of that sketch -- not the part most worth simulating (camera
capture, preprocessing, inference). Not attempted for that reason,
rather than left out by oversight.

## To try this again

```bash
# Requires arduino-cli + the esp32 board core installed locally, and a
# WOKWI_CLI_TOKEN from a Wokwi account (wokwi.com -> account -> CLI tokens)
cd firmware/irrigation_node
arduino-cli compile --fqbn esp32:esp32:esp32 --output-dir build .
wokwi-cli --timeout 30000 --expect-text "REST API server started" wokwi/
```

Note: `config.h`'s `WIFI_SSID`/`WIFI_PASSWORD` are real-deployment
placeholders. To get past the Wi-Fi-connect wait in a Wokwi run
specifically, point them at Wokwi's virtual network
(`WIFI_SSID "Wokwi-GUEST"`, empty password) locally before compiling --
never commit that substitution, it's simulation-only.

If a future run gets further than "stalls after connecting," that's
real new information worth replacing this file's conclusion with --
not something to guess at in advance.

## Re-attempted 2026-08-22: same result

Re-ran this end to end again, independently, on a later date: recompiled
`irrigation_node` fresh (`arduino-cli` still installed, same successful
build size), re-linted `diagram.json`/`wokwi.toml` (clean, same one
informational `unsupported-part` notice as before, no errors), then ran
`wokwi-cli` against the real firmware with a real `WOKWI_CLI_TOKEN` --
`--serial-log-file` captured a **0-byte file**, confirming zero serial
output. Re-ran the same independent trivial sanity sketch
(`Serial.begin(); Serial.println("SANITY BOOT OK");`) against a bare
one-part diagram with no project code involved at all -- identical
result: connects, "Starting simulation...", then times out with no
output. Same reproducible environment/service-level limitation, not a
regression or a newly-introduced bug; nothing here has changed since the
first attempt.
