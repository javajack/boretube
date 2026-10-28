# Decisions and rationale

These are recorded so future contributors and LLM agents don't re-open settled questions without new information.

| Decision | Why | Revisit if… |
|---|---|---|
| SmartTube for the whole family, stock YouTube removed | Hides Shorts and has no ads; the family already searches inside the YouTube app | SmartTube's Shorts filtering regresses badly, or YouTube Kids becomes acceptable |
| No global voice search for YouTube | The remote mic can't reach SmartTube; the family uses in-app search anyway | An app can take the assistant role on Google TV (untested idea) |
| Keep launcherx, setupwraith and dreamx | Remote app buttons and voice need launcherx; setupwraith owns the Wi-Fi on this unit; the family wants the Photos screensaver | Never, without checking `dumpsys wifi` and the remote buttons |
| Leave the YouTube button unused | Remapping needs a key filter, which breaks volume hold | Firmware changes key handling |
| Flutter app is primary; bash tool frozen | One maintained product; bash had broken Cast volume on Sony | n/a |
| **The TV is the brain, the phone is the remote** (TV Guard is the only enforcer) | Phones leave home, Doze throttles them, and they lose Wi-Fi latency when backgrounded. A single enforcer means no leases or conflicts | — |
| **TV Guard is optional** | Some TVs can't run it, some parents won't install it, and it can break. The app must be complete at the Cast and ADB tiers | — |
| Pure-Dart ADB client instead of a Kotlin library | Testable from the laptop against the real TV; no platform channel | Wireless-debugging TLS pairing becomes necessary (planned fallback) |
| Restore runs from the phone over ADB, not through the agent | Works even when the agent is the thing that broke | — |
| After an OTA, only low-risk watchdog ops run until the parent approves | Firmware updates can change what is safe to disable | — |
| One sneaky/explicit style switch for the whole TV, not per rule | Simpler UX | Parents ask for per-rule styles |
| Break replaces "Pause TV"; quick actions flip optimistically | Clear purpose and countdown; feels instant | — |
| Push to `javajack/boretube`, v2 becomes `main` | Single home for app, agent, debloat and knowledge | — |
