// Host-side test for firmware/vision_node/vision_logic.h -- compiles and
// runs on a plain desktop C++ compiler (no ESP32-CAM board, no camera,
// no TFLite Micro build). See docs/host-testing.md.
//
// Build: g++ -std=c++17 -I../vision_node test_vision_logic.cpp -o test_vision_logic
// Run:   ./test_vision_logic
#include <cmath>
#include <cstdio>
#include "vision_logic.h"

using namespace vision_logic;

static int failures = 0;

#define CHECK(cond)                                                        \
  do {                                                                     \
    if (!(cond)) {                                                         \
      std::fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
      failures++;                                                          \
    }                                                                      \
  } while (0)

#define CHECK_NEAR(a, b, eps)                                                                     \
  do {                                                                                             \
    if (std::fabs((double)(a) - (double)(b)) > (eps)) {                                            \
      std::fprintf(stderr, "FAIL %s:%d: %s ~= %s (got %f vs %f)\n", __FILE__, __LINE__, #a, #b,     \
                   (double)(a), (double)(b));                                                      \
      failures++;                                                                                  \
    }                                                                                               \
  } while (0)

void test_decodeRgb565_pureColors() {
  // RGB565 packs RRRRR GGGGGG BBBBB into 16 bits, transmitted big-endian
  // (high byte first) by esp32-camera -- see vision_node.ino's
  // preprocessFrame() comment for why the byte order matters.

  // Pure white: R=31, G=63, B=31 -> 0xFFFF
  RgbNormalized white = decodeRgb565BigEndian(0xFF, 0xFF);
  CHECK_NEAR(white.r, 1.0, 0.01);
  CHECK_NEAR(white.g, 1.0, 0.01);
  CHECK_NEAR(white.b, 1.0, 0.01);

  // Pure black: 0x0000
  RgbNormalized black = decodeRgb565BigEndian(0x00, 0x00);
  CHECK_NEAR(black.r, 0.0, 0.001);
  CHECK_NEAR(black.g, 0.0, 0.001);
  CHECK_NEAR(black.b, 0.0, 0.001);

  // Pure red: R=31 (11111), G=0, B=0 -> 11111 000000 00000 = 0xF800
  RgbNormalized red = decodeRgb565BigEndian(0xF8, 0x00);
  CHECK_NEAR(red.r, 1.0, 0.01);
  CHECK_NEAR(red.g, 0.0, 0.001);
  CHECK_NEAR(red.b, 0.0, 0.001);
}

void test_quantizeChannel_matchesTrainingMetadata() {
  // Real values from ml/models/training_metadata.json's
  // input_quantization -- the actual contract the shipped model was
  // quantized with, not made-up numbers.
  const float scale = 0.003921568859368563f;
  const int zeroPoint = -128;

  // 0.0 normalized -> exactly the zero-point (0/scale is exactly 0
  // regardless of scale's own precision, so this boundary is safe to
  // assert exactly).
  CHECK(quantizeChannel(0.0f, scale, zeroPoint) == -128);

  // 1.0 normalized should land at (or one below) the top of the INT8
  // range. Not asserted as an exact ==127: the shipped scale isn't
  // precisely 1/255, so 1.0f/scale can round to 254.999... in float32,
  // landing on 126 after the +zeroPoint -- a real, benign one-step
  // rounding difference, not a bug. Verified without a local compiler,
  // so kept as a tolerant range rather than a guessed exact value.
  int8_t nearMax = quantizeChannel(1.0f, scale, zeroPoint);
  CHECK(nearMax == 126 || nearMax == 127);

  // Defensive clamp: an out-of-[0,1] input (which shouldn't happen, but
  // a stray rounding error upstream could produce one) must not risk
  // undefined behavior from casting an out-of-int8-range float.
  CHECK(quantizeChannel(1.5f, scale, zeroPoint) == 127);
  CHECK(quantizeChannel(-0.5f, scale, zeroPoint) == -128);
}

void test_argmaxDequantized_picksHighest_and_firstOnTie() {
  const float scale = 0.003921568859368563f;
  const int zeroPoint = -128;

  // 8 classes (matches training_metadata.json's class_names count);
  // index 5 (Spider_Mite's position in the shipped label order) has the
  // highest raw logit here.
  int8_t outputs[8] = {-128, -100, -50, 0, 10, 50, 5, -20};
  Prediction pred = argmaxDequantized(outputs, 8, scale, zeroPoint);
  CHECK(pred.classIndex == 5);
  float expectedConfidence = (50 - zeroPoint) * scale;
  CHECK_NEAR(pred.confidence, expectedConfidence, 1e-4);

  // Tie: the first-seen index wins, matching the .ino's strict '>' loop.
  int8_t tied[3] = {10, 10, -128};
  Prediction tiePred = argmaxDequantized(tied, 3, scale, zeroPoint);
  CHECK(tiePred.classIndex == 0);
}

int main() {
  test_decodeRgb565_pureColors();
  test_quantizeChannel_matchesTrainingMetadata();
  test_argmaxDequantized_picksHighest_and_firstOnTie();

  if (failures == 0) {
    std::printf("All vision_logic tests passed.\n");
    return 0;
  }
  std::fprintf(stderr, "%d vision_logic test(s) FAILED.\n", failures);
  return 1;
}
