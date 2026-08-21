# Host-side firmware testing

Neither firmware sketch can be unit-tested as a whole without an ESP32
board -- `WiFi.h`, `WebServer.h`, `esp_camera.h`, and TFLite Micro's
interpreter all need the real target. But the parts of the firmware most
likely to have an actual logic bug (as opposed to a wiring problem) don't
need any of that: threshold comparisons, a state machine, and some
arithmetic. Those are pulled out into plain, dependency-free C++ headers
so they can be compiled and run with a normal desktop compiler.

## What's split out

| Header | Pure logic it holds |
|---|---|
| [`firmware/irrigation_node/irrigation_logic.h`](../firmware/irrigation_node/irrigation_logic.h) | soil-ADC-to-percent conversion, AUTO start/stop threshold decisions, pump cooldown, the origin-tracked auto-cutoff timer |
| [`firmware/vision_node/vision_logic.h`](../firmware/vision_node/vision_logic.h) | RGB565 byte decode + normalize, INT8 quantize/dequantize, argmax over the model's output |

Both headers take every input (including "now", instead of calling
`millis()`) as a plain parameter and return a value or a decision --
no `Arduino.h`, no hardware I/O. `irrigation_node.ino` and
`vision_node.ino` call into these headers and do the actual
`digitalWrite`/camera/interpreter calls around them; nothing about the
*production* code path changed, the decision logic just now also has an
address a host compiler can reach.

## Running the tests

```bash
cd firmware/test
g++ -std=c++17 -I ../irrigation_node test_irrigation_logic.cpp -o test_irrigation_logic && ./test_irrigation_logic
g++ -std=c++17 -I ../vision_node     test_vision_logic.cpp     -o test_vision_logic     && ./test_vision_logic
```

No Arduino IDE, `arduino-cli`, or ESP32 board required -- any C++17
compiler works. This also runs automatically in CI on every push (the
`host-logic-tests` job in `.github/workflows/firmware-compile.yml`,
using the GitHub Actions runner's own `g++`) alongside the existing
`arduino-cli` compile checks for both full sketches.

## What this does and doesn't prove

This proves the pump state machine, threshold math, and RGB565/INT8
quantization arithmetic behave correctly for the specific inputs the
tests exercise -- including the regression the pump-timer origin-tracking
fix exists to prevent (a manually-started pump must never be cut off by
the AUTO safety timer). It does **not** prove:

- the DHT11/soil sensor actually reads correctly on real hardware,
- the relay's active-high/active-low wiring is correct,
- the camera actually produces valid RGB565 frames,
- Wi-Fi, the REST server, or TFLite Micro's interpreter behave correctly
  on target,
- or anything about timing/power/electrical behavior.

Those remain in [`docs/bring-up-checklist.md`](bring-up-checklist.md) as
physical-hardware validation that hasn't been performed.
