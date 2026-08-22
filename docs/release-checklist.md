# Release checklist

Every checkbox reflects real, verified evidence — see
[`docs/final-release-status.md`](final-release-status.md) for the full
detail behind each. Unchecked items are unchecked because they
genuinely aren't done, not out of caution.

## Repository

- [x] Working tree clean, no uncommitted changes at release time
- [x] `HEAD` matches `origin/main`
- [x] No secrets, credentials, or `.env` files tracked (verified against full git history, not just current tree)
- [x] `.gitignore` correctly excludes build artifacts, generated model copies, and run-specific logs
- [x] No large accidental files
- [x] License present (MIT) with dataset attribution noted separately

## README

- [x] Explains problem, solution, architecture in the opening section
- [x] Recruiter-scannable "At a glance" section
- [x] Technology stack table
- [x] Real, non-fabricated CI badges (4 workflows, all genuinely present and passing)
- [x] Verification status table distinguishing build-verified / logic-verified / deployed / simulated / blocked
- [x] Links to all supporting documentation
- [x] Known limitations stated plainly, not buried

## Architecture

- [x] [`docs/architecture.md`](architecture.md) — full system diagram with per-link verification status
- [x] Distinguishes implemented / simulated / cloud-validated / physically validated / unavailable
- [x] ESP32-CAM vision node's actual role clearly explained (not conflated with the AWS pipeline)

## ML

- [x] Model architecture and training approach documented
- [x] Real metrics reported (81.9% float, 65.8% quantized) with methodology for the quantization gap investigation
- [x] Known weak classes (Spider Mite, Target Spot) documented with root cause, not hidden
- [x] Class-label consistency verified across firmware/backend/training metadata
- [ ] Real-world (non-PlantVillage) accuracy measured — **not done, no field images available**

## Firmware

- [x] Both sketches compile against real ESP32 board definitions (CI)
- [x] Hardware-independent logic host-tested (`g++`, CI)
- [x] Wokwi simulation passing (local and GitHub Actions)
- [ ] Physical ESP32 bring-up — **BLOCKED, no hardware available**
- [ ] Physical ESP32-CAM bring-up — **BLOCKED, no hardware available**
- [ ] ESP32-CAM camera/vision simulation — **NOT SUPPORTED, Wokwi has no camera component**

## Flutter

- [x] `flutter analyze` clean
- [x] `flutter test` passing (19/19)
- [x] `flutter build web` succeeds
- [x] Real headless-browser (Playwright) runtime test — all 6 screens, 0 uncaught exceptions
- [x] Release APK builds successfully (20.7 MB)
- [ ] Physical/emulated Android or iOS runtime — **BLOCKED, no device/emulator available**

## AWS

- [x] Infrastructure defined as code (AWS SAM), `sam validate --lint` passing
- [x] Deployed for real (`smart-agriculture-system`, `ap-south-1`, 21/21 resources)
- [x] Real end-to-end diagnosis flow verified (upload → S3 → SQS → real inference → DynamoDB → poll)
- [x] Real chat API verified
- [x] IAM policies confirmed resource-scoped, no wildcards
- [x] Deploy workflow confirmed manual-only

## Wokwi

- [x] Local simulation passing, real firmware, deterministic marker (`WOKWI_IRRIGATION_READY`)
- [x] GitHub Actions simulation passing on a clean Ubuntu runner (real run ID recorded)
- [x] Root cause of the original zero-output stall documented, not just the fix
- [ ] ESP32-CAM/vision simulation — **NOT SUPPORTED**

## CI

- [x] 4 automatic workflows (firmware, Flutter, backend, plus manual deploy/Wokwi) all green on current `main`
- [x] No workflow requires a secret that isn't actually configured (Wokwi secret confirmed present via `gh secret list`)

## Security

- [x] Credentials only via GitHub encrypted secrets, never printed or committed
- [x] Full git history scanned for leaked secrets — none found
- [x] One real hardening fix applied (secret interpolation anti-pattern in a workflow)
- [x] IAM least-privilege confirmed
- [ ] API authentication/rate limiting — **not implemented, named as a known gap**

## Testing

- [x] 19 backend tests (real handler code, mocked AWS)
- [x] 19 Flutter tests (including real integration tests against a protocol-accurate simulator)
- [x] Firmware host-side logic tests (real execution, `g++`)
- [x] Real AWS end-to-end smoke tests
- [x] Real Wokwi simulation tests

## Demo

- [x] [`docs/demo-guide.md`](demo-guide.md) — 5-min and 10-min procedures
- [x] [`docs/final-demo.md`](final-demo.md) — full spoken script
- [x] [`docs/demo-assets.md`](demo-assets.md) + `demo/generate_demo_payload.py` — reproducible, secret-free demo payload, verified working against the live API
- [x] Fallback procedure documented for AWS/Wokwi unavailability

## Resume

- [x] [`docs/resume-project-entry.md`](resume-project-entry.md) — 1-line through 5-bullet versions, ATS keywords
- [x] [`docs/recruiter-version.md`](recruiter-version.md) — role-specific versions (SWE, full-stack, ML, embedded, cloud)

## Interview

- [x] [`docs/interview-preparation.md`](interview-preparation.md) — 30 questions, 8 categories
- [x] [`docs/final-interview-preparation.md`](final-interview-preparation.md) — 50 questions, 25 categories, with follow-ups on key questions

## Portfolio

- [x] [`docs/project-presentation.md`](project-presentation.md) — 30-second to 5-minute explanations
- [x] [`docs/linkedin-project-post.md`](linkedin-project-post.md) — draft announcement post
- [x] [`docs/technical-deep-dive.md`](technical-deep-dive.md) — implementation-level reference, written from actual source
- [x] [`docs/final-release-status.md`](final-release-status.md) — the single source of truth for what's PASS/SIMULATED/BLOCKED/NOT SUPPORTED
