# Boretube 2 (phone app): Flutter

Read `../AGENTS.md` and `README.md` first. Device facts are in `../docs/knowledge/`.

## Project
- **Label / app id**: "Boretube 2" / `com.rakesh.boretube`. The legacy v1 is `com.rakesh.boretube_mobile`, signed with a different key, and installs side by side.
- **Kotlin namespace**: `com.rakesh.boretube_mobile` (`MainActivity` holds the multicast lock and the low-latency WifiLock).
- **Flutter** 3.41+ (Dart 3.11). Riverpod + GoRouter. minSdk 24. Android is the target platform.
- **Gradle needs JDK 17.** Point `JAVA_HOME` or `flutter config --jdk-dir` at a JDK 17. Flutter may otherwise pick a newer bundled JDK that Gradle can't run.

## Layout (`lib/`)
- `adb/`: pure-Dart ADB client, key identity, `AdbSession` (queue with an urgent lane)
- `discovery/`: mDNS, SSDP and subnet sweep, plus merge and relocation by stable id
- `tv/`: `Tv` model, `TvStore`, `CapabilityProber`
- `ops/`: `TvOps` (typed TV ops with guards, verify reads and journal), device profiles, health, baseline, restore planner
- `actions/`: instant actions (agent → ADB → Cast fallback)
- `agent/`: TV Guard client and installer
- `protocols/`, `services/`: legacy Cast/DIAL/Sony REST and the classic lock (kept)
- `providers/`, `security/`, `ui/` (design system), `screens/`

## Code style
- `flutter analyze` must report **zero** issues. Run `dart format`.
- Use `const`, `final`, trailing commas and `super.key`. Keep lines to 80 columns.
- UI must use the `lib/ui` components and tokens. Keep it polished, not skeletal.
- Never send a raw shell command from the UI. Every TV write goes through `TvOps`, `ActionsService` or `AgentClient`.

## Tests
- `flutter test` covers unit, widget and golden tests. Update goldens with `flutter test --update-goldens test/goldens`.
- Opt-in live tests: `BORETUBE_TV`, `BORETUBE_ADBKEY`, `BORETUBE_LIVE`. They are read-only.
- Debug builds log `BTIME` timing lines: `adb logcat -s flutter | grep BTIME`.
