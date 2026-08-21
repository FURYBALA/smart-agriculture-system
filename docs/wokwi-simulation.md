# Wokwi simulation (irrigation node) -- config only, not executed

[`firmware/irrigation_node/wokwi/`](../firmware/irrigation_node/wokwi/)
contains a [Wokwi](https://wokwi.com) diagram (`diagram.json`) and CLI
config (`wokwi.toml`) modeling the irrigation node's circuit: an ESP32,
a DHT sensor, a soil-moisture analog input, and an LED standing in for
the relay-driven pump.

**This has not been run.** Wokwi's CLI simulation (`wokwi-cli`) requires
a `WOKWI_CLI_TOKEN` from a Wokwi account, which isn't available in this
project's dev environment. The config exists so someone with a Wokwi
account can run it; it is not evidence that the simulation has been
verified to work.

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

## To actually run this

```bash
npm install -g wokwi-cli   # or see https://docs.wokwi.com/wokwi-ci/getting-started
export WOKWI_CLI_TOKEN=...  # from wokwi.com account settings
cd firmware/irrigation_node
arduino-cli compile --fqbn esp32:esp32:esp32 --output-dir build .
wokwi-cli wokwi/
```

If you run this and it works (or doesn't), that's real information this
repo doesn't currently have -- worth updating this file with the actual
result rather than leaving it as an assumption either way.
