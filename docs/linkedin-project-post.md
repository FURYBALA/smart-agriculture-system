# LinkedIn project post — draft

A draft announcement post, written only from verified facts in this
repository. Edit freely for voice, but keep the specifics — they're
what make the post credible rather than generic.

---

🌱 **Built a Smart Agriculture System: ESP32 + on-device ML + Flutter +
AWS, and actually deployed all of it.**

For my microcontrollers course project, I wanted to go further than a
report — I wanted a working system I could actually run, test, and
deploy for real.

**What it does:**
🔧 Two ESP32 nodes handle the physical side — one automates soil-
moisture irrigation with a relay pump and a safety cutoff timer, the
other (ESP32-CAM) runs an on-device machine learning model that
classifies 8 tomato leaf conditions from a single camera frame.

🧠 The ML model is a custom CNN I trained from scratch and quantized to
INT8 — 69.9 KB, small enough to run directly on the ESP32-CAM via
TensorFlow Lite Micro. No cloud round-trip needed for on-device
inference.

📱 A Flutter app (6 screens) ties it together: live sensor dashboard,
irrigation control, disease diagnosis, history, and a plant-care
chatbot powered by Gemini.

☁️ I also deployed a full serverless AWS backend as an alternative
inference path — API Gateway → Lambda → S3 → SQS → DynamoDB — as
real, live infrastructure-as-code (AWS SAM), not just a diagram.

**What I'm most proud of isn't the features — it's the debugging.**
A few real problems I found and fixed along the way:
- A quantized-model accuracy drop that turned out to be a biased
  evaluation sample, not quantization — found by comparing float vs.
  quantized predictions image-by-image (99.2% agreement ruled out the
  obvious suspect)
- A Lambda Layer packaging bug that only appeared in the real AWS
  deployment, never in local tests, because local tests bypass the
  actual build step — root-caused by downloading and inspecting the
  deployed artifact directly
- A circuit simulator (Wokwi) that connected but produced zero output
  across multiple attempts — looked like an environment issue until I
  tested it against Wokwi's own official example project, which
  worked immediately and let me find the real cause: a missing config
  field in my circuit diagram

**Without physical hardware in hand during development**, I leaned on
real automated testing instead: 38+ unit/integration tests across
firmware (C++), backend (Python), and mobile (Dart), a real headless-
browser end-to-end test, and a real circuit simulation reproducible in
CI on a clean GitHub Actions runner.

Everything here is real and verifiable — deployed AWS resources,
passing CI, an actual trained model, actual test output. The project's
documentation is deliberately explicit about what's genuinely tested
versus what still needs physical hardware I didn't have access to.

Repo: github.com/FURYBALA/smart-agriculture-system

#EmbeddedSystems #IoT #MachineLearning #TensorFlow #Flutter #AWS
#ESP32 #CloudComputing #SoftwareEngineering

---

*(Shorter variant, if the above is too long for the platform:)*

🌱 Built and deployed a Smart Agriculture System: two ESP32 nodes
(automated irrigation + on-device tomato disease detection via a
custom CNN quantized to 69.9 KB), a 6-screen Flutter app, and a real,
deployed AWS serverless backend (API Gateway/Lambda/S3/SQS/DynamoDB).

The part I'm proudest of: the real bugs I found and fixed along the
way — a biased ML evaluation sample masquerading as a quantization
problem, a Lambda Layer bug that only showed up in the actual AWS
deployment, and a circuit-simulator config bug I isolated by testing
against a known-working reference project instead of guessing.

38+ automated tests, real CI, a real AWS deployment I verified
end-to-end. Repo: github.com/FURYBALA/smart-agriculture-system

#EmbeddedSystems #MachineLearning #Flutter #AWS #ESP32
