# Performance and latency: measured, explained, fixed

All numbers were measured on the Sony VU3 from a Pixel 9 Pro XL (Android 17) and a laptop, on the same Wi-Fi.

## The phone Wi-Fi power-save trap (biggest win)

- **Symptom:** the app's ADB commands sometimes took **6–16 s** to come back, even though they normally take 0.2–0.7 s. Stalls came roughly every 20 s.
- **What was ruled out:**
  - The TV: a 70 s loop on the TV itself had no command over 600 ms.
  - The client: the same Dart client running on the laptop measured 163–265 ms, 30 times out of 30.
  - Reconnects: logs showed none (connect 92 ms, sign 7 ms).
  - Plain Wi-Fi: 300 pings at 0.2 s had 0 over 200 ms.
- **Cause:** with traffic only every few seconds, the phone's Wi-Fi radio power-saves. Replies get lost, and TCP retransmit back-off (0.2+0.4+0.8+1.6+3.2 s…) turns 0.3 s into 6–8 s. A continuous ping kept the radio awake, which is why the ping test looked clean and an A/B test with a background ping "fixed" it.
- **Fix:** hold `WifiManager.createWifiLock(WIFI_MODE_FULL_LOW_LATENCY)` while the app is on screen: acquire in `onResume`, release in `onPause`. See `boretube-mobile/android/.../MainActivity.kt`. Note that the low-latency lock only applies while the app is foreground with the screen on. That is one reason 24/7 enforcement lives on the TV (TV Guard).

## Quick action round trips

| Action | v1 (naive) | Combined shell | Fast path |
|---|---|---|---|
| Mute/unmute | 4 round trips, 650–800 ms | 1 round trip, ~650 ms | **150–190 ms** (a fresh poll knows the state, so the key is sent alone, then verified in the background and corrected if wrong) |
| Stop app | 5 round trips | 1 round trip, ~500 ms | n/a |
| Bore / Break | 9 round trips | 2 round trips | n/a |

- **UI perception:** flip the tile optimistically on tap, with haptic feedback. Show no success ring or tick, and a spinner only after 1.5 s. Users read a short spinner plus tick as "slow" even when the TV had already acted.
- **Priority lane:** user actions jump ahead of background polls in the ADB session queue. The poll pauses while an action is in flight.

## TV Guard (on-TV agent)

- Re-mute after a remote unmute during a break: ~100–170 ms (223–322 ms measured end-to-end, including a ~150 ms dumpsys read).
- Volume cap: ten fast volume-up presses never got the level above the cap.
- Self-ADB command: ~200 ms (first after boot ~725 ms).
- Watchdog: a stock YouTube reinstall is removed within ~7 s (package event, 3 s settle) and within ≤60 s by the backup check.
- Agent API `/v1/status`: available as soon as adbd is up after a reboot.

## Debugging tips

- Debug builds of the phone app log `BTIME` lines: `adb logcat -s flutter | grep BTIME`. They show per-ADB-job wait and run times, connect and sign times, and per-action totals.
- To separate TV, client, network and app problems, run the same command (a) on the TV in a shell loop, (b) from the laptop with the same client, and (c) as ping from the phone, both long and continuous. Then compare.
