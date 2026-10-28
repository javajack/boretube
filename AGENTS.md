# AGENTS.md: start here (for LLM agents and new contributors)

boretube helps a parent control a family Google TV from a phone. It has three parts. The knowledge base exists so you **don't redo the research**: read it before you experiment.

## Map

| Path | What | Read first |
|---|---|---|
| `boretube-mobile/` | **Boretube 2** phone app (Flutter): discovery, ADB, quick actions, rules editor, health and maintenance, restore | `boretube-mobile/README.md` |
| `boretube-agent/` | **TV Guard**, an optional on-TV agent (Kotlin): 24/7 rules, Break, watchdog, HTTP API on :8790 | `boretube-agent/README.md` |
| `debloat/` | Plain-adb debloat kit: per-model lists plus apply/check/restore scripts | `debloat/README.md` |
| `docs/knowledge/` | **Verified facts and research**: Sony VU3, ADB playbook, Shorts/SmartTube, launchers, performance, decisions | `docs/knowledge/README.md` |
| `docs/superpowers/` | Design spec, plus P1 (app core) and P2 (TV Guard) plans | spec |
| `boretube.sh`, `detect.sh` | Legacy v1 bash tool (Cast/DIAL). **Frozen** | `docs/history/v1-README.md` |

## Rules of the road

1. **The TV is the brain, the phone is the remote.** TV Guard is the only rule enforcer, but it is **optional**. The app must stay fully usable without it, and with Cast only.
2. **Never disable** `setupwraith` (it may own the saved Wi-Fi), `launcherx` (remote buttons and voice) or `dreamx` (Ambient), nor input, tuner, Assistant, Play or Speech packages. See `debloat/profiles/never-touch.txt`.
3. **Wait ≥60 s before rebooting a TV** after package changes.
4. Every TV write goes through typed ops with a verify read and a journal entry. There's no raw shell from the UI, and you must keep restore possible (`Restore TV`, `debloat/restore.sh`).
5. Mark new knowledge *(verified)* or *(research)*, with a date, in `docs/knowledge/`.
6. Secrets never go in git: `boretube-agent/keystore/*.jks` and `keystore.properties` are ignored; so are ADB keys and agent tokens.

## Commands

```bash
# Phone app
cd boretube-mobile && flutter analyze && flutter test
# Opt-in, read-only live test against a real TV:
BORETUBE_TV=<ip>:5555 BORETUBE_ADBKEY=~/.android/adbkey flutter test test/adb/adb_live_test.dart

# TV Guard (JDK 17)
cd boretube-agent && ./gradlew test assembleRelease

# Debloat (read-only check)
TV=<ip>:5555 debloat/check.sh debloat/profiles/sony-bravia-vu3.txt --extras
```
