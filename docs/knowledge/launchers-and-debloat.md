# Google TV launchers and debloat (research, Oct 2026)

## Launchers

| Launcher | Status | Widgets | Lock/hide | Takes Home via |
|---|---|---|---|---|
| **cleanyourtv** `com.gathin.tvhome` (Gathin23/cleanyourtv, built locally) | Very active (started Oct 2026) | Add-on *tiles*, not live widgets | `hidden_apps` (config / theme `config.json`) | `HomeKeyService` accessibility redirect, or disabling launcherx |
| Projectivy | v4.71 (Jul 2026) | Limited | Premium parental lock | Accessibility "Override current launcher" |
| ATV Launcher Pro | 0.1.41 (Sep 2026) | Best (clock, weather, system, Watch Next) | Yes | Accessibility |
| AT4K | v1.1 | Good | Yes | Accessibility. Only one launcher should hold the override |
| Arc / LTvLauncher (FLauncher forks) | Active | Minimal | Hide | Needs launcherx disabled |

**Used:** cleanyourtv's launcher with launcherx **kept** and the Home redirect. On Sony/Realtek, disabling launcherx kills the app buttons and the voice results. The user plans to build their own launcher later.

## Debloat tools

- **cleanyourtv** (recommended reference): per-model lists in `examples/`, including a VU3 list. It disables rather than uninstalls, backs up to `~/.cleanyourtv/`, and has `restore.sh` / `check.py --fix`. It is designed to be driven by an AI agent. PCWorld reports AI debloat scripts boot-looping some TVs, so go in batches and reboot between them.
- **Plain adb** is enough. This repo's `debloat/` folder has the VU3 list and small apply/check/restore scripts.
- **UAD-ng:** lists are phone-oriented. **Shizuku + Canta:** uninstalls for user 0; disabling is safer.

## Remote remappers

- tvQuickActions Pro, Button Mapper and Key Mapper all filter keys through an accessibility service. On the VU3 that **breaks volume-hold repeat**.
- On Chromecast, the YouTube button may still open a chooser.

## Sources

- https://github.com/Gathin23/cleanyourtv, including `examples/sony-bravia-vu3/` and `docs/TROUBLESHOOTING.md`
- https://www.pcworld.com/article/3266473/please-dont-use-ai-hacks-to-debloat-your-tv.html
- https://techcrunch.com/2026/10/19/people-are-using-ai-to-make-their-smart-tvs-dumb-again/
- https://www.androidauthority.com/google-tv-update-blocks-projectivy-override-3649445
- https://androidcentral.com/how-remap-youtube-and-netflix-buttons-chromecast-google-tv
