# Interview cheat sheet

One page. For the full versions, see
[`docs/final-interview-preparation.md`](final-interview-preparation.md)
(50 Q&A) and [`docs/project-presentation.md`](project-presentation.md)
(pitches by length).

| | |
|---|---|
| **Project** | Dual-node ESP32 IoT + AI system: automated irrigation + on-device tomato disease detection, unified in a Flutter app, with a deployed AWS serverless backend as an alternative cloud inference path |
| **Architecture** | 3 independent layers (firmware / mobile / optional cloud), REST over local Wi-Fi, async upload→queue→infer→poll on AWS |
| **ML** | Custom CNN from scratch, 81.9% float / 65.8% INT8-quantized accuracy, 69.9 KB, TensorFlow Lite Micro on-device |
| **Firmware** | C++/Arduino, 2 ESP32 nodes, hardware-independent logic host-tested (`g++`), full sketches compiled against real board defs in CI |
| **Flutter** | 6 screens, `Provider`, 19 tests passing, real headless-browser (Playwright) runtime verified, 20.7 MB release APK builds |
| **AWS** | API Gateway → Lambda → S3/SQS/DynamoDB, deployed for real (`ap-south-1`), 21/21 resources healthy, verified end-to-end |
| **Testing** | 38+ automated tests (C++/Python/Dart) + real AWS smoke tests + real Wokwi simulation (local and GitHub Actions) |
| **Security** | Secrets only via GitHub encrypted secrets, never committed (checked full git history); IAM scoped per-resource, no wildcards |
| **Hardest bug** | Wokwi's zero-serial-output stall — looked like an environment issue across two "inconclusive" passes, actually a missing `diagram.json` serial-monitor config, found by diffing against Wokwi's own official example project |
| **Biggest achievement** | A real, independently-verified AWS deployment with a genuine production-only bug found and fixed (Lambda Layer double-nesting), not just a `sam deploy` that happened to succeed |
| **Biggest limitation** | No physical ESP32/ESP32-CAM hardware and no physical/emulated mobile device — both genuinely unavailable, stated everywhere, never worked around |
| **Future improvement** | Real hardware bring-up (highest value), then real-world model fine-tuning on actual garden photos |

## Top 15 questions, one-sentence answers

1. **What is this project?** A dual-node ESP32 IoT system for irrigation and on-device plant disease detection, unified in a Flutter app with an optional deployed AWS backend.
2. **Why two ESP32 nodes?** Different hardware requirements (camera + PSRAM for vision vs. simple sensors for irrigation) and independent failure domains.
3. **Why INT8 quantization?** To fit the model in ~70 KB for TFLite Micro on the ESP32-CAM's limited RAM.
4. **Why did quantized accuracy drop?** Investigated directly — a biased evaluation sample, not quantization itself (99.2% float-vs-quantized prediction agreement ruled quantization out).
5. **Why async inference on AWS?** Decouples API response time from inference latency and lets inference scale independently via SQS.
6. **How is the API secured?** Least-privilege IAM per Lambda, no wildcards; the API itself is intentionally unauthenticated since there's no user-account system.
7. **Is AWS actually deployed?** Yes — real account, `ap-south-1`, verified via live `curl` calls and direct DynamoDB/S3 checks, not just a successful `sam deploy`.
8. **Did you test on physical hardware?** No — genuinely unavailable; firmware compiles against real board defs and its logic is host-tested, but real hardware behavior is unverified, stated plainly.
9. **Did you test on a mobile device?** Not a physical/emulated device — but a real headless-browser (Playwright) test verified the actual web runtime, including finding and fixing a real bug.
10. **What's the hardest bug you found?** The Wokwi zero-output stall — see cheat sheet row above.
11. **How accurate is the model?** 81.9% float / 65.8% quantized on held-out PlantVillage images — not measured on real garden photos.
12. **What's the biggest limitation?** No physical hardware or mobile device validation.
13. **How would you productionize this?** API authentication/rate limiting, physical hardware bring-up, real-world model fine-tuning, and an application-level firmware watchdog.
14. **What did you personally build?** All of it — firmware, ML pipeline, Flutter app, and AWS backend — see [`docs/technical-deep-dive.md`](technical-deep-dive.md) for implementation specifics.
15. **Why should this count as more than a simple classifier project?** It's a full-stack system spanning embedded C++, trained/quantized ML, mobile development, and deployed cloud infrastructure, each with real automated tests and real bugs found and fixed — not just a model in a notebook.
