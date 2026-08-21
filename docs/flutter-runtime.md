# Flutter runtime target investigation

This app has never run on a physical device. What follows is what was
actually checked in this project's dev environment, in order, with real
results -- not an assumption that no runtime target exists.

## What was checked

```bash
flutter devices
```

- **Physical Android/iOS device**: none connected.
- **Android emulator**: none configured (`flutter emulators` lists
  none; creating one needs downloading a system image, not done here).
  The Android SDK itself is also incomplete in this environment
  (`flutter doctor` flags a missing `cmdline-tools` component and
  unaccepted licenses), so even building an installable APK isn't
  currently clean, separate from having anywhere to run it.
- **Windows desktop**: `flutter devices` lists it, but `flutter doctor`
  flags Visual Studio (with the "Desktop development with C++"
  workload) as not installed -- required to actually compile a Windows
  build. Not usable as-is.
- **Chrome**: not installed.
- **Edge**: installed, and *is* usable once `flutter config --enable-web`
  is set and `flutter create --platforms=web .` adds the (previously
  absent) `web/` platform files -- see below.

## Flutter web: real, mixed results

Assumed at first that `dart:io` usage (`File` in
`diagnosis_screen.dart` and `history_screen.dart`, for locally-cached
diagnosis photos) would make a web build fail outright. That assumption
was wrong and worth correcting rather than leaving stated as fact:
Flutter's web compiler has a stub `dart:io` that compiles fine; it only
throws at *runtime* if something actually calls an unsupported API.

**What was verified:**
```bash
flutter build web
```
succeeds -- a full, clean production build with no compile errors. This
is now a permanent CI check (`flutter-ci.yml`'s `flutter build web`
step) precisely because it wasn't obvious in advance whether it would
work.

**What was not verified:** actually running the built output in a
browser and observing it. Two real attempts, both with concrete,
specific outcomes -- not left untried:

1. `flutter run -d edge` -- the dart2js compile step alone took ~45+
   seconds before this environment's tooling limits made it impractical
   to wait through a full launch-and-interact cycle.
2. Serving `build/web` locally (`python -m http.server`) and using
   Edge's own headless CLI flags
   (`msedge --headless=new --screenshot=... http://127.0.0.1:8123/`) to
   capture a screenshot without needing Selenium/Playwright. This did
   **not** produce an isolated headless render of the app: it launched
   full interactive Edge under the environment's real default profile
   instead (confirmed from the process log -- it opened
   `copilot.microsoft.com`, the profile's normal new-tab page, not the
   target URL), spawning ~40 browser processes. No screenshot was
   produced. Killed and cleaned up rather than fought further with
   different flags -- this is a concrete, observed limitation of this
   specific Edge installation's headless mode in this environment, not
   an assumption that browser observation is impossible in general.

So:

- Whether `HistoryScreen` (which opens a `sqflite` database via
  `HistoryDatabase`, and is kept mounted at all times by `HomeShell`'s
  `IndexedStack`) fails gracefully or crashes on web is **not
  confirmed either way**. `sqflite` has no web implementation without
  the separate `sqflite_common_ffi_web` package, which this project
  doesn't depend on. Reasoned prediction based on reading the code
  (not an observed result): the `FutureBuilder`/`_ErrorList` pattern
  already in `history_screen.dart` would likely turn that into a
  caught, displayed error rather than an app-wide crash -- but that's
  a prediction, not something that's been watched happen.
  - Fix scope note, deliberately not done: making History (and image
    storage) actually work correctly on web would mean swapping
    `sqflite` for `sqflite_common_ffi_web` and replacing `dart:io File`
    with an abstraction that works on both platforms -- a real,
    multi-file architecture change, not a quick patch. Out of scope for
    this pass (see the "don't rebuild working code" constraint this
    audit itself was given); noted here rather than silently worked
    around.
- Whether the other five screens (Sensor Dashboard, Irrigation Control,
  Disease Diagnosis, Chatbot, Device Tests) render and behave correctly
  in a browser is also unconfirmed for the same reason.

## Bottom line

Flutter web is now a genuinely useful **compile-time** smoke test (real,
in CI, catching real compile errors before they'd otherwise surface).
It is not, and isn't claimed to be, a substitute for running this
mobile-first app on an actual Android/iOS device or emulator -- that
remains externally blocked, same as physical ESP32 hardware.
