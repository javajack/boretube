# Boretube 2 (phone app)

Boretube 2 is an Android app that works as a remote control and rule editor for the family TV. A parent can mute the TV, stop the current app, cap the volume or start a break with one tap. The app was built and tested on a Sony Bravia VU3 (Google TV). On TVs that run **TV Guard** (the on-TV agent in [`../boretube-agent`](../boretube-agent/README.md)), the rules keep working while the phone is away or switched off.

Model: **the TV is the brain, the phone is a remote.** TV Guard is the only rule enforcer. The phone sends instant actions, edits the rules and shows health. Design and plans:
[`docs/superpowers/specs/2026-10-28-boretube-v2-design.md`](../docs/superpowers/specs/2026-10-28-boretube-v2-design.md),
[`docs/superpowers/plans/`](../docs/superpowers/plans/).

## Tiers

The app probes each TV when it connects (`lib/tv/capabilities.dart`) and shows only the controls that TV supports. A missing capability shows an "Unlock with ADB" or "Install TV Guard" tip instead of a button that would fail.

| Tier | Needs | You get |
|---|---|---|
| **Cast-only** | Cast `:8008`/`:8009` (+ Sony REST on `:80` if available) | Instant actions (mute, stop, volume, bore), classic timed lock + whitelist |
| **+ ADB** | Network ADB on `:5555`, "Always allow" for this phone's key | Strong stop (`am force-stop`), the TV tab (Health with Fix, Apps, stock YouTube toggle, Restore TV), journal |
| **+ TV Guard** (optional) | The agent installed by the phone over ADB | Rules tab, enforcement 24/7 on the TV, breaks and timed mutes enforced by the TV, self-healing watchdog |

TV Guard is optional. Without it, everything except the Rules tab still works over Cast and ADB.

## Features

The app is locked behind a parent PIN, with optional fingerprint unlock. It locks on cold start and again after 5 minutes in the background. The top bar has a TV switcher (saved TVs, "Add TV") and a status pill (TV Guard on, limited, paused, safe mode, down, break, classic lock, not guarded).

### Now

- **Now-on-TV card:** the foreground app (with a friendly name), a volume meter, mute state, and "last seen" when the TV is off.
- **Quick actions** (`lib/actions/actions_service.dart`). Each one tries the best transport first: TV Guard (when healthy), then Sony REST, then ADB, then Cast.
  - **Mute / Unmute**
  - **Stop:** stops the foreground app. ADB force-stops it; protected apps only get Home. Cast/DIAL is the fallback.
  - **Bore:** stop + mute.
  - **Volume:** a slider. Sony REST sets the volume directly. Over ADB it steps with key events, because the VU3 ignores an absolute set.
  - **Break:** 15, 30 or 60 min, or "Silence only" (mute for N min). With TV Guard the TV enforces it ("Enforced by TV"). Without it, the phone keeps the break going.
  - **Restore:** ends breaks and timed mutes, and unmutes.
- **Classic lock** (TVs without TV Guard). This is the v1 timed lock: mode (apps / volume), check interval 5–300 s, max volume 1–100 %, duration 1–1440 min, start/stop, countdown and a live feed. It runs in a foreground service with an ongoing notification that has a Stop button. The lock unmutes when it ends. The **whitelist** screen is here too, with "what's playing → add".

### Rules (TV Guard TVs only)

Without TV Guard, the Rules tab shows an explainer and an Install button. With TV Guard, it edits the rules document stored on the TV (`lib/screens/rules/rules_editor.dart`). Edits are kept as a draft, and Save sends the draft with its `version`. If another phone saved first, the TV answers 409 ("the TV has newer rules") and the app handles it.

- **Allowed apps:** off / allowlist / blocklist. Apps are picked from the TV's app list.
- **Volume limit:** a max %.
- **Always mute**
- **TV time:** a schedule of blocked windows per weekday (may cross midnight) and a daily limit in minutes. It counts only while the screen is on and not on an HDMI or tuner input.
- **Style:** *sneaky* (force-stop + Home, mute/clamp silently) or *explicit* (a full-screen "TV time is over · back at 07:00" card, then Home).
- **Temporary overrides:** e.g. "Allow YouTube tonight", "Muted for 30 min".
- Each save records `updatedBy` and `updatedAt`. If two phones edit, the last write wins.

### TV (needs ADB)

- **Health** (`lib/ops/health.dart`): ADB connection, bloat cleanup N/N, stock YouTube removed, Speech services at the known-good version, Home launcher + accessibility helper, plus TV Guard's own checks. **Fix** works per row, and **Fix all (N)** fixes everything. The TV Guard card at the top offers install/repair, shows version, mode and self-ADB, and has Pause / Safe mode / Uninstall and Approve-build.
- **Apps:** the TV's apps marked Allowed / Blocked / Removed. The **stock YouTube card** has a toggle: remove = `pm uninstall -k --user 0`, restore = `cmd package install-existing`, and YouTube Music follows. It also has "allow tonight".
- **Activity:** the phone journal and the TV Guard journal merged, newest first. What TV Guard did since the app was last opened is grouped under **"While you were away"**.
- **Settings:**
  - saved TVs: set active, rename or edit the address, forget
  - refresh interval
  - Change PIN, fingerprint unlock, Lock now
  - **ADB key**: this phone's fingerprint, and Reset key
  - "Allow maintenance" for untested TV models
  - **Restore TV** (`lib/screens/restore_screen.dart`). *Undo Boretube* reverts journaled changes and removes TV Guard. *Back to stock* re-enables the profile's cleanup list, restores stock YouTube/Music and removes TV Guard. Each target lists its exact steps first and runs over ADB, so it doesn't need the agent. The **baseline snapshot** (how the TV looked the first time this phone connected over ADB) can be viewed and copied as JSON.
  - About

Every TV write goes through `TvOps`. Each write is checked against a built-in **never-touch** list (system, Play Services/Store, setup and Wi-Fi, launcher, input/tuner packages, the agent), gets a verify read afterwards, and is journaled per TV with an undo command.

## Discovery and identity

`lib/discovery/discovery_service.dart` runs three methods at the same time and merges their results:

1. **mDNS**: `_googlecast._tcp`, `_adb._tcp`, `_adb-tls-connect._tcp`, `_boretube._tcp`. It holds an Android MulticastLock while it runs.
2. **SSDP**: M-SEARCH for `urn:dial-multiscreen-org:service:dial:1`.
3. **Subnet sweep** (fallback): TCP 8008 **and** 8009 on the phone's /24 plus the common gateway subnets, 50 probes at a time, 600 ms timeout each.

Each hit is identified with `GET :8008/ssdp/device-desc.xml` (name, maker, model, UDN). Saved TVs are keyed by a **stable id**, using the first one available:

1. the agent id
2. the ADB serial
3. the Cast/UDN uuid
4. `ip:ADDR` (temporary)

**Relocation:** when the active TV stops answering (e.g. a new DHCP lease), `Relocator` re-discovers it, matches it by id, updates the IP and shows "Living Room TV moved to .7". It tries at most once every 2 minutes. You can also add a TV by IP by hand.

## Architecture (`lib/`)

```
lib/
├── main.dart, app.dart        entry point; routing (lock → onboarding → shell) as a pure function
├── version.dart               app version shown in Settings › About (keep in step with pubspec)
├── adb/
│   ├── adb_client.dart        pure-Dart ADB over TCP :5555 (CNXN, AUTH, OPEN/WRTE/OKAY/CLSE, shell)
│   ├── adb_session.dart       connection manager: reconnect, keep-alive, auth-pending state,
│   │                          urgent lane (taps) ahead of background lane (polls)
│   ├── adb_connection.dart    AdbShell interface (faked in tests)
│   ├── adb_key.dart           RSA-2048 key in adbd's format, PKCS#1 signing of the AUTH token
│   ├── adb_identity.dart      generates and stores the key in secure storage
│   └── adb_message.dart       wire format
├── discovery/
│   ├── discovery_service.dart runs mDNS + SSDP + sweep together, identifies, relocate()
│   ├── mdns_discovery.dart    Cast / ADB / TV Guard services
│   ├── ssdp_discovery.dart    DIAL M-SEARCH
│   ├── subnet_sweep.dart      8008+8009 TCP sweep
│   ├── discovery_merger.dart  de-duplicates hits by IP, then by agent id / ADB serial / UDN
│   ├── device_identifier.dart device-desc.xml parser
│   └── net.dart               HTTP/TCP primitives (injectable)
├── tv/
│   ├── tv.dart                Tv model + stable id + capability set
│   ├── tv_store.dart          saved TVs + active id (SharedPreferences, migrates v1 tv_config)
│   └── capabilities.dart      probes cast / dial / sonyRest / adb / agent
├── ops/
│   ├── tv_ops.dart            the only ADB API the UI uses: typed ops, never-touch guard,
│   │                          verify reads, volume/mute key paths, parsers
│   ├── device_profile.dart    JSON profiles in assets/profiles/ (sony-bravia-vu3, generic)
│   ├── health.dart            Health checks with check/fix pairs
│   ├── journal.dart           per-TV journal (before/after/undo) in prefs
│   ├── baseline.dart          first-connect snapshot of the TV
│   └── restore_planner.dart   Undo Boretube / Back to stock step lists
├── actions/
│   └── actions_service.dart   instant actions, best transport first (agent > Sony REST > ADB > Cast)
├── agent/
│   ├── agent_client.dart      HTTP client for TV Guard :8790 (timeouts, 401/409 handling)
│   ├── agent_models.dart      lenient typed models for the API (contract v1)
│   └── agent_installer.dart   install/repair stepper: verify hash, push, pm install, grants,
│                              start, read token, self-ADB approval, push profile, check
├── providers/                 Riverpod wiring
│   ├── tv_providers.dart      active TV, ADB session, TvOps, journal, probe, discovery
│   ├── now_playing.dart       polled now-on-TV state, Relocator
│   ├── break_provider.dart    breaks (persisted end time; agent-enforced when available)
│   ├── agent_providers.dart   token, client, status, rules
│   ├── providers.dart         prefs, legacy TvService, whitelist
│   ├── security_providers.dart, settings_provider.dart
├── security/
│   ├── app_lock.dart          PIN/biometric gate, re-locks after 5 min in background
│   ├── pin_store.dart         salted SHA-256 PIN hash in secure storage
│   └── biometric.dart         local_auth wrapper
├── services/                  v1 code kept for the classic lock
│   ├── lock_service.dart      foreground-service lock loop (flutter_foreground_task)
│   ├── lock_decision.dart     pure lock rule evaluation
│   └── tv_service.dart        CastV2 + DIAL + Sony REST façade
├── protocols/, proto/         CastV2 (TLS :8009, protobuf) and DIAL/Sony REST clients
├── platform/multicast_lock.dart  MethodChannel to MainActivity's MulticastLock
├── models/                    v1 models (TvConfig, TvStatus, LogEntry, WhitelistEntry)
├── ui/                        tokens, theme (dark default), shared components, formatters
└── screens/
    ├── shell_screen.dart      top bar (TV switcher + status pill) + Now / Rules / TV tabs
    ├── onboarding_screen.dart Find → Connect → Unlock ADB → PIN → done
    ├── adb_guide_screen.dart  enable developer mode/debugging; "Look at the TV → Always allow"
    ├── lock_screen.dart, pin_entry.dart
    ├── now/                   now_tab, quick_actions, classic_lock_card
    ├── rules_tab.dart, rules/rules_editor.dart
    ├── tv/                    tv_tab, health_section, tv_guard_card, apps_section,
    │                          activity_section, settings_section, common
    ├── restore_screen.dart    Restore TV + baseline snapshot
    ├── whitelist_screen.dart, tv_address_dialog.dart
```

Native side: `android/app/src/main/kotlin/com/rakesh/boretube_mobile/MainActivity.kt` holds the multicast lock (channel `boretube/multicast`) and the low-latency WifiLock.

Bundled assets:
- `assets/profiles/*.json`: device profiles.
- `assets/agent/boretube-agent.apk` + `manifest.json`: the TV Guard bundle. See [Bundling TV Guard](#bundling-tv-guard).

## Performance notes (P1 learnings)

- **Low-latency WifiLock while on screen.** `MainActivity` acquires `WIFI_MODE_FULL_LOW_LATENCY` (`FULL_HIGH_PERF` before Android 10) in `onResume` and releases it in `onPause`. Without it, the radio power-saves between polls, TV replies get lost, and TCP retransmit back-off turns a 0.3 s ADB command into 6–8 s.
- **Fast-path mute.** The VU3 only honours the mute *toggle* key. When the freshly polled state already says the TV is in the other state, `TvOps.setMuted` sends `KEYCODE_VOLUME_MUTE` alone (~0.1 s). It then checks in the background after 250 ms and corrects the TV if it ended up wrong. Otherwise it does read → press-if-needed → verify in one shell round trip, and never toggles blind.
- **Two ADB lanes.** Taps go on an urgent lane that runs ahead of queued poll commands.
- **Spinner only after 1.5 s.** Tiles flip optimistically on tap. A progress ring appears only when an action takes longer than 1.5 s, and a failed action rolls back with a snackbar.
- **Timing logs (debug builds only).** Lines prefixed `BTIME` log action time, transport, ADB connect/sign time and per-command queue wait and run time:

  ```sh
  adb logcat -s flutter | grep BTIME
  ```

## Build and run

### Prerequisites

| Tool | Version / note |
|---|---|
| Flutter | 3.41+ (Dart 3.11). The dev machine uses `/opt/flutter` (see `android/local.properties`, `flutter.sdk`) |
| JDK | **17** for Gradle (AGP 8.13.1, Kotlin 2.2.20, Gradle wrapper 8.14) |
| Android SDK | `sdk.dir` in `android/local.properties` |
| Device | Android 7.0+ (**minSdk 24**, needed by local_auth and flutter_secure_storage) |

**JDK selection.** Flutter may pick up Android Studio's bundled JDK, or a newer `java` on `PATH`, instead of 17. Pin it in one of two ways:

```sh
flutter config --jdk-dir=/path/to/jdk-17      # persistent, for flutter build/run
# or per command, leaving the system default alone:
JAVA_HOME=/path/to/jdk-17 PATH=/path/to/jdk-17/bin:$PATH flutter build apk --debug
```

**Isolated build.** To keep this build away from other projects' Gradle state, give it its own Gradle home too:

```sh
cd boretube-mobile
env JAVA_HOME=/path/to/jdk-17 \
    PATH=/path/to/jdk-17/bin:/opt/flutter/bin:$PATH \
    GRADLE_USER_HOME=$HOME/.gradle-boretube \
    flutter build apk --debug
```

### App identity

- Application id `com.rakesh.boretube`, label **"Boretube 2"**. The Gradle namespace and Kotlin package stay `com.rakesh.boretube_mobile`.
- The legacy v1 app (`com.rakesh.boretube_mobile`) has a different id, so both can be installed side by side.
- Version: `pubspec.yaml` (`2.0.0+2`) and `lib/version.dart`.
- **Signing:** every build (debug and release) is signed with one stable key, `~/.boretube/keys/boretube2-debug.keystore`, or the path in `BORETUBE_KEYSTORE`. That way updates install over the app already on the phone. **Back up this file.** If the key changes, the phone refuses the update unless you uninstall first, which is what happened with v1. If the file is missing, the build falls back to the machine's default debug key.

### Commands

```sh
cd boretube-mobile
flutter pub get
flutter analyze                     # must stay at 0 issues
flutter test                        # unit, widget and golden tests (fakes; no TV needed)
flutter build apk --debug           # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release         # build/app/outputs/flutter-apk/app-release.apk
```

### Goldens

Golden screenshots (360×800 dp) are in `test/goldens/`. After an intended UI change, regenerate them:

```sh
flutter test --update-goldens test/goldens
```

### Opt-in live tests (real TV on the LAN, read-only)

These tests are skipped unless their env vars are set. `BORETUBE_ADBKEY` points to an ADB private key that the TV already trusts, e.g. the laptop's.

```sh
# ADB client: connect + shell
BORETUBE_TV=192.168.1.3:5555 BORETUBE_ADBKEY=~/.android/adbkey \
  flutter test test/adb/adb_live_test.dart

# TvOps reads against the real TV
BORETUBE_TV=192.168.1.3:5555 BORETUBE_ADBKEY=~/.android/adbkey \
  flutter test test/ops/ops_live_test.dart

# Discovery (mDNS/SSDP/sweep) + capability probe; BORETUBE_TV_IP defaults to 192.168.1.3
BORETUBE_LIVE=1 [BORETUBE_TV_IP=192.168.1.3] [BORETUBE_ADBKEY=~/.android/adbkey] \
  flutter test test/discovery/discovery_live_test.dart
```

### Install on a phone

USB (enable Developer options › USB debugging on the phone):

```sh
adb devices
flutter run -d <device-id>                         # debug, with hot reload and logs
# or install a built APK:
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

To launch the installed app from the laptop (the activity class keeps the old Kotlin package):

```sh
adb shell am start -n com.rakesh.boretube/com.rakesh.boretube_mobile.MainActivity
```

The helper scripts in `scripts/` (`debugbuild.sh`, `normalbuild.sh`, `prodbuild.sh`, `run-android.sh`) source `_env.sh`. It:

- finds a **JDK 17** in `$BORETUBE_JDK17`, `$JAVA_HOME`, `~/development/jdk-17*` or `/usr/lib/jvm/*17*`;
- finds Flutter in `~/development/flutter`, `/opt/flutter` or on `PATH`;
- pins the JDK in a private Flutter config under `.dart_tool/` (Flutter otherwise prefers Android Studio's bundled JDK).

They launch `com.rakesh.boretube`.

Wireless debugging (Android 11+; Developer options › Wireless debugging › Pair device with pairing code):

```sh
adb pair <phone-ip>:<pair-port>      # enter the 6-digit code
adb connect <phone-ip>:<port>
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## First run

1. **Find TV.** TVs on the same Wi-Fi appear as discovery runs. Use manual entry if yours doesn't.
2. **Connect.** The app checks capabilities (Cast, DIAL, Sony REST, ADB, TV Guard).
3. **Unlock with ADB** (optional, recommended). On the TV:
   - Settings › System › About: select "Android TV OS build" 7 times.
   - Settings › System › Developer options: turn on USB debugging.
   - Tap Connect in the app, look at the TV, and choose **"Always allow"** for this phone.
4. **Set a parent PIN.**
5. **Install TV Guard** (optional), from the Rules tab or TV › Health. The stepper:
   - checks the bundled APK's hash
   - copies and installs it
   - grants permissions
   - starts the service
   - reads the token
   - asks for one more **"Always allow"** on the TV (TV Guard's own self-ADB key)
   - sends the device profile
   - runs a final status check

## Bundling TV Guard

The phone installs the APK from `assets/agent/`. After building a new agent (see [`../boretube-agent/README.md`](../boretube-agent/README.md)):

1. Copy `boretube-agent/app/build/outputs/apk/release/app-release.apk` to `assets/agent/boretube-agent.apk`.
2. Update `assets/agent/manifest.json`: `sha256` (the `sha256sum` of the APK), `versionCode` and `versionName` (from `boretube-agent/app/build.gradle`). If the keystore changed, also update `certSha256` / `signingCertSha256`.
3. Rebuild the phone app.

The installer refuses an APK whose SHA-256 doesn't match the manifest, and checks the hash again on the TV after the copy. It offers an update when the installed `versionCode` is older than the bundled one.

## Troubleshooting

| Symptom | What to do |
|---|---|
| **TV not found** | Phone and TV must be on the same Wi-Fi (guest networks often block multicast). Wait for the sweep to finish, or add the TV by IP (Find step → manual entry, or TV › Settings → edit address). |
| **ADB says "needs approval"** | Look at the TV: an "Allow USB debugging?" prompt is waiting. Tick **Always allow**. If you reset the phone's ADB key (TV › Settings › ADB key) or the TV lost its authorizations, approve again. |
| **Actions are slow** (several seconds) | Check the Wi-Fi: a weak signal or a power-saving access point causes retransmits. Keep the app in the foreground (that holds the low-latency WifiLock). In debug builds, `adb logcat -s flutter \| grep BTIME` shows where the time goes. |
| **"TV Guard down"** (red pill) | Open TV › Health › TV Guard card → **Repair**. Over ADB it re-enables, reinstalls or restarts the agent, or re-reads the token. If the pill says "limited", approve TV Guard's self-ADB prompt on the TV. |
