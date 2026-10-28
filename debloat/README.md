# Debloat kit (plain adb)

These are small, reversible scripts for cleaning up a Google TV over Wi-Fi ADB. They disable packages rather than uninstalling them, and every write path is a dry run unless you pass `--yes`.

Verified on a Sony BRAVIA VU3 (`BRAVIA_VU3_2K`, Google TV 14). Read [../docs/knowledge/sony-bravia-vu3.md](../docs/knowledge/sony-bravia-vu3.md) first.

## Setup

1. On the TV, go to Settings › System › About and press **Build** 7 times. Then go to Developer options and turn on **Wireless debugging**.
2. Pair from the laptop:
   ```bash
   adb pair <TV-IP>:<pair-port> <code>
   adb mdns services   # find the connect port
   adb connect <TV-IP>:<port>
   ```
   On the VU3, legacy `:5555` also comes up and survives reboots.
3. Point the scripts at the TV:
   ```bash
   export TV=<TV-IP>:5555
   ```

## Scripts

| Script | What it does |
|---|---|
| `./snapshot.sh` | Saves a restore point (getprop, package states, settings, Home, Speech Services version) to `~/.boretube/snapshots/<time>/` |
| `./apply.sh profiles/sony-bravia-vu3.txt [--extras] [--yes]` | Disables the profile's packages. It takes a snapshot first and skips anything on `profiles/never-touch.txt` |
| `./check.sh profiles/sony-bravia-vu3.txt [--extras] [--fix]` | Reports anything that came back after an update, plus stock YouTube and Speech Services state. `--fix` disables those packages again |
| `./restore.sh profiles/sony-bravia-vu3.txt [--extras] [--youtube] [--yes]` | Re-enables the profile's packages, and optionally stock YouTube, to get back to stock |
| `./youtube.sh on|off` | Turns stock YouTube (and YouTube Music) on or off for user 0 |
| `./speech-rollback.sh` | Rolls Google Speech Services back to the factory build. This fixes the SIGILL crash that breaks in-app voice search on this chip |

Rules:

- Apply in batches and **wait at least 60 s before any reboot**. Package state is saved lazily, and a quick reboot loses it.
- Before touching the setup wizard, check who owns the saved Wi-Fi with `dumpsys wifi | grep cname`. On the VU3 we tested, it's setupwraith.
- The TV Guard agent (`../boretube-agent`) runs the same checks automatically after updates. These scripts are the laptop fallback.

## Profiles

- `profiles/sony-bravia-vu3.txt`: 18 packages, plus 4 `[extra]` apps the family didn't use. It's based on the cleanyourtv VU3 list (github.com/Gathin23/cleanyourtv), minus dreamx, setupwraith and launcherx.
- `profiles/never-touch.txt`: packages the scripts always refuse to change.

To add a new TV, copy a profile, check each package on the real set, and record what you verified in `docs/knowledge/`.
