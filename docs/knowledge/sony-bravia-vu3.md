# Sony BRAVIA VU3 (Google TV 14): verified device facts

Everything here was **observed on a real set** between 2026-10-28 and 2026-10-29, unless it is marked *(research)*. Read this before changing anything on this TV. It will save you hours.

## Identity

| Property | Value |
|---|---|
| `ro.product.model` | `BRAVIA VU3` |
| `ro.product.device` | `BRAVIA_VU3_2K` (siblings: `BRAVIA_VU3`, `BRAVIA_VU3_4K`) |
| Platform | Realtek `rtd2885m`, **32-bit** `armeabi-v7a` userspace |
| RAM | 1.5 GB, with ~420 MB in zram swap in normal use. Load average stays at ~24–30 even when idle (Realtek D-state threads, harmless) |
| OS | Google TV 14 (API 34), build `UKR1.240726.001`, fingerprint `Sony/BRAVIA_VU3/BRAVIA_VU3_2K:14/UKR1.240726.001/386-60842:user/release-keys` |
| Stock launcher | `com.google.android.apps.tv.launcherx` |
| Cast | :8008 (DIAL + `/ssdp/device-desc.xml`) and :8009 (CastV2 TLS) |
| Sony REST (:80 `/sony/*`) | **Connection refused** on this set. Don't rely on it |
| Android TV Remote | :6466 and :6467 |

## ADB

- Only **Wireless debugging** (TLS pairing) is offered in Developer options, and it **switches itself off at every reboot**.
- Legacy TCP ADB on **:5555 stays up**. After the first `adb tcpip`/pairing session, `persist.adb.tcp.port=5555` was set, and :5555 has come back after every reboot since, with no user action. mDNS advertises it as `_adb._tcp` with instance `adb-<serial>`.
- **`pm disable-user` changes are lost if you reboot within a few seconds.** Package restrictions are written lazily. Wait **≥60 s** before rebooting.
- A phone ADB client needs one "Allow USB debugging?" on the TV (tick *Always allow*). The TV's own apps connecting to `localhost:5555` need the same. **That approval survives reboots.**

## Packages: what is safe to touch

Disabled and verified OK (TV viewing, HDMI, Wi-Fi, Input menu, remote and casting all keep working):

- Sony: `com.sony.dtv.promos`, `.sonyselect`, `.sonytab`, `.multiscreendemo`, `.smarthelp`, `.helpguidecontents`, `com.sonypicturescore`
- Ads and personalization: `com.android.adservices.api`, `com.android.federatedcompute.services`, `com.android.ondevicepersonalization.services`
- Google leftovers: `com.google.android.feedback`, `.play.games`, `.partnersetup`, `.onetimeinitializer`, `.syncadapters.calendar`, `com.android.printspooler`, `android.autoinstalls.config.google.gtvpai`, `com.android.gallery3d`
- By user choice: `com.sonyliv`, `com.amazon.amazonvideo.livingroom`, `com.apple.atve.androidtv.appletv`, `com.google.android.youtube.tvmusic`
- Stock YouTube `com.google.android.youtube.tv`: removed with `pm uninstall -k --user 0` (the factory copy stays in `/product/app/YouTubeLeanback`). Bring it back with `cmd package install-existing com.google.android.youtube.tv`.
- Factory-disabled out of the box: `com.sony.dtv.b2b.vendorprotocol`.

**Never disable** on this set:

| Package | Why |
|---|---|
| `com.google.android.tungsten.setupwraith` | **It owns the saved Wi-Fi network here** (`dumpsys wifi | grep cname` shows `cname=…setupwraith`). Disabling it can drop Wi-Fi, and it also breaks phone casting after a reboot. On other units the owner can be `android.uid.system`; check yours first. |
| `com.google.android.apps.tv.launcherx` | Realtek's `com.realtek.advancesetting/.GlobalKeyReceiver` hands the Netflix/YouTube/Prime/YT-Music remote buttons to launcherx. It's also where voice-search results are shown. |
| `com.google.android.apps.tv.dreamx` | The Ambient screensaver (Google Photos). The family wanted it. |
| `com.sony.dtv.smartui` | Input button menu |
| `com.realtek.dtv`, `com.realtek.tv.atv`, `com.realtek.tv.passthrough` | Tuner and HDMI |
| `com.realtek.advancesetting` | Global keys and FallbackHome |
| `com.android.tv` | Live TV |
| `com.google.android.katniss` | Assistant / remote mic |
| `com.google.android.gms`, `com.android.vending` | Play Services and Play Store |
| `com.google.android.tts` | Speech recognition. Roll it back, never disable it (see below) |

## Remote buttons

- The YouTube button arrives as `KEYCODE_BUTTON_14`, scancode **569**. Netflix is 758 (`BUTTON_4`), Prime 652 (`BUTTON_2`), YouTube Music 653 (`BUTTON_15`).
- `GlobalKeyReceiver` has `com.google.android.youtube.tv` **hard-coded**. With stock YouTube removed, the button does nothing (it logs `NameNotFoundException`). There's no setting to retarget it.
- Remapping the button needs an accessibility service with `CAPABILITY_CAN_FILTER_KEY_EVENTS`. **Any** key-filtering service on this firmware breaks volume-hold repeat (one step per press). A non-filtering service (window-state events only) is fine.
- The **mic button** never produces an `EV_KEY`. It goes straight to Google Assistant (`katniss`, `ASSISTANT_TV_INTERACTION_FROM_NEAR_FIELD`), whatever app is in front. Apps can't intercept it.

## Sound

- From the **shell**, `cmd media_session volume --set N` and `--adj mute|unmute` are **ignored**. `input keyevent KEYCODE_VOLUME_UP/DOWN/MUTE` works, but `KEYCODE_VOLUME_MUTE` is a **toggle**.
- From an **app's own context**, `AudioManager.adjustStreamVolume(STREAM_MUSIC, ADJUST_RAISE/LOWER)` works, and so do **`ADJUST_MUTE` / `ADJUST_UNMUTE`, which are explicit and idempotent**. `getStreamVolume`/`isStreamMute` read correctly (max 100).
- To read state: `dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'` gives `Muted:` and `streamVolume:`. Both update right after a key press (~350 ms including the dumpsys).

## Permissions and app-ops

- **`appops` grants are reset at every reboot**: `GET_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` go back to `default`. An app that depends on them must re-grant itself after boot (TV Guard does this over self-ADB).
- `am start-foreground-service` from the shell fails for a non-exported service ("Requires permission not exported"). Export it and guard it with `android:permission="android.permission.DUMP"`, which the shell holds and ordinary apps don't.
- On Android 11+, **package visibility** hides `PACKAGE_ADDED` for packages the app can't see. `cmd package install-existing` of YouTube produced no event until the app had `QUERY_ALL_PACKAGES`.
- `foregroundServiceType="specialUse"` (with the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property) works.

## Speech Services crash

- The Play Store auto-updated `com.google.android.tts` to `googletts.google-speech-apk_20260928.02_p0-tv` on 2026-10-27. That build **crashes with SIGILL** in `libgoogle_speech_sbg_tts_jni.so` (conformer encoder): it uses CPU instructions this 32-bit Realtek chip lacks.
- Symptom: in-app voice search (SmartTube's on-screen mic) hears you, then silently does nothing. `logcat` shows `F/DEBUG … SIGILL … com.google.android.tts`.
- Fix: `pm uninstall-system-updates com.google.android.tts` takes it back to the factory build `googletts.google-speech-apk_20251028.02_p2.827711934`, which works. Expect the Play Store to try again. TV Guard's watchdog rolls it back automatically.
- Google Assistant (remote mic) uses a different path and is not affected.

## Launcher

- `com.gathin.tvhome` (from Gathin23/cleanyourtv), with launcherx **kept**. The `HomeKeyService` accessibility redirect is used with `key_filter=false`, so remote buttons and volume ramp both keep working. Google TV home flashes for about 1 s at boot or Home, then the custom launcher takes over.
- Hide tiles without a rebuild: write `config.json` via `content write --uri content://com.gathin.tvhome.theme/config.json` plus a new `theme_revision`, then force-stop and re-put `enabled_accessibility_services`.

## Network

- On this home network, `mogambo` Wi-Fi and the 192.168.1.0/24 subnet: Cast mDNS, `_adb._tcp` mDNS and SSDP DIAL all answer from the phone and the laptop.
- See [performance-and-latency.md](performance-and-latency.md) for the phone Wi-Fi power-save finding.
