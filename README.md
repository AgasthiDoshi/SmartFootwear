# STRIDE AI

A Flutter movement companion with a deterministic local sensor studio, saved walking recordings, explainable summaries, and simulated safety tools. No wearable, account, Firebase project, or paid AI key is required for the local app; optional cross-device admin controls require Firebase.

## Setup and run

Validated toolchain: Flutter 3.41.6 / Dart 3.11.4 on Windows. Install Flutter, add its `bin` directory to PATH, and run `flutter doctor`. Android builds require a compatible JDK and Android SDK with accepted licenses. Gradle may download dependencies on the first build. The project uses AGP 8.12.1, Gradle 8.14, and Kotlin 2.4.0.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

For an Android emulator, start it from Android Studio before running the app. No environment variables are needed for a local run.

### Optional shared admin readings

Tap the bottom-right Profile tab four times within ten seconds to open admin sign-in. The shortcut does not grant access. Enable Firebase Authentication email/password sign-in, create the admin account, and deploy [firestore.rules](./firestore.rules). Set the `admin: true` custom claim for that account using a trusted server-side Firebase Admin SDK; never set admin privileges from the client. Firestore rules allow clients to read the public demo override document, but only authenticated users with that server-set claim can write it.

Provide the Firebase app configuration when building/running each phone app. Values below are public Firebase client configuration, not admin credentials:

```powershell
flutter run --dart-define="FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY" --dart-define="FIREBASE_APP_ID=YOUR_PLATFORM_APP_ID" --dart-define="FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID" --dart-define="FIREBASE_PROJECT_ID=YOUR_PROJECT_ID" --dart-define="FIREBASE_AUTH_DOMAIN=YOUR_PROJECT_ID.firebaseapp.com"
```

The same Firebase project makes the step summary and nine simulated live sensor channels update across connected phones. Changes are labeled **ADMIN-ADJUSTED DEMO**; this app currently has no real hardware sensor source, and saved session history remains local to each phone. Without Firebase configuration, the local demo app still runs and the admin screen reports that shared controls are unavailable.

```sh
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Android output: `build/app/outputs/flutter-apk/app-debug.apk`. Debug APKs are for development, not store distribution. iOS signing and release builds have not been validated here.

## Navigation and demo walkthrough

Complete or skip onboarding. The five tabs are Home, Live, AI Coach, Safety, and Profile. Secondary routes cover Gait Intelligence, History, session details, Walk Replay, goals, quests, Device Hub, contacts, privacy, notifications, and app settings. Unknown routes offer Home recovery; missing recordings have an unavailable state.

Home is a fixed **bundled sample** for 21 October 2026. Its sample walks and weekly chart are excluded from saved history, goals, achievements, quests, and Coach answers. Distance is unavailable because no distance measurement exists.

In Live, explicitly start the simulated feed or a recording. Choose walking or stationary input. Calibration collects 40 stationary samples, zeroes FSR offsets, and retains gravity on acceleration Z. Start, pause, resume, then stop to save a recording. Disconnecting or leaving the foreground pauses recording; resume requires an explicit action. Failed saves retain the pending recording in memory and offer retry. Keep the app open until saved.

History operates on saved recordings only. Select daily, weekly, or monthly trends, filter a bucket, open details or replay, and export CSV. Empty history offers recording guidance, with no fabricated chart. Join a quest before recording to earn progress. Goals are user-selected practice targets, not health recommendations.

Coach uses a deterministic local rules provider. Suggested questions cover daily/weekly totals, historical comparisons, baseline, observations, and goals. It explains calculations, links evidence, and communicates insufficient data. It does not diagnose conditions or infer unavailable measurements. Chat is memory-only and can be cleared; saved-data changes mark previous answers stale.

Safety fall events are manually triggered simulations. Countdown cancellation is available on the Safety screen and globally across routes. Backgrounding cancels an active practice. No contacts produces a blocked preview. Add up to five local contacts, choose inclusion, and exercise immediate test alerts. **No emergency messages, calls, OS notifications, BLE writes, or physical haptics are sent.** Test mode and permission pickers cannot enable real delivery. Device Hub connection and haptic commands are previews only. Actual OS permission status is not queried.

## Architecture

- `lib/core`: theme and app-level orchestration.
- `lib/app.dart`: GoRouter routes, five-tab shell, lifecycle handling, global safety activity banner, and reduced-motion setting.
- `lib/domain`: immutable models, repository interfaces/local adapters, deterministic sensor source, processing, trend/goal/quest calculations, replay capture, CSV encoding, and Coach/safety boundaries.
- `lib/services`: ChangeNotifier controllers for recording, replay, progress, Coach, preferences, safety, and device previews. Controllers accept repositories/providers and clocks for deterministic tests.
- `lib/features`: screen files organized by feature; shared surfaces, state panels, preference controls, and CSV dialog live in `lib/widgets`.
- `test`: processing, persistence, controller state transitions, navigation, failure handling, and widget coverage, including a compact-screen route matrix in both themes.

Async writes publish new saved values after successful persistence. Read failures block operations that could overwrite unread data. Dashboard requests ignore stale and disposed results. Charts are bounded and live traces have repaint isolation; reduced motion respects both the platform and local preference.

## Data and calculations

The simulator generates nine channels at 20 logical samples per second: three FSR ADC channels (heel, forefoot, toe), three acceleration channels (g), and three gyroscope channels (degrees/second). The live chart retains 120 frames. This is synthetic single-insole data, not clinically validated gait measurement.

- A contact is counted when summed FSR exceeds 700 ADC after dropping below 150, with a 300 ms refractory interval. It is displayed as a simulated step; it is not bilateral footstep detection.
- Live cadence is 60,000 divided by the mean of up to eight recent contact intervals in milliseconds; it becomes unavailable after a two-second gap. Saved average cadence is total contacts times 60,000 divided by active milliseconds. Aggregates weight by active duration rather than averaging session averages.
- Timing consistency needs at least three intervals and is `100 * (1 - standard deviation / mean)`, clamped to 0-100. It describes recent contact timing, not a medical or overall gait score.
- Pressure shares are accumulated ADC counts per zone divided by the total across zones, times 100. Zero total yields three zeros. They are not force, body weight, or left/right balance.
- Active duration counts logical simulator samples while recording; paused time is excluded. It may differ from wall-clock time if the UI thread stalls.
- Trends group whole sessions by local start date, weeks begin Monday, and monthly buckets use calendar months. They do not split sessions crossing midnight. Coach excludes future-starting sessions; comparisons use completed seven-day windows. Its personal baseline needs at least three prior moving recordings on two dates within 28 calendar days, using at most ten recordings.
- Replay retains at most 180 adaptive checkpoints. Seeking shows the earlier stored checkpoint, without invented interpolation or GPS. Short pressure peaks may be omitted.

CSV contains saved session summaries with UTC timestamps, active seconds, simulated contacts, cadence, ADC shares, calibration status, and checkpoint count. Missing values are blank. Textual cells neutralize spreadsheet formula prefixes. Copy uses the OS clipboard; sharing opens the platform share sheet and reports its actual reported status, not guaranteed destination delivery.

## Persistence and privacy

SharedPreferences stores onboarding/theme, up to 100 recent saved recordings, goals/quest enrollment, profile, contacts, and settings in separate versioned keys. Replay capture preferences apply to new recordings. Old recordings may lack replay. Delete recordings from session details; clear contacts/chat through Privacy. Reset settings preserves contacts and profile. Deletion and retention can reduce achievement/quest progress because these are calculated from retained recordings.

Local storage is **not encrypted** and is not a backup system. Uninstalling or clearing app data removes it. Contacts are entered manually; masking only changes presentation. No address book, location, SMS, or phone permission is needed. Invalid history is preserved and surfaced as a read error; there is no automatic destructive repair. Export before removing app data. Pending unsaved recordings are lost if the process is killed.

## Future integration boundaries

BLE should implement `SensorSource` with a documented packet schema, timestamp handling, disconnection/gap processing, channel validation, platform permissions, and real-device calibration tests. The current logical clock must be adapted before accepting real asynchronous packets. Device connection and `HapticPreviewPort` are preview contracts; build a separate explicitly authorized hardware transport rather than silently turning previews into commands.

Firebase is not configured. Future authenticated sync should add a repository adapter, explicit opt-in, per-user access rules, schema migrations, conflict handling, deletion/export policies, and encrypted handling of sensitive fields. Keep local operation available and verify rules with emulator tests before deployment.

`CoachProvider` allows a future secure server-backed AI adapter. Require consent, authentication, timeouts, minimal data transfer, and factual grounding; never embed paid provider credentials in the client. Emergency preview requests expose a recipient count, not contact addresses. Real emergency delivery requires a separate reviewed integration with consent, platform permissions, delivery/failure semantics, and independent safety validation. No setting in this build can activate it.

## Verification and limitations

See the quality-pass report in the accompanying task response for actual command outcomes. The automated route sweep covers 360x640 at 1.5x text in light/dark themes and onboarding at 320x480 at 2x text. Tests also exercise interactions, persistence failures, empty data, replay, Coach grounding, and safety cancellation. This does not replace physical-device, TalkBack/VoiceOver, OS share-destination, or performance profiling checks.

Known limits: fixed sample Home rather than personalized Home; local unencrypted storage and no sync; logical simulator time; simplified contact detection; sparse replay; finite local Coach topics; no hardware, clinical validation, automatic fall detection, real delivery, or real OS permission/notification integration. Debug build success does not establish release readiness.

Quality pass verified on 21 October 2026: formatting checked 71 Dart files with zero changes; `flutter analyze` reported no issues; `flutter test` passed all 115 tests; `flutter build apk --debug` succeeded. Test output is retained in `qa-test.log`. These are automated host results; the physical-device and assistive-technology checks above remain outstanding.
