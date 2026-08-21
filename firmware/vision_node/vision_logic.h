// Pure, hardware-independent preprocessing/postprocessing math for the
// vision node: RGB565 pixel unpacking + INT8 quantization on the way in,
// and dequantize-and-argmax on the way out.
//
// No Arduino.h, no esp_camera.h, no TFLite Micro dependency -- everything
// here is plain arithmetic on parameters the caller provides, so it can
// be exercised by a host-side test
// (firmware/test/test_vision_logic.cpp) without an ESP32-CAM board or a
// TFLite Micro build. vision_node.ino's preprocessFrame()/runInference()
// call these functions and do the actual camera/interpreter I/O around
// them.
#pragma once

#include <cstdint>

namespace vision_logic {

// One RGB565 pixel's two bytes (big-endian, as esp32-camera emits them --
// see vision_node.ino's preprocessFrame() comment) decoded into
// normalized [0, 1] R/G/B channel values -- the same
// (channel * 255) / maxChannelValue / 255.0f chain preprocessFrame()
// uses, kept identical here so this is a real extraction, not a
// reimplementation with different rounding behavior.
struct RgbNormalized {
  float r;
  float g;
  float b;
};

inline RgbNormalized decodeRgb565BigEndian(uint8_t highByte, uint8_t lowByte) {
  uint16_t p = (static_cast<uint16_t>(highByte) << 8) | lowByte;
  uint8_t r5 = (p >> 11) & 0x1F;
  uint8_t g6 = (p >> 5) & 0x3F;
  uint8_t b5 = p & 0x1F;

  RgbNormalized out;
  out.r = (r5 * 255) / 31.0f / 255.0f;
  out.g = (g6 * 255) / 63.0f / 255.0f;
  out.b = (b5 * 255) / 31.0f / 255.0f;
  return out;
}

// Converts one already-normalized [0,1] channel value to the INT8 the
// model expects. The original preprocessFrame() cast straight to int8_t
// without clamping, relying on the input always landing in [0,1] --
// correct as long as that invariant holds, but static_cast<int8_t> of an
// out-of-range float is undefined behavior if it's ever violated by a
// stray rounding error. The clamp here is a defensive fix with no effect
// when the invariant holds (0..1 in, and this model's scale/zero-point
// map that range exactly onto [-128, 127]).
inline int8_t quantizeChannel(float normalized, float scale, int zeroPoint) {
  float quantized = normalized / scale + zeroPoint;
  if (quantized < -128.0f) quantized = -128.0f;
  if (quantized > 127.0f) quantized = 127.0f;
  return static_cast<int8_t>(quantized);
}

// Dequantizes one INT8 output logit back to a float probability, using
// the *output* tensor's own scale/zero-point (not the input's -- they're
// generally different values, both discovered from the interpreter at
// runtime in the real model, never hardcoded).
inline float dequantizeOutput(int8_t raw, float outScale, int outZeroPoint) {
  return (raw - outZeroPoint) * outScale;
}

// argmax over the num classes' raw INT8 output logits, returning the
// winning class index and its dequantized confidence. Mirrors
// runInference()'s loop exactly (strict '>' so the first-seen class wins
// a tie, matching the .ino).
struct Prediction {
  int classIndex;
  float confidence;
};

inline Prediction argmaxDequantized(const int8_t* rawOutputs, int numClasses,
                                     float outScale, int outZeroPoint) {
  int bestIdx = 0;
  float bestProb = -1.0f;
  for (int i = 0; i < numClasses; i++) {
    float prob = dequantizeOutput(rawOutputs[i], outScale, outZeroPoint);
    if (prob > bestProb) {
      bestProb = prob;
      bestIdx = i;
    }
  }
  return Prediction{bestIdx, bestProb};
}

}  // namespace vision_logic
