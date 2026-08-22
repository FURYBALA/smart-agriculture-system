# Resume / project entry — draft copy

Pick the length that fits the space you have. All versions are built
from the same verified facts — swap wording to match your voice, but
keep the specifics (they're what make it checkable, not generic).

## 1-line version

Smart Agriculture System — ESP32 irrigation + on-device ML disease
detection (custom CNN, INT8 TFLite) + Flutter app + AWS serverless
backend, deployed and tested end-to-end (React/Flutter, Python, AWS
Lambda/API Gateway/DynamoDB, TensorFlow, C++/embedded).

## 3-bullet version

- Built a dual-node ESP32 IoT system (automated soil-moisture
  irrigation + on-device tomato leaf disease detection) and a Flutter
  mobile app unifying both, backed by a self-hosted AWS serverless
  inference pipeline (API Gateway → Lambda → S3 → SQS → DynamoDB)
- Trained a custom CNN from scratch, quantized to INT8 (69.9 KB) for
  TensorFlow Lite Micro on-device inference; root-caused an 18-point
  accuracy regression to a biased evaluation sample rather than
  quantization, then measurably improved the two weakest classes via
  targeted data rebalancing
- Deployed the AWS backend for real via GitHub Actions CI/CD, verified
  end-to-end with live API tests (S3 → SQS → Lambda inference →
  DynamoDB), and found/fixed a production-only Lambda Layer packaging
  bug invisible to any local test

## 4-bullet version

- Designed and implemented a dual-node ESP32 IoT system: closed-loop
  automated irrigation (soil moisture + DHT11, relay pump control with
  a safety cutoff timer) and an ESP32-CAM running on-device disease
  classification via TensorFlow Lite Micro
- Built a 6-screen Flutter app (Provider state management) unifying
  both nodes plus Gemini Vision/text AI, with platform-conditional
  local persistence (native `sqflite` / web `sqflite_common_ffi_web`)
  — verified with a real headless-browser (Playwright) test run, not
  just a build check
- Architected and deployed a serverless AWS backend
  (API Gateway/Lambda/S3/SQS/DynamoDB) as infrastructure-as-code (AWS
  SAM), with least-privilege IAM scoping and a manual-gated CI/CD
  deploy pipeline; verified live with real end-to-end API tests
- Wrote 38+ automated tests across firmware (C++/`g++`), backend
  (Python/`pytest`), and mobile (Dart/`flutter test`), plus a real
  circuit simulation pipeline (Wokwi) integrated into CI on a clean
  Ubuntu runner

## 5-bullet version

- Designed and implemented a dual-node ESP32 IoT system: closed-loop
  automated irrigation (soil moisture + DHT11 sensing, relay pump
  control with an origin-tracked safety cutoff timer) and an
  ESP32-CAM running on-device 8-class disease classification
- Trained a custom CNN from scratch (Keras, ~61K params, 81.9% float
  validation accuracy) and quantized it to INT8 (69.9 KB) for
  TensorFlow Lite Micro; diagnosed a quantization accuracy regression
  down to a biased evaluation sample via image-by-image prediction
  comparison, then improved the weakest classes through targeted
  training-data rebalancing
- Built a 6-screen Flutter app (Provider) unifying both ESP32 nodes and
  Gemini AI, with platform-conditional persistence and a real
  headless-browser (Playwright) end-to-end test that found and fixed a
  web-only database crash
- Architected and deployed a serverless AWS backend
  (API Gateway/Lambda/S3/SQS/DynamoDB) as infrastructure-as-code,
  least-privilege IAM, GitHub Actions CI/CD; verified live with a real
  async upload → inference → poll flow and found/fixed a production-
  only Lambda Layer packaging bug no local test could catch
- Delivered 38+ automated tests (C++, Python, Dart) plus a real
  firmware circuit simulation (Wokwi) reproducible in CI, after
  root-causing a zero-output stall to a missing diagram configuration
  by diffing against a known-working reference project

## ATS keywords

Embedded systems, ESP32, ESP32-CAM, IoT, C++, Arduino framework, REST
API, TensorFlow, TensorFlow Lite, TensorFlow Lite Micro, machine
learning, CNN, convolutional neural network, model quantization, INT8
quantization, computer vision, image classification, Flutter, Dart,
mobile development, cross-platform development, state management,
SQLite, AWS, Amazon Web Services, AWS Lambda, API Gateway, Amazon S3,
Amazon SQS, DynamoDB, serverless, infrastructure as code, AWS SAM,
IAM, least privilege, CI/CD, GitHub Actions, Python, pytest, unit
testing, integration testing, end-to-end testing, test automation,
debugging, root cause analysis, agile development, version control,
Git, technical documentation.

## Technical skills demonstrated

| Category | Specific skills |
|---|---|
| Embedded / IoT | C++, Arduino framework, ESP32/ESP32-CAM, sensor interfacing (DHT11, analog ADC), relay/GPIO control, REST API design over `WebServer`, PSRAM memory management, real-time state machines |
| Machine learning | TensorFlow/Keras, CNN architecture design, training-from-scratch, post-training INT8 quantization, TensorFlow Lite Micro deployment, dataset curation, confusion-matrix root-cause analysis |
| Mobile development | Flutter, Dart, Provider (state management), `sqflite`, async/await patterns, platform-conditional code (`kIsWeb`), REST client integration |
| Cloud / backend | AWS Lambda, API Gateway, S3, SQS, DynamoDB, AWS SAM (infrastructure as code), IAM policy design, Python 3.12, serverless architecture, async pipeline design |
| DevOps / CI/CD | GitHub Actions, multi-language CI (C++/Dart/Python), automated deployment pipelines, secrets management, Docker (via `sam build --use-container`) |
| Testing | `pytest`, `moto` (AWS mocking), `flutter test`, host-side C++ unit testing, integration testing, headless-browser end-to-end testing (Playwright), circuit simulation (Wokwi) |
| Engineering practice | Root-cause debugging, technical documentation, git version control, evidence-based verification, security-conscious credential handling |
