# Hardware

Two independent nodes, per the report's dual-node architecture
(Table 3.1).

## Irrigation Node — plain ESP32 Dev Board

| Component | Signal | Pin |
|---|---|---|
| DHT11 | VCC | 3.3V |
| DHT11 | GND | GND |
| DHT11 | DATA | GPIO4 |
| Soil moisture sensor | VCC | 3.3V |
| Soil moisture sensor | GND | GND |
| Soil moisture sensor | AOUT | GPIO34 |
| Relay module | VCC | 5V |
| Relay module | GND | GND |
| Relay module | IN | GPIO27 |
| Water pump | +/− | Relay COM/NO, in series with pump's own power supply |

**Power**: 3.7V Li-ion battery through an AMS1117 regulator to 3.3V
for the ESP32, per the report's power module. **Power the pump from
its own supply switched through the relay** — never from the ESP32's
3.3V/5V rail.

**Relay logic**: most low-cost single-channel relays are active-LOW.
If the pump runs immediately on boot instead of staying off, flip
`RELAY_ACTIVE_LOW` in `firmware/irrigation_node/config.h`.

**Soil sensor calibration is required** before the percentage
thresholds mean anything — every sensor unit reads differently.
Watch raw `analogRead()` values in Serial output at fully dry and
fully wet, then set `SOIL_RAW_DRY` / `SOIL_RAW_WET` in `config.h`.

## Vision Node — ESP32-CAM (AI-Thinker)

No extra wiring beyond the onboard OV2640 camera — power and a
USB-serial programmer are all it needs.

- **PSRAM must be enabled** in board settings — the camera frame
  buffer and TFLite tensor arena together don't fit in internal SRAM
  alone.
- **Programming**: the ESP32-CAM has no onboard USB. Wire an
  FTDI/USB-serial adapter (`TX→U0R`, `RX→U0T`, `GND→GND`, `5V→5V`),
  bridge GPIO0 to GND before power-up to enter flashing mode, then
  disconnect GPIO0 and reset to run normally.
- **Arduino IDE settings**: Board = *AI Thinker ESP32-CAM*, Partition
  Scheme = *Huge APP (3MB No OTA/1MB SPIFFS)*, PSRAM = *Enabled*.

## Both nodes

Set `WIFI_SSID` / `WIFI_PASSWORD` in each node's `config.h`. On boot,
each prints its IP address to Serial — put those into
`mobile_app/.env` as `IRRIGATION_NODE_HOST` / `VISION_NODE_HOST` so
the app can find them. Both must be on the same Wi-Fi network as the
phone.
