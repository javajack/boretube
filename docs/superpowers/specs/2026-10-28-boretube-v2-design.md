# boretube v2 — design

Date: 2026-10-28 · Status: approved (simplified model) · Scope: Flutter app `boretube-mobile/` + new TV agent `boretube-agent/`. The bash tool (`boretube.sh`, `detect.sh`) is frozen: no new features.

## 1. Goal

Control the family TV remotely from a phone. When a kid is glued to the TV, often at high volume, a parent can stop apps, cap the volume, mute, or end TV time. The TV also stays clean after the 2026-10-28 debloat (stock YouTube removed, SmartTube in use).

Success means:

- From the phone, a parent can mute, stop the current app, set the volume, or "bore" the TV in one tap, on any discovered TV.
- On ADB-capable TVs, rules (allowed apps, volume limit, TV time) keep working with the phone away or off.
- After a firmware or Play update, the TV heals itself: YouTube is removed again, Speech Services is rolled back, the cleanup list is re-applied, and Home is checked. Nobody has to open a laptop.
- The TV's IP can change without breaking anything.
- Every existing app feature survives (see §9).

## 2. Core model

**The TV is the brain; the phone is a remote.**

- **TV Guard** (the on-TV agent) is the **only** rule enforcer. Rules live on the TV. They're enforced 24/7, offline, on the TV's clock.
- **Phone** = remote control + rule editor + status/health dashboard.
  - **Instant actions** (Mute/Unmute, Stop app, Volume → N, Bore, Pause TV N min, Restore) run directly from the phone over Cast/Sony REST/ADB, on any TV.
- **Classic lock**: on TVs without TV Guard (Cast-only, or agent not installed), the app offers today's timed lock. A phone foreground service polls and acts. It's a separate feature. There is no automatic switching between the classic lock and TV Guard.
- If two phones edit the rules, the last write wins. The rule set records `updatedBy` and `updatedAt`, and both are shown in the app.

## 3. Discovery and identity

Three discovery methods run together, and their results are merged:

1. **mDNS**: `_googlecast._tcp`, `_adb._tcp`, `_adb-tls-connect._tcp`, `_boretube._tcp`.
2. **SSDP**: M-SEARCH `urn:dial-multiscreen-org:service:dial:1`.
3. **Subnet sweep** (fallback):
   - Scans the phone's /24 plus the gateway candidates `192.168.0.1`, `192.168.1.1`, `192.168.2.1`, `10.0.0.1`, `10.0.1.1`, `172.16.0.1` (the same list `detect.sh` uses).
   - A hit needs TCP 8008 **and** 8009 open.
   - Probes run 50 at a time, with a 600 ms timeout each.

Each hit is identified with `GET :8008/ssdp/device-desc.xml`, which gives the friendly name, manufacturer, model and UDN.

**Stable TV id.** Use the first one available:

1. the agent id
2. the ADB serial (mDNS instance name, e.g. `adb-qaezcxxq07001865`)
3. the Cast/UDN uuid
4. `ip:` (temporary)

Saved TVs are keyed by this id. If a saved TV stops answering, the app re-discovers it, matches it by id, updates the IP, and shows "Living Room TV moved to .7". Several TVs can be saved; one is active at a time.

## 4. Capabilities

The app probes each TV on connect (and on refresh) and caches the result per TV:

| Capability | Probe | Unlocks |
|---|---|---|
| `cast` | CastV2 :8009 GET_STATUS | see the running app, stop app, mute, volume (Cast volume is wrong on Sony) |
| `dial` | :8008 device-desc | YouTube/Netflix DIAL stop |
| `sonyRest` | `POST :80/sony/audio getVolumeInformation` | correct volume read/set, mute |
| `adb` | :5555 CNXN + authorized | the TV tab (Health/Apps), strong stop, all maintenance |
| `agent` | `_boretube._tcp`, or `GET :8790/v1/status` with token | Rules tab, 24/7 enforcement |

The UI shows only controls the TV supports. A missing capability shows an "Unlock with ADB" or "Install TV Guard" tip instead of a button that would fail.

## 5. Phone ADB layer (`lib/adb/`)

- **Pure-Dart ADB over TCP** to `:5555`: CNXN, then AUTH (signature, then public key), then OPEN/WRTE/OKAY/CLSE.
  - The app generates an RSA-2048 key on first run and keeps it in secure storage.
  - The first connection makes the TV show "Allow USB debugging?". The app guides the parent to choose "Always allow".
  - Supported: `shell(cmd)` → stdout + exit code (`;echo $?` trailer), `install(apk)` via push+`pm install`, keep-alive, and auto-reconnect.
- The same code runs under `dart test` on the laptop against a real TV, through opt-in integration tests.
- Wireless-debugging pairing (TLS + SPAKE2) is deferred.

**`TvOps`** is the only API the UI uses. Each operation is typed and has check / apply / verify / undo:

| Op | Apply | Undo |
|---|---|---|
| stopApp(pkg) | `am force-stop` | — |
| setAppEnabled(pkg, on) | `pm enable` / `pm disable-user --user 0` | inverse |
| stockYouTube(on) | `cmd package install-existing com.google.android.youtube.tv` + enable tvmusic / `pm uninstall -k --user 0 …youtube.tv` + disable tvmusic | inverse |
| speechRollback() | `pm uninstall-system-updates com.google.android.tts` when the version is newer than the profile's known-good | — |
| applyCleanup() | disable each package in the profile's list | enable each |
| launcherHealth() | check HOME + `enabled_accessibility_services` contains the redirect helper; re-put the list if missing | — |
| volume / mute | Sony REST, else `cmd media_session volume --set` / `input keyevent` | — |

Rules for every TV write:

- A built-in **never-touch list** blocks dangerous ops: setupwraith, launcherx, Realtek/Sony input, tuner and key packages, Play Services, Play Store, the agent, and the launcher.
- A **verify read** after every write.
- A per-TV **journal** (op, time, before/after, undo).
- **Wait at least 60 s before any reboot.** Disables are lost if the TV reboots sooner.

**Device profiles** are JSON assets (`assets/profiles/*.json`). Each holds `match` (brand/device/build), `cleanup` packages, `neverTouch`, `knownGood` versions (e.g. tts `20251028`), and `quirks`.

- The first profile is `sony-bravia-vu3`, built from the 2026-10-28 session.
- Unknown TVs get a generic profile, and maintenance stays read-only until the parent opts in.

## 6. TV agent (`boretube-agent/`, Kotlin, package `com.rakesh.boretube.agent`)

- **Shape:** a small foreground service plus a boot receiver. It has no launcher tile.
  - The APK ships inside the phone app's assets. The phone installs and updates it over ADB and pins its signing cert.
- **Permissions**, granted by the phone over ADB:
  - `appops set … GET_USAGE_STATS allow` (foreground app)
  - `appops set … SYSTEM_ALERT_WINDOW allow` (explicit card)
  - `pm grant … WRITE_SECURE_SETTINGS`
- **Self-ADB:** dadb connects to `localhost:5555` with the agent's own key. That triggers one more "Allow" on the TV, guided by the phone. It's used for force-stop, `pm`, and settings.
  - Without it, the agent runs in **limited mode**: it still detects apps, clamps volume and shows the card, and it reports "limited".
- **Foreground app:** read with `UsageStatsManager.queryEvents`, polled at 1 s. No accessibility service, so it doesn't interfere with the launcher's Home helper or volume-hold repeat.
- **Volume:** watch STREAM_MUSIC changes and clamp through AudioManager. If that doesn't move the panel, fall back to Sony REST on localhost. The P0 spike verifies which path works.
- **Rules** (one JSON document, versioned):
  - `allowedApps` (allowlist, or a blocklist with `mode`)
  - `volumeLimit` (max %, or `mute: true`)
  - `tvTime`: `schedule` (blocked windows per weekday) + `dailyLimitMin`, counted only while the screen is on and not on an HDMI input. HDMI is noted as out of scope for app rules; volume and TV-time rules still apply.
  - `style: sneaky|explicit` — a single TV-wide switch.
  - Optional `until` timestamps for temporary overrides ("allow YouTube tonight", "muted for 30 min").
- **Enforcement:**
  - **Sneaky:** force-stop the blocked app, then HOME; clamp or mute the volume.
  - **Explicit:** a full-screen card ("TV time is over · back at 7:00"), then HOME.
- **Maintenance watchdog** runs on boot, on `PACKAGE_ADDED`/`REPLACED`, and every 6 h. It runs the same ops as §5, driven by the profile the phone pushes: YouTube watchdog (unless `stockYouTube` is allowed), speech rollback, cleanup re-apply, launcher health. Each run writes to the journal.
- **API:** HTTP+JSON on LAN `:8790`, announced as `_boretube._tcp` with TXT `id`, `ver`.
  - Auth is a bearer token. The agent generates it on first start and stores it at `/sdcard/Android/data/com.rakesh.boretube.agent/files/token`, which only ADB/shell can read. The phone reads it once over ADB.
  - Endpoints: `GET /v1/status` (now playing, volume, active rules, health), `GET/PUT /v1/rules`, `POST /v1/action` (mute, stop, volume, bore, pause, restore), `GET /v1/journal?since=`.
- **Tamper:** if the agent is disabled or uninstalled, the phone sees it missing and shows a red "TV Guard down", with **Repair** (enable or reinstall over ADB).

## 7. App UX

- **App lock:** a parent PIN or biometric is needed to open the app.
- **Top bar:** TV switcher + status pill:
  - 🟢 TV Guard on
  - 🟡 TV Guard limited
  - 🔵 Classic lock running
  - ⚪ Not guarded
  - 🔴 TV Guard down
- **First run:** Find TVs → Connect (capability check) → optional Unlock ADB guide ("Allow" on TV) → optional Install TV Guard → set PIN.

**Three tabs:**

1. **Now**
   - Now-on-TV card: app icon/name or input, a live volume meter, mute state.
   - Quick actions: Mute/Unmute · Stop app · Bore · Volume slider · Pause 15/30/60 · Restore.
   - Active rule chips with countdowns.
   - The last 5 events.
   - On TVs without the agent, the **Classic lock** card (mode, interval, max volume, duration, start/stop, countdown, live feed) lives here.
2. **Rules** (agent TVs only)
   - Allowed apps · Volume limit · TV time · the Sneaky/Explicit switch · temporary overrides.
3. **TV**
   - **Health** checklist with Fix / Fix all: cleanup N/N · YouTube removed · Speech OK · Home OK · ADB OK · Agent vX.
   - **Apps:** the TV's apps with Allowed/Blocked/Removed, the YouTube card (toggle + "allow tonight"), and "what's playing → allow".
   - **Activity:** the journal and events, with Undo.
   - **Settings:** saved TVs, poll interval, notifications, PIN, ADB key, about.

**Notifications:**
- A classic-lock ongoing notification with Stop (kept as today).
- Alerts: TV Guard down, YouTube came back and was removed, volume capped often.

## 8. Edge cases

| Case | Behaviour |
|---|---|
| Phone away or off | Agent enforces. When the phone comes back, it shows a "while you were away" summary from the journal. |
| Agent disabled or crashed | 🔴 + Repair. No automatic phone takeover; the classic lock is offered manually. |
| Phone not on home Wi-Fi | Status shows "not home". Instant actions are disabled. Rules keep running on the TV. |
| TV off or standby | "Off, last seen …". TV time only counts screen-on time. |
| TV reboot or firmware update | Agent restarts and re-applies. If ADB authorization is lost, the app shows a guided "Allow again". |
| IP change | Re-discovered and matched by id. |
| TV clock more than 2 min off | Phone sends its time when it syncs, and the agent shows a warning. |
| Kid raises the volume | Agent clamps it within about 0.2 s. |
| Kid reinstalls YouTube | Watchdog removes it, unless it's allowed. |
| Kid switches to HDMI | App rules don't apply. Volume and TV-time rules do. |
| Cast-only TV | Instant actions + classic lock only. Rules/TV tabs show unlock tips. |

## 9. Preservation map (current app → v2)

| Current | v2 |
|---|---|
| Lock Apps / Lock Volume, check interval, max %, duration, countdown, live feed | **Classic lock** card (non-agent TVs) and Rules (agent TVs) |
| Whitelist screen + "what's playing → add" | TV → Apps (+ classic lock whitelist) |
| Sony REST hardware volume | kept in `TvOps` volume |
| Foreground service + notification Stop | kept for the classic lock |
| Settings IP/name/ports | Settings → TVs, auto-filled by discovery; manual entry kept |
| Unmute on lock end | kept |

## 10. Phases

- **P0 — spike** (laptop):
  - The Dart ADB client connects to the real TV and runs `shell`.
  - Confirm Android `AudioManager`/`media_session` volume moves the real Sony panel volume.
- **P1 — app core:**
  - New shell (PIN, 3 tabs, TV switcher), discovery + identity, capabilities, instant actions.
  - ADB layer + `TvOps` + profiles + Health/Apps/journal.
  - Classic lock ported, with whitelist and existing tests kept green.
- **P2 — TV Guard:**
  - Agent app, install/repair flow, rules + enforcement, explicit card, watchdog, API.
  - Rules tab and status pill.
- **P3 — later:** presets, watch-time stats, Quick Settings tile/widget, pairing-code fallback.

## 11. Testing

- Unit tests:
  - rule engine (pure Kotlin/Dart)
  - discovery merge and identity matching
  - `TvOps` command building and never-touch guard
  - profile matching
  - the existing 76 tests
- A fake TV server (Cast, Sony, ADB) for service tests.
- Opt-in integration tests (`BORETUBE_TV=192.168.1.3:5555`) run from the laptop against the real TV, read-only by default.
- Agent: JVM unit tests for the rules and engine; an on-TV smoke test via ADB.
- `flutter analyze` must stay at zero issues.

## 12. Non-goals

- New features in the bash tool.
- iOS background enforcement.
- Root.
- Blocking content inside apps (SmartTube's own Shorts settings handle that).
- Cloud or remote access from outside the home network.
