# Android / Google TV over ADB: a playbook

These are reusable lessons from building boretube. Each one notes whether we saw it on the Sony VU3 *(verified)* or are relying on documentation or reports *(general)*.

## Connecting

- **Pairing (Android 11+ wireless debugging):** `adb pair IP:PAIRPORT CODE`, then `adb connect IP:CONNECTPORT`. The connect port differs from the pairing port; find it with `adb mdns services`. *(verified)*
- **Legacy TCP :5555:** after `adb tcpip 5555`, many TVs keep `persist.adb.tcp.port`, and :5555 then survives reboots. That makes :5555 the reliable target for an app. *(verified on VU3)*
- **mDNS:** `_adb._tcp` (legacy), `_adb-tls-connect._tcp`, `_adb-tls-pairing._tcp`. The instance name `adb-<serial>-xxxx` is a **stable device identity** that survives IP changes. *(verified)*
- **Writing your own client:** the legacy protocol is simple:
  - 24-byte header, little-endian: `cmd, arg0, arg1, len, crc32 (byte sum), magic = cmd ^ 0xffffffff`.
  - Commands: `CNXN 0x4e584e43`, `AUTH 0x48545541`, `OPEN 0x4e45504f`, `OKAY 0x59414b4f`, `CLSE 0x45534c43`, `WRTE 0x45545257`, `STLS 0x534c5453`.
  - Send version `0x01000001` so adbd skips the checksum.
  - AUTH: sign the 20-byte token with PKCS#1 v1.5 using the **SHA-1 DigestInfo prefix** (`3021300906052b0e03021a05000414`) applied to the token as-is. The TV verifies it as if it were a SHA-1 digest.
  - If the signature is rejected, send `AUTH(3)` with the **Android public-key struct** (`len_words, n0inv, n[LE], rr[LE], e`, base64) followed by `" name\0"`. The TV then shows "Allow USB debugging?".
  - See `boretube-mobile/lib/adb/` for a ~400-line pure-Dart implementation, verified against the VU3. A pure-Dart RSA-2048 sign takes ~7 ms on a Pixel 9 Pro XL.
- **Exit codes over `shell:`:** append `; echo "__BTEXIT:$?"` and parse it out. *(verified)*

## Changing packages safely

- Use `pm disable-user --user 0 PKG`, undone with `pm enable PKG`. It's reversible and survives updates, though firmware updates may re-enable packages.
- Use `pm uninstall -k --user 0 PKG` when the user must not be able to re-enable it from Settings. Restore it with `cmd package install-existing PKG`. The system copy stays.
- **Always verify with a read after a write.** **Wait ≥60 s before rebooting** after state changes. *(verified)*
- Keep a **never-touch list**: setup wizard (may own Wi-Fi), stock launcher (remote buttons), Live TV, tuner and HDMI packages, Assistant, Play Services, Play Store, Speech Services.
- Check who owns the saved Wi-Fi before disabling the setup wizard: `dumpsys wifi | grep cname`.
- Roll back a bad Play update of a system app with `pm uninstall-system-updates PKG`.

## Timing and batching

- One `adb shell` round trip to the TV takes ~70–200 ms. Heavy `dumpsys` calls take ~100–140 ms on the TV itself. *(verified)*
- **Chain commands into one shell call**, e.g. `a; echo ---; b`, and split the output on markers. A quick action went from 4–6 round trips to 1.
- Note that `dumpsys activity activities | grep -m1 …` prints "Broken pipe" from dumpsys. It's harmless.

## Apps that need shell powers on the TV ("self-ADB")

- A TV app can connect to its own `localhost:5555` with its own key (e.g. **dadb** `dev.mobile:dadb`). After a one-time "Allow" it runs commands as uid 2000 (shell): `am force-stop`, `pm …`, `appops set …`. That approval survived reboots. *(verified)*
- **Re-grant app-ops at every start.** The VU3 resets `GET_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` on reboot. *(verified)*
- To be startable from the shell, a service must be exported. Protect it with `android.permission.DUMP`. *(verified)*
- Package events need `QUERY_ALL_PACKAGES` on Android 11+. Also add a periodic check, because events can be missed. *(verified)*
- Use `AudioManager` from the app context for volume and explicit mute. It works even where shell `media_session` is ignored. *(verified)*
- Foreground app: `UsageStatsManager.queryEvents` (`ACTIVITY_RESUMED`), polled at 1 s. Fallback: `dumpsys activity activities | grep -m1 topResumedActivity`.
- **Don't add accessibility services that filter key events.** On Realtek/Sony firmware they break volume-key repeat. *(verified)*

## Things that don't work (save yourself the time)

- Retargeting the Sony remote's YouTube button: it is hard-coded in Realtek's GlobalKeyReceiver.
- Intercepting the remote mic: it goes straight to Assistant, with no key event.
- Absolute volume set or explicit mute from the shell on the VU3.
- The SmartTube voice bridge on a TV with YouTube built in. It needs YouTube's package name, which needs root on Sony. *(research)*
- Sony REST `/sony/*` on the VU3: port 80 is closed.
