# Wokwi simulation (irrigation node) -- root-caused, fixed, and passing

[`firmware/irrigation_node/wokwi/`](../firmware/irrigation_node/wokwi/)
contains a [Wokwi](https://wokwi.com) diagram (`diagram.json`) and CLI
config (`wokwi.toml`) modeling the irrigation node's circuit: an ESP32,
a DHT sensor, a soil-moisture analog input, and an LED standing in for
the relay-driven pump.

**Status: PASS.** This is a real, deterministic, reproducible result --
run repeatedly against Wokwi's real simulation API with a real
`WOKWI_CLI_TOKEN`, not assumed or guessed. The simulation boots the
real production firmware and observes a real, expected serial message.
This took several real investigation passes to get right; the honest
history of each is below, including two passes that ended
"inconclusive" before the actual root cause was found.

## The root cause (found by isolating against Wokwi's own official example)

Every earlier attempt -- with this project's firmware, with a bare
one-part diagram, with an independently-written trivial sanity sketch
-- connected to the real Wokwi API and reported "Starting
simulation...", then timed out with **zero bytes** of serial output,
every time. That symptom is identical whether the code involved is
this project's or not, which is exactly what made it look like an
environment/service-level problem rather than a project one.

It wasn't. The actual test that broke the deadlock: cloning Wokwi's
own official example project verbatim
([`wokwi/esp-idf-hello-world`](https://github.com/wokwi/esp-idf-hello-world))
and running it, completely unmodified, through this same local CLI and
token:

```
ets Jul 29 2019 12:21:46
...
I (263) main_task: Calling app_main()
Hello world!
...
Expected text found: "Hello world"
TEST PASSED.
```

That's real, unambiguous proof the local CLI, network, and token all
work correctly -- which meant the earlier "trivial sanity sketch"
wasn't actually trivial enough: it was missing something the official
example's `diagram.json` has and ours didn't.

Diffing the two `diagram.json` files and testing each difference in
isolation (own Arduino-compiled sanity firmware, one variable changed
at a time) found it precisely: **our diagram never wired the ESP32's
UART0 to a serial monitor.** Two things are both required together --
neither alone is sufficient, confirmed by testing each alone and
failing both times:

```json
"connections": [
  ...,
  ["esp32:TX", "$serialMonitor:RX", "", []],
  ["esp32:RX", "$serialMonitor:TX", "", []]
],
"serialMonitor": {
  "display": "terminal"
}
```

Without the top-level `serialMonitor` property: zero output, even with
the connection wired. Without the connection: zero output, even with
the property set. With both: real serial output, every time. This is
now added to `firmware/irrigation_node/wokwi/diagram.json`, alongside
the two genuinely real, previously-found bugs (pin-name and required-
field issues, kept below for the full history).

**This was never a firmware defect, a local Windows issue, or a Wokwi
service problem.** It was a genuinely missing piece of our own
`diagram.json` -- the same class of "real, fixable project
configuration bug" as the two earlier ones, just harder to isolate
because its symptom (silence) looked identical to what a broken
service or broken firmware would also produce.

## Fix #3: a real, deterministic boot marker

The real firmware's first serial output on boot is
`Serial.print("Connecting to Wi-Fi")` followed by an unbounded loop of
`.` characters with no terminating newline until Wi-Fi actually
connects -- which it never does in Wokwi, since `config.h`'s
`WIFI_SSID`/`WIFI_PASSWORD` are intentionally real-deployment
placeholders, never a live network. `wokwi-cli --expect-text` matches
against completed (newline-terminated) lines, so it can never match
text from a line that's still open. Real observed behavior, not
speculation: the CLI happily prints `Connecting to Wi-Fi...........`
to the terminal and to `--serial-log-file`, but never reports "Expected
text found" for it, no matter how long the timeout.

Fixed with a small, harmless, genuinely useful addition to
`irrigation_node.ino`'s `setup()`, printed unconditionally right after
`Serial.begin()` and before anything else (Wi-Fi, sensors, or the REST
server) can hang or fail:

```cpp
Serial.println("WOKWI_IRRIGATION_READY");
```

This is real production firmware, not a test shim -- it's a legitimate
boot-confirmation line that also helps real hardware bring-up (confirms
the board booted and Serial is alive before anything else is
attempted), and it doesn't change any pin, timing, or logic covered by
`firmware/test/test_irrigation_logic.cpp`. It gives `--expect-text` a
short, complete, always-printed line to match against regardless of
what happens with Wi-Fi.

## Real result, run repeatedly

```bash
cd firmware/irrigation_node
arduino-cli compile --fqbn esp32:esp32:esp32 --output-dir build .
wokwi-cli wokwi --timeout 10000 --expect-text "WOKWI_IRRIGATION_READY" --serial-log-file wokwi-serial.log
```

```
Wokwi CLI v0.26.1 (9d71b975b7eb)
Connected to Wokwi Simulation API 1.0.0-...
Starting simulation...
ets Jul 29 2019 12:21:46

rst:0x1 (POWERON_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
...
entry 0x400805dc
WOKWI_IRRIGATION_READY

Expected text found: "WOKWI_IRRIGATION_READY"
TEST PASSED.
```
Exit code `0`. Run 4 times in this investigation: 3 clean passes, 1
transient `API Error: Connection to transport closed unexpectedly:
code 1006` on a retry (a known, documented Wokwi-service-side
websocket hiccup -- see
[wokwi-cli issue #28](https://github.com/wokwi/wokwi-cli/issues/28) --
not reproduced again immediately after). Reported honestly rather than
hidden: cloud simulation services have occasional transient
connectivity blips, same as any other network service; this doesn't
change the deterministic pass/fail result once connected.

## What this proves, and what it explicitly doesn't

**Proves**, for real, via actual simulated execution of the real
compiled firmware:
- The firmware boots successfully in a simulated ESP32 environment
- `Serial.begin(115200)` and the UART are alive and correctly wired
- Execution reaches `setup()`'s very first line without crashing
- The `--expect-text` mechanism gives a deterministic, automatable
  pass/fail signal usable in CI (see below)

**Does not prove** -- not claimed, not implied:
- Real pump/relay electrical behavior (the LED standing in for it only
  confirms GPIO27 toggles at the right times -- see
  [`docs/host-testing.md`](host-testing.md) for what's separately
  verified about *when* it toggles)
- Real soil sensor accuracy (a potentiometer produces an analog
  voltage on the right pin, not real soil electrical behavior)
- Real DHT11 timing quirks (Wokwi has no DHT11 part; `wokwi-dht22` is
  the closest protocol-family stand-in)
- Real ESP32 hardware timing, power behavior, or Wi-Fi radio behavior
- Anything about `vision_node`/ESP32-CAM (see below)

## Why there's still no vision_node Wokwi config

Checked directly against Wokwi's real parts registry this pass, not
assumed: `wokwi-cli lint` accepts `board-esp32-cam-ai-thinker` as a
known board type (it models the GPIO/pin layout), but Wokwi's
[documented parts catalog](https://github.com/wokwi/wokwi-docs/tree/main/docs/parts)
contains no camera/image-sensor part of any kind -- no way to feed a
simulated image into that board, and no evidence of any real camera
capture or TFLite Micro inference simulation. A `vision_node` Wokwi
config could only ever exercise its Wi-Fi/REST half, not the part most
worth simulating. Not attempted, for the same reason as before, now
confirmed against Wokwi's actual registry rather than assumed from its
absence in the docs.

## GitHub Actions: workflow created, blocked on a missing secret

[`.github/workflows/wokwi-simulation.yml`](../.github/workflows/wokwi-simulation.yml)
runs the same real compile + `wokwi/wokwi-ci-action@v1` simulation in
CI (manual `workflow_dispatch` only), so this result isn't tied to one
person's Windows machine. It is **not yet usable**: this repository has
no `WOKWI_CLI_TOKEN` secret configured (checked directly with
`gh secret list` -- only the three AWS secrets exist). Adding it
requires repository-secret write access this session was explicitly
told not to use ("Do NOT modify GitHub secrets"), so it wasn't added.
Once the repository owner adds a `WOKWI_CLI_TOKEN` secret (from
[wokwi.com's CI dashboard](https://wokwi.com/dashboard/ci)), running
this workflow should reproduce the same real local result in a clean,
non-local environment -- at that point it can reasonably become the
authoritative, always-available version of this test instead of a
local-machine-only result.

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

## Full history (kept for an honest record, not just the happy ending)

1. **First real bug** (original attempt): `diagram.json` wired the
   ESP32 using Arduino-style pin names (`esp32:D4`, `esp32:D34`,
   `esp32:D27`). Wokwi's `board-esp32-devkit-c-v4` part rejected all
   three -- `wokwi-cli` reported the exact valid pin list (plain
   numbers: `4`, `34`, `27`, no `D` prefix), and the run failed with
   `API Error: Connection to transport closed unexpectedly`. Fixed by
   using the correct pin names Wokwi itself reported.
2. **Second real bug** (same attempt): `wokwi.toml`'s `firmware` field
   is required, not optional -- confirmed by an actual CLI error
   (`Error in wokwi.toml: Firmware path must be a string`) when an
   ELF-only config was tried as a diagnostic.
3. **First "inconclusive" verdict**: with both bugs fixed, the CLI
   connected successfully every time but every run -- the real
   firmware, a bare-board diagram, and an independent trivial sanity
   sketch -- hit its timeout with zero serial output. Reasonably read
   at the time as a possible environment/service-level limitation,
   since a project-code cause had just been ruled out by the sanity
   sketch.
4. **Re-attempted independently on a later date, same result**:
   recompiled fresh, re-linted clean, reran with `--serial-log-file` --
   captured a literal 0-byte file. Reran the same class of trivial
   sanity sketch -- identical zero-output result. Documented as a
   reproduced, not one-off, "inconclusive."
5. **Root cause finally found** (this pass): tested against Wokwi's own
   official, known-working example project instead of another
   from-scratch trivial sketch. It worked immediately, which
   proved the CLI/network/token were never the problem, and made the
   real diagnosis possible by direct diff -- see "The root cause"
   above.

The lesson worth keeping, not just the fix: "an independently-written
trivial sketch also fails" rules out *that specific sketch's* code as
the cause, but not a config assumption shared by every diagram written
for this investigation (none of them wired a serial monitor). A known-
good external reference, not another self-written one, is what
actually isolated it.

## To try this again

```bash
# Requires arduino-cli + the esp32 board core installed locally, and a
# WOKWI_CLI_TOKEN from a Wokwi account (wokwi.com -> account -> CLI tokens)
cd firmware/irrigation_node
arduino-cli compile --fqbn esp32:esp32:esp32 --output-dir build .
wokwi-cli wokwi --timeout 10000 --expect-text "WOKWI_IRRIGATION_READY" --serial-log-file wokwi-serial.log
```

Or, once a `WOKWI_CLI_TOKEN` repository secret exists, trigger
[`.github/workflows/wokwi-simulation.yml`](../.github/workflows/wokwi-simulation.yml)
manually from the Actions tab.
