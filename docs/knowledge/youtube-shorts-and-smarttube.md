# Blocking YouTube Shorts on a Google TV (research + what we did)

Goal: the family keeps watching YouTube videos, but the kid's Shorts habit is broken.

## What works on TV (state as of Oct 2026)

| Option | Blocks Shorts on TV? | Notes |
|---|---|---|
| **SmartTube** (yuliskov/SmartTube) | Mostly | Settings › General › Hide unwanted content › all Shorts options, plus hiding the Shorts, News and Gaming sections. Open bugs: #6375 (Shorts in search, 32.68), #6364 (kids search "shorts"), plus News #6215 and Gaming #5950 leaks *(research)* |
| YouTube Kids TV app | Yes | Kid content only |
| Google TV kids profile | Limits apps only | No Shorts toggle *(research)* |
| Family Link Shorts timer = 0 (2026) | **No** | Phones and tablets only: "does not apply on computers or TVs" *(research)* |
| YouTube parent code (stock TV app) | No | Only locks profile switching |
| NewPipe / Tubular | Tubular can filter | Built for phones, awkward with a remote |
| TizenTube | n/a | Samsung (Tizen) only |

## SmartTube facts

- **Install only from official sources:** GitHub releases (`yuliskov/SmartTube`), smarttubeapp.github.io, or F-Droid `app.smarttube.fdroid`. Avoid mirror sites.
- **The December 2025 signing-key theft is real:** builds ~30.43–30.51 contained `libalphasdk.so`, a fingerprinting library that phones home. Builds from about 30.55/30.56 use a new key and the app id `org.smarttube.stable`.
  - What we installed: **32.68 stable**, armeabi-v7a, sha256 `2130b23b17ed5cfd324baec81750a2be22059212b6ee17449f21cae2cb3a60d9`, signer "CN=Yurii L, O=SmartTube", no `libalphasdk.so`.
- **Parental lock is weak.** There's a settings/startup password with a known built-in master password, and no kids mode or channel allowlist.
- **Voice search:** use SmartTube's **on-screen** search with *Settings › Search › Misc › Instant voice search* on. The voice engine should stay on "System". The remote's mic button goes to Google Assistant and opens Google TV search, not SmartTube.
- **Voice can die when Speech Services updates.** See the Speech Services crash in [sony-bravia-vu3.md](sony-bravia-vu3.md).
- **Back behaviour:** Back goes content → left menu → exit, which can feel like ignored presses. It's a design choice, not lag.
- **Recurring risk:** YouTube changes break playback for days at a time. SmartTube usually fixes it in a release; check GitHub.

## What we set up

1. SmartTube 32.68 stable installed and verified (hash, signer, no malicious library). The user configured Hide Shorts.
2. Stock YouTube removed for user 0 (`pm uninstall -k --user 0 com.google.android.youtube.tv`). YouTube Music disabled, because it needs stock YouTube.
3. With stock YouTube gone, **phone casting from the YouTube app stops working**. The family doesn't cast, so that was accepted.
4. **TV Guard watchdog:** if stock YouTube comes back (Play Store loophole or firmware), it is removed again within ~7 s unless the parent allows it in the app ("Allow YouTube tonight").
5. Open loophole: SmartTube search can still surface Shorts (#6375). Re-check after SmartTube updates. Agent-side detection of Shorts playback is a possible P3.

## Media-session spike (verified, 2026-10-29, Sony VU3 + SmartTube 32.68)

- SmartTube publishes an **active MediaSession** (`org.smarttube.stable`) with title and channel in `description`, plus a PlaybackState. Read it with `dumpsys media_session`.
- The position follows Android's model: `position` at `updated` (elapsedRealtime ms) × `speed`. A live position = `position + (uptime − updated) × speed`.
- Metadata has 7 fields. `dumpsys` doesn't print the duration. To read `METADATA_KEY_DURATION`, TV Guard needs `MediaSessionManager.getActiveSessions` with notification-listener access (grant over ADB: `cmd notification allow_listener <pkg>/<service>`). Not yet verified.
- **A normal video** keeps one title, steadily `PLAYING`, for minutes.
- **Shorts** cycle `NONE → BUFFERING → PLAYING` with a **new title every ~8–10 s**. Five titles in 40 s is the swipe rhythm.
- Nothing in the session marks a Short explicitly. Detect them by rhythm, e.g. ≥3 distinct titles in ~2 min with each under ~90 s, plus a duration under 3 min if it's readable.
- **End after this one:** pause when the title changes or playback stops, with a 45-minute cap. Show "about N min left" only if the duration is readable.
