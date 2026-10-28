# TV Guard (boretube-agent)

TV Guard is a small Android TV app (package `com.rakesh.boretube.agent`). It runs on the family TV and enforces the parent's rules 24/7: allowed apps, volume limit, always-mute, TV-time schedule and daily limit, breaks and timed mutes. It works offline, on the TV's own clock, with no phone needed. It also heals the TV after updates: it removes stock YouTube again, rolls back a bad Speech Services update, re-applies the bloat cleanup, and checks the Home launcher.

The phone app ([`../boretube-mobile`](../boretube-mobile/README.md)) installs TV Guard over ADB, then drives it through a LAN HTTP API. TV Guard has no launcher tile and no activity. Design:
[`docs/superpowers/specs/2026-10-28-boretube-v2-design.md`](../docs/superpowers/specs/2026-10-28-boretube-v2-design.md) §6,
[`docs/superpowers/plans/2026-10-28-boretube-v2-p2.md`](../docs/superpowers/plans/2026-10-28-boretube-v2-p2.md).

minSdk 26, targetSdk/compileSdk 34. Current version: `1.0.1` (versionCode 2).

## What runs

- **`GuardService`**: a foreground service ("TV Guard is on", low importance, `specialUse` / `parental-control`).
  - It is `exported="true"` but protected by `android.permission.DUMP`, so only the ADB shell or the system can start it.
  - It returns `START_STICKY` and owns a single `GuardController`.
- **`BootReceiver`**: `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED` (only once the user is unlocked) and `MY_PACKAGE_REPLACED` start the service. Boots are de-duplicated by `/proc/sys/kernel/random/boot_id`.
- **`PackageReceiver`**: `PACKAGE_ADDED/REPLACED/CHANGED` trigger the watchdog. Since Android 8 these implicit broadcasts don't reach manifest receivers, so the running service also registers for them at runtime.
- **Enforcement loop**, every **1 s** on the `guard` thread:
  - reads the foreground app and the volume
  - counts TV time
  - runs `RuleEngine.decide(...)`
  - applies the decisions: close app (force-stop + HOME, or HOME only for stop-protected apps), mute, unmute, clamp volume

  Volume changes (`VOLUME_CHANGED_ACTION`, `STREAM_MUTE_CHANGED_ACTION`, a `Settings.System` ContentObserver) trigger an immediate sound-only tick, so a kid's unmute is reverted right away.
- **Housekeeping**, every 5 s on the `slow` thread: self-ADB connect, permission self-heal, watchdog scheduling.
- **Self-ADB.** [dadb](https://github.com/mobile-dev-inc/dadb) connects to `localhost:5555` with the agent's own RSA key (`files/adbkey`). On first connect the TV shows "Allow USB debugging?" for that key, and the phone guides the parent to tick **Always allow**.
  - It uses two connections (lanes), so urgent commands (stop, HOME, keys) never queue behind slow watchdog `pm` writes.
  - Without self-ADB the agent runs in **limited** mode: it still detects apps, mutes/clamps via AudioManager and sends HOME by intent, but it can't force-stop or run maintenance.
- **Permission self-heal.** The Sony VU3 resets the `GET_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` app-ops to default at every reboot. On every service start, then every 10 min, and whenever a grant is missing (at most every 30 s), the agent re-runs these commands over self-ADB and verifies them:

  ```
  appops set com.rakesh.boretube.agent GET_USAGE_STATS allow
  appops set com.rakesh.boretube.agent SYSTEM_ALERT_WINDOW allow
  pm grant com.rakesh.boretube.agent android.permission.POST_NOTIFICATIONS
  ```

  If self-ADB is also down, `/v1/status` reports `needsPhoneGrant: true` and the phone re-grants over its own ADB.
- **Foreground app.** Read from `UsageStatsManager.queryEvents` (ACTIVITY_RESUMED). Falls back to `dumpsys activity activities` over self-ADB when usage access is missing. There is **no accessibility service** on purpose: one would break the launcher's Home helper and volume-hold repeat.
- **Sound.** `AudioManager.adjustStreamVolume` comes first. On the VU3, ADJUST_MUTE/UNMUTE are idempotent and LOWER/RAISE step by one. A runtime self-test reads the result back. If the TV ignored it, the agent switches to `input keyevent` over self-ADB for good (`soundPath` in status).
- **Explicit card.** A `TYPE_APPLICATION_OVERLAY` window ("TV time is over · back at 07:00"), not focusable, so it never traps the remote.
- **Watchdog** (maintenance) runs:
  - on boot
  - 3 s after a package event
  - every 6 h
  - after a **60 s quick check**: with `QUERY_ALL_PACKAGES`, the agent checks in-process whether stock YouTube (`com.google.android.youtube.tv`) is installed and enabled while not allowed. This catches `install-existing` and OTA restores that don't send package events.

  The watchdog plans ops from the pushed device profile and runs them with a journal entry each.
- **Announce.** NsdManager advertises `_boretube._tcp` on port 8790 with TXT `id`, `ver`, `api=1`.

## HTTP API (`:8790`, LAN, contract v1)

Every `/v1/*` request needs `Authorization: Bearer <token>`. A missing or wrong token gets **401**, and the check is constant-time.

The agent creates the token on first start and mirrors it to:

```
/sdcard/Android/data/com.rakesh.boretube.agent/files/token      (and files/agent_id)
```

Only ADB/shell can read that path. The phone reads it once over ADB and keeps it in secure storage.

The phone may send `X-Phone-Time` (epoch ms or ISO) with a request. If the TV clock is more than 2 min off, status sets `clockSkewWarn`. Errors come back as `{"error": "...", "status": N}`: 400 for bad JSON or bad fields, 404, 405 for the wrong method, 500.

| Method + path | Request | Response |
|---|---|---|
| `GET /v1/status` | — | Status document; see below |
| `GET /v1/rules` | — | Rules document |
| `PUT /v1/rules` | The full rules document; its `version` must equal the current one | 200 + stored doc (`version+1`, `updatedAt` filled in if empty) · **409** + current doc on version mismatch · 400 if invalid |
| `POST /v1/action` | `{"action": "mute"\|"unmute"\|"stop"\|"bore"\|"restore"\|"endBreak"}`, `{"action":"volume","value":0..100}`, `{"action":"break"\|"muteFor","minutes":1..1440}` | `{ok, detail}`. `break`/`muteFor` are then enforced by the TV until they expire. `restore` ends breaks and timed mutes and unmutes. In safe mode only `unmute`, `restore` and `endBreak` run |
| `GET /v1/journal?since=<epochMs>` | — | `[{time, op, target, before, after, ok, source: agent\|watchdog\|rule, undo?}]`, a ring buffer of 1000 entries |
| `POST /v1/mode` | `{"mode": "normal"\|"paused"\|"safe"}` | `{ok, detail}` |
| `POST /v1/approveBuild` | — | Approves the current `ro.build.fingerprint` for high-risk watchdog writes |
| `POST /v1/profile` | Device profile JSON (same format as `boretube-mobile/assets/profiles/*.json`, plus optional `keepDisabled`, `inputPackages`) | `{ok, detail}`. Validated (package names), stored, and the watchdog runs on the next pass |
| `POST /v1/restore` | `{"target": "undoBoretube"\|"stock", "dryRun"?: bool, "alsoRemoveLauncherHelper"?: bool, "journal"?: [{op, target, ok}]}` | `{ok, plan: {target, steps, notes}, results, mode, detail}`. Afterwards the agent is **paused**. Needs self-ADB |
| `GET /v1/watchdog` | — | Dry-run plan: `{ok, plan: {ops, pending, notes}, results, detail}` |
| `POST /v1/watchdog` | `{"dryRun": bool}` (an empty body runs it for real) | Same shape, with results |

**Status** (`GET /v1/status`) fields:

- identity and uptime: `agentId`, `version`, `api`, `uptimeSec`, `bootCount`
- `selfAdb`: `ok|needsApproval|unavailable`
- `mode` (`normal|paused|safe`) and `modeReason`
- `now`: `{foreground, volume, min, max, muted}`
- `activeRulesVersion`, `activeReasons`
- `break`: `{active, endsAt}`, and `muteForEndsAt`
- `health`: `[{id, status, detail}]`, covering selfAdb, usageAccess, overlay, notifications, profile, build, watchdog, sound, clock, mode
- build gate: `buildFingerprint`, `approvedFingerprint`, `buildChangedSinceApproval`
- clock: `clockSkewWarn`, `clockSkewSec`
- `limited`, `limitedReasons`, `needsPhoneGrant`
- `soundPath`: `audioManager|adbKeys|untested`
- watchdog: `watchdogPending`, `lastWatchdogAt`
- `profileId`

## Rules document

```json
{
  "version": 3,
  "updatedBy": "Parent phone",
  "updatedAt": "2026-10-28T19:30:00+05:30",
  "style": "sneaky",
  "allowedApps": { "mode": "allowlist", "packages": ["org.smarttube.stable"] },
  "volumeLimit": { "maxPercent": 30, "enabled": true },
  "alwaysMute": false,
  "tvTime": {
    "schedule": [{ "days": [1, 2, 3, 4, 5], "from": "21:00", "to": "07:00" }],
    "dailyLimitMin": 120
  },
  "overrides": [
    { "kind": "allowApp", "pkg": "com.google.android.youtube.tv", "until": "2026-10-28T22:00:00+05:30" }
  ],
  "stockYouTubeAllowed": false
}
```

Validation rules:

- `style`: `sneaky|explicit`.
- `allowedApps.mode`: `off|allowlist|blocklist`.
- `maxPercent`: 0..100.
- `days`: ISO weekdays (1 = Mon … 7 = Sun) on which the window *starts*. Windows may cross midnight. `from`/`to` are `HH:mm`.
- `dailyLimitMin`: 0..1440 (0 = no limit). TV time counts only while the screen is on and not on an input package (HDMI passthrough, tuner).
- `overrides[].kind`: `allowApp|muteUntil|breakUntil`. `allowApp` needs a `pkg`. `until` is ISO.
- App rules never close settings, system or setup packages, and they don't apply to inputs. Volume and TV-time rules still apply on inputs.

## Safety

- **Never-touch.** No op writes to `android`, SystemUI, Settings, Play Store, Play Services, the agent, or the profile's `neverTouch` list. A separate never-stop set covers system, both launchers, katniss, setupwraith, Realtek/Sony input and tuner packages, and the agent; those only get HOME. Restore plans skip never-touch packages too.
- **Build-fingerprint gate.** Low-risk watchdog ops (remove stock YouTube, speech rollback) run on any build. High-risk ops (cleanup re-apply, launcher fix) wait in `pending` until the parent approves the current `ro.build.fingerprint` (`/v1/approveBuild`). An OTA therefore never triggers a mass `pm disable` by itself.
- **Boot-loop safe mode.** 3 boots within 15 min put the agent in **safe** mode: no enforcement, no writes, report only. Leaving safe mode by hand clears the boot history.
- **Modes.**
  - **paused**: enforces nothing and makes no watchdog writes.
  - **safe**: same, and instant actions are limited to unmute/restore/endBreak.

  Both are set from the phone (`/v1/mode`).
- **Restore targets** (`core/RestorePlanner.kt`):
  - `undoBoretube` reverts the journaled disables, cleanup and stock-YouTube removals.
  - `stock` re-enables the profile's cleanup and extras lists, runs `install-existing` for stock YouTube and its companions, and optionally removes the launcher helper.

  Each target lists its steps first and journals every step. The agent is left paused, and the phone uninstalls it last over its own ADB. The phone can run the same restores without the agent.
- Uninstalling the agent leaves the TV fully working.

## Code map

```
app/src/main/java/com/rakesh/boretube/agent/
├── GuardService.kt          foreground service; holds the GuardController singleton
├── Receivers.kt             BootReceiver, PackageReceiver
├── core/                    pure Kotlin (no Android imports), JVM unit-tested
│   ├── Api.kt               Router: /v1 routes, auth, request/response models
│   ├── Http.kt              minimal HTTP/1.1 parser/writer, bearer Auth, ClockSkew
│   ├── Rules.kt             rules document, validation, versioned PUT (409)
│   ├── RuleEngine.kt        (rules, break, time, observed) → decisions
│   ├── BreakState.kt        breaks and timed mutes
│   ├── TvTime.kt            daily screen-on TV-time accounting
│   ├── SoundPolicy.kt       AudioManager vs ADB-keys self-test verdict
│   ├── Watchdog.kt          maintenance planner + OpExecutor (journals each op)
│   ├── RestorePlanner.kt    undoBoretube / stock plans
│   ├── SafetyGuard.kt       modes, boot-loop guard, fingerprint gate
│   ├── PermissionHeal.kt    app-op self-heal planner, limited reasons, health items
│   ├── Profile.kt           DeviceProfile, never-touch / never-stop sets, PackageGuard
│   ├── TvShell.kt           shell command builders and output parsers
│   └── Journal.kt           1000-entry ring buffer
└── android/                 adapters
    ├── GuardController.kt   owns state, 1 s loop, housekeeping, implements AgentApi
    ├── Shell.kt             self-ADB via dadb (two lanes, approval state)
    ├── ForegroundWatcher.kt UsageStatsManager polling (+ dumpsys fallback)
    ├── SoundController.kt   STREAM_MUSIC via AudioManager or key events
    ├── Overlay.kt           explicit card
    ├── Net.kt               ServerSocket HTTP server (:8790) + NsdAnnouncer
    └── AgentStore.kt        SharedPreferences + files (token, agent_id, journal)
```

Tests are in `app/src/test/.../core/`: ContractTest, RuleEngineTest, StateTest, TvShellTest and WatchdogTest, with the `sony-bravia-vu3.json` fixture.

## Build

| | |
|---|---|
| JDK | **17** (source/target 17) |
| Gradle | wrapper **8.9** |
| Android Gradle Plugin | 8.5.2 |
| Kotlin | 1.9.24 (+ serialization plugin) |
| Libraries | kotlinx-serialization-json 1.6.3, dadb 1.2.10, JUnit 4.13.2 |
| SDK | `sdk.dir` in `local.properties` (gitignored) |

```sh
cd boretube-agent
export JAVA_HOME=/path/to/jdk-17      # Gradle 8.9 does not run on newer JDKs such as 25
./gradlew test                         # JVM unit tests (core/)
./gradlew assembleRelease              # app/build/outputs/apk/release/app-release.apk
```

### Signing

Release signing reads `keystore/keystore.properties` → `keystore/agent-release.jks`. Both files are **gitignored**. See [`keystore/README.md`](keystore/README.md) to regenerate them, and keep a private backup. Without them, `assembleRelease` produces an unsigned APK.

The signing cert is pinned in `boretube-mobile/assets/agent/manifest.json` (`certSha256` / `signingCertSha256`). After re-keying, update it:

```sh
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk   # SHA-256 digest
```

The TV refuses `pm install -r` over an install signed with a different key, so uninstall the old agent first.

### Bundle into the phone app

```sh
cp app/build/outputs/apk/release/app-release.apk ../boretube-mobile/assets/agent/boretube-agent.apk
sha256sum ../boretube-mobile/assets/agent/boretube-agent.apk
```

Then edit `../boretube-mobile/assets/agent/manifest.json`:

- `sha256`: the hash above
- `versionCode` and `versionName`: from `app/build.gradle`
- `certSha256` / `signingCertSha256`: only if the key changed

Rebuild the phone app. The phone verifies the hash before installing and again after copying to the TV, and offers an update when the TV's `versionCode` is older.

## Manual install and debug (from a laptop)

The phone normally does all of this. From a laptop with ADB access to the TV:

```sh
TV=192.168.1.3
adb connect $TV:5555
adb -s $TV:5555 install -r app/build/outputs/apk/release/app-release.apk

# Grants (the phone runs the same at install)
adb -s $TV:5555 shell appops set com.rakesh.boretube.agent GET_USAGE_STATS allow
adb -s $TV:5555 shell appops set com.rakesh.boretube.agent SYSTEM_ALERT_WINDOW allow
adb -s $TV:5555 shell pm grant com.rakesh.boretube.agent android.permission.WRITE_SECURE_SETTINGS
adb -s $TV:5555 shell pm grant com.rakesh.boretube.agent android.permission.POST_NOTIFICATIONS

# Start (only the shell can: the service is DUMP-protected)
adb -s $TV:5555 shell am start-foreground-service -n com.rakesh.boretube.agent/.GuardService
# Now approve "Allow USB debugging?" (Always allow) on the TV for the agent's self-ADB key.

# Token + API
TOKEN=$(adb -s $TV:5555 shell cat /sdcard/Android/data/com.rakesh.boretube.agent/files/token | tr -d '\r\n')
curl -s -H "Authorization: Bearer $TOKEN" http://$TV:8790/v1/status
curl -s -H "Authorization: Bearer $TOKEN" -X POST http://$TV:8790/v1/profile \
  --data-binary @../boretube-mobile/assets/profiles/sony-bravia-vu3.json
curl -s -H "Authorization: Bearer $TOKEN" http://$TV:8790/v1/watchdog          # dry-run plan
curl -s -H "Authorization: Bearer $TOKEN" -X POST http://$TV:8790/v1/action -d '{"action":"muteFor","minutes":5}'
curl -s -H "Authorization: Bearer $TOKEN" "http://$TV:8790/v1/journal?since=0"

# Logs
adb -s $TV:5555 logcat -s BoretubeGuard BoretubeService BoretubeShell BoretubeHttp BoretubeNsd

# Remove
adb -s $TV:5555 shell pm uninstall com.rakesh.boretube.agent
```

Wait at least 60 s after any package-state change before rebooting the TV. Disables can be lost if it reboots sooner.

## Verified on device (Sony Bravia VU3)

- Re-mute after a remote unmute: **~0.1–0.17 s**.
- Volume cap: never exceeded while the kid holds volume-up.
- Stock YouTube reinstalled → removed again within **7 s**.
- A break survives a TV reboot and an agent outage, and is still enforced when the agent comes back.
- Auto-unmute when a break or timed mute expires.
