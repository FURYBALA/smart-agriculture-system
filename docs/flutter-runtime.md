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

**Update -- now actually observed.** The two attempts below (both from
an earlier pass) still stand as real, documented dead ends for the
tools they used, but they are no longer the last word: a working
isolated headless browser was found afterward (see "Real browser
observation" below), and it answered every question this section used
to leave open.

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

## Real browser observation (Playwright + Chromium)

What actually unblocked this: `npx playwright install chromium`
downloads its own isolated Chromium build (not the environment's Edge
profile), so it doesn't hit attempt #2's problem. Set up a small
scratch Node project, `npm install playwright`, served `build/web` with
`python -m http.server`, and drove real headless Chromium against it --
navigating by clicking the actual `NavigationBar` destinations at their
real screen coordinates (not simulated events), capturing a full-page
screenshot after each, plus every `console` and `pageerror` event the
page produced.

**All six screens render correctly**, confirmed by screenshot, not
assumption:

- **Sensors** (Sensor Dashboard): renders, shows a loading spinner
  waiting on an unreachable ESP32 -- correct behavior with no device
  present.
- **Irrigation**: renders "Could not reach the irrigation node." --
  the same readable-error path M6 already unit-tested, now observed
  in an actual rendered frame.
- **Diagnose**: renders the image picker UI ("No image selected",
  Camera/Gallery buttons, both diagnosis-path buttons) cleanly.
- **History**: see below -- this is the one screen that needed a real
  fix, not just observation.
- **Chat**: renders the initial assistant greeting and input bar
  correctly.
- **Device**: renders both device rows and the "Test All" button
  correctly.

No uncaught JS exceptions (`pageerror`) were produced by navigating
the app through all six screens both before and after the History fix
below; the only console output throughout was routine (service worker
install, a WebGL performance advisory from software rendering in a
headless/no-GPU environment -- not an app bug).

### HistoryScreen: real bug, real fix, real re-verification

Before any fix, History rendered a real, unhandled-looking error (not
a crash, but not usable either):
```
Could not load history: Bad state: databaseFactory not initialized
databaseFactory is only initialized when using sqflite_common_ffi.
...
```
This confirms the *fact* of the earlier prediction (fails gracefully
via the existing `FutureBuilder`/`_ErrorList` pattern, not an app-wide
crash) while showing the prediction undersold it: History was
completely unusable on web, not just imperfect.

**Fixed properly**, not worked around: added `sqflite_common_ffi_web`
as a real dependency, and in `main.dart`, guarded by `kIsWeb`:
```dart
if (kIsWeb) {
  databaseFactory = databaseFactoryFfiWeb;
}
```
`HistoryDatabase` itself (`history_database.dart`) needed **zero
changes** -- its `openDatabase()`/`getDatabasesPath()` calls are the
plain top-level `sqflite` functions, which already delegate to
whichever `databaseFactory` is registered. Mobile is unaffected: the
`kIsWeb` branch never executes there, so it keeps using the default
platform-channel factory exactly as before.

This alone wasn't sufficient -- the web factory also needs a service
worker and a `sqlite3.wasm` binary present as static assets, generated
once via:
```bash
dart run sqflite_common_ffi_web:setup
```
which produced `mobile_app/web/sqflite_sw.js` and
`mobile_app/web/sqlite3.wasm`. These are committed as real project
assets (like `web/index.html`), not build output -- `flutter build web`
copies them into `build/web/` but does not regenerate them; re-run the
setup command above if `sqflite_common_ffi_web` is ever upgraded.

**Re-verified after the fix**, same method as before (`flutter
analyze`, `flutter test` -- both still clean, 19/19 tests passing,
unaffected since none of this touches mobile code paths -- then
`flutter build web`, then the same real headless-Chromium pass):
History now renders **"No diagnoses yet."** -- a clean, successful
empty query against a real IndexedDB/wasm-backed SQLite database in
the browser, not an error. `Sensor Log`'s tab behaves the same way.

What this proves: the on-disk history database genuinely opens,
creates its schema, and queries successfully on web now. What it
doesn't prove: that a diagnosis actually gets *saved* through the full
web UI flow -- `diagnosis_screen.dart` reads the picked image via
`dart:io File(...).readAsBytes()` before saving, and plain `dart:io`
has no real file-reading implementation on web either (a second,
separate `dart:io`-on-web gap, in the image path rather than the
database path). That wasn't observed to fail -- doing so would require
driving Playwright through a real file-picker interaction, not
attempted here -- so it's named as a known, unaddressed limitation
rather than either fixed or claimed working. Fixing it would mean
switching `image_picker`'s web bytes API and `Image.memory` in place of
`Image.file`/`dart:io File` in both `diagnosis_screen.dart` and
`history_screen.dart`'s thumbnail rendering -- a second real
architecture change, deliberately left out of this pass's scope (this
one was specifically about the database layer, which is what was
observed broken).

## Android release APK: real build fix, real success

`flutter build apk --release` initially failed -- not on this project's
code, but on the Android build toolchain itself. Diagnosed and fixed in
two steps, each confirmed with the actual next build attempt rather
than guessed:

1. **Gradle/JDK mismatch.** The project's default Gradle 7.6.3 doesn't
   support JDK 21 (Android Studio's currently-bundled JDK, which is
   what Flutter's Gradle invocation uses by default here). Bumped to
   Gradle 8.4 + AGP 8.1.0 + Kotlin 1.9.24 -- the standard, documented
   combination for JDK 21.
2. **Kotlin/Java JVM-target mismatch.** With that fixed, a second, more
   specific error appeared: `compileReleaseJavaWithJavac` (target 1.8,
   from `app/build.gradle`'s existing `compileOptions`) and
   `compileReleaseKotlin` (inferring target 21 from the JDK, since
   nothing pinned it) disagreed. Fixed by adding an explicit
   `kotlinOptions { jvmTarget = "1.8" }` to match the Java side.

After both fixes:
```
√ Built build\app\outputs\flutter-apk\app-release.apk (20.7MB)
```
A real, verified file on disk -- confirmed with `ls`, not just a
"BUILD SUCCESSFUL" message. **What this doesn't prove**: the APK has
never been installed on a device or emulator, so nothing about its
actual runtime behavior is known -- only that it exists and is a valid
build output.

## Bottom line

Flutter web is now verified at **both** levels: `flutter build web`
(compile-time) and a real headless-Chromium run that actually opened
the app and clicked through all six screens (runtime) -- including a
real bug (HistoryScreen's database on web) found and fixed along the
way, not just observed and left broken. Android
(`flutter build apk --release`) remains build-time only -- a real,
verified 20.7MB APK exists, after a real non-trivial toolchain fix, but
it has never been installed or launched on a device or emulator, so
nothing about its actual runtime behavior is known. That -- and
physical ESP32 hardware -- are what remain externally blocked, not
"any Flutter runtime, unqualified."
