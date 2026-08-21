# Hardware validation checklist

Use this once physical ESP32 hardware is available. Nothing on this
list has been checked off yet — every box here is genuinely open. Work
through it in order; each section assumes the previous one passed.

Related reading: [`wiring.md`](wiring.md) (pinout),
[`bring-up-checklist.md`](bring-up-checklist.md) (library install and
first-boot detail), [`DEPLOYMENT.md`](DEPLOYMENT.md) (the full
start-from-zero runbook this checklist is the hardware slice of).

## Board identification

- [ ] Irrigation board confirmed as a genuine ESP32 dev board (not
      ESP32-S2/S3/C3 — different board definition, `esp32:esp32:esp32`
      won't match)
- [ ] Vision board confirmed as AI-Thinker ESP32-CAM specifically (pin
      mapping in `firmware/vision_node/camera_pins.h` is AI-Thinker's;
      a different ESP32-CAM variant needs different pins)

## USB connection

- [ ] Irrigation ESP32 enumerates as a serial port when plugged in
      (check Device Manager / `ls /dev/tty*`)
- [ ] ESP32-CAM's USB-to-serial adapter enumerates (the board itself
      has no onboard USB)
- [ ] Correct COM port identified for each board

## Flashing

- [ ] `arduino-cli core install esp32:esp32` (or Arduino IDE board
      manager) completed
- [ ] Irrigation node: `arduino-cli compile --fqbn esp32:esp32:esp32
      firmware/irrigation_node` succeeds locally (already CI-verified;
      confirm it also works in your actual local toolchain)
- [ ] Irrigation node flashes without error: `arduino-cli upload -p
      <PORT> --fqbn esp32:esp32:esp32 firmware/irrigation_node`
- [ ] Vision node: PSRAM enabled in board settings before compiling
- [ ] Vision node: Partition Scheme set to "Huge APP (3MB No OTA/1MB
      SPIFFS)"
- [ ] Vision node: GPIO0 bridged to GND before power-up (flashing
      mode), disconnected before normal boot
- [ ] Vision node flashes without error

## Serial output

- [ ] Irrigation node prints "Connecting to Wi-Fi" then an IP address
      at 115200 baud
- [ ] Vision node prints "Model loaded." then "Camera ready." then an
      IP address
- [ ] Vision node does **not** halt at "Model setup failed" (if it
      does: PSRAM isn't actually enabled — recheck board settings)
- [ ] Vision node does **not** halt at "Camera setup failed" (if it
      does: check camera ribbon cable seating first)

## Wi-Fi

- [ ] Both boards join the configured SSID successfully
- [ ] Both boards' printed IPs are reachable from the phone that will
      run the app (same network/subnet)
- [ ] IPs are stable enough to use (or: router configured for a DHCP
      reservation per board's MAC, if IPs keep changing)

## Sensor wiring

- [ ] DHT11 wired per `wiring.md` (VCC→3.3V, GND→GND, DATA→GPIO4)
- [ ] `GET /sensors` returns non-null temperature/humidity under
      normal conditions
- [ ] Soil moisture sensor wired (VCC→3.3V, GND→GND, AOUT→GPIO34)
- [ ] Raw ADC values recorded at fully dry and fully wet (watch Serial
      output), and `SOIL_RAW_DRY`/`SOIL_RAW_WET` in `config.h` updated
      to match — **do not skip this**, the shipped values are
      placeholders
- [ ] `GET /sensors`'s `soilMoisture` percentage now tracks actual
      moisture changes sensibly after calibration

## Relay

- [ ] Relay module wired per `wiring.md` (VCC→5V, GND→GND, IN→GPIO27)
- [ ] Confirm on first boot whether the pump runs immediately
      (indicates active-LOW relay — flip `RELAY_ACTIVE_LOW` in
      `config.h` and reflash) or stays off (correct)
- [ ] `/pump/on` in MANUAL mode audibly/visibly switches the relay
- [ ] `/pump/off` switches it back

## Pump

- [ ] Pump powered from its **own** supply through the relay's
      COM/NO contacts — never from the ESP32's 3.3V/5V rail
- [ ] Pump actually moves water when the relay is on
- [ ] AUTO mode starts the pump below the dry threshold (confirm
      against your calibrated values)
- [ ] AUTO mode stops the pump above the wet threshold
- [ ] Pump stops on its own after `PUMP_RUN_MS` even if soil hasn't
      crossed the wet threshold yet (safety timer)
- [ ] Manually starting the pump via `/pump/on`, then switching to
      AUTO mode mid-run, does **not** cause the safety timer to
      unexpectedly cut it off (this is the origin-tracking behavior —
      logic-verified by a host test, never physically observed)

## Camera

- [ ] ESP32-CAM captures a frame without error (no repeated "Camera
      capture failed" in Serial output)
- [ ] Point the camera at a clearly different scene (e.g. a hand vs.
      a plain wall) and confirm the Serial-printed prediction actually
      changes — a basic sanity check that inference is responding to
      the actual image, not returning a constant

## Inference

- [ ] `Prediction: <class> (<confidence>% confidence)` prints to
      Serial on each capture interval
- [ ] Confidence values are in a sane range (0–100%), not obviously
      garbage
- [ ] Point the camera at a real tomato leaf (healthy or diseased, if
      available) and record what class it predicts — this is real
      field data this repo doesn't currently have anywhere

## REST

- [ ] `curl http://<irrigation-ip>/sensors` returns valid JSON matching
      the documented shape
- [ ] `curl http://<vision-ip>/latest` returns valid JSON with
      `hasResult: true` after at least one successful capture
- [ ] `hasResult: false` correctly right after boot, before the first
      successful inference

## Mobile communication

- [ ] `mobile_app/.env`'s `IRRIGATION_NODE_HOST`/`VISION_NODE_HOST`
      updated to the real boards' IPs
- [ ] App's Sensor Dashboard shows live data matching what `curl`
      shows directly
- [ ] App's Irrigation Control mode switch and pump buttons actually
      affect the real hardware
- [ ] App's Diagnosis screen's on-device-result poll shows the same
      class/confidence Serial is printing
- [ ] Device Tests screen correctly reports both nodes as reachable

## Sign-off

Once every box above is checked, the physical validation gap this
repository has documented throughout is closed for the firmware side.
Update `docs/end-to-end-test-plan.md`'s Hardware and Vision sections
from BLOCKED to their real, observed results — including any bugs this
checklist surfaces, which is exactly what it's for.
