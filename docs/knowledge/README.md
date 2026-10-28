# Knowledge base

This folder holds what we learned building boretube, written so the next person or LLM agent can skip the research. Each claim is marked *(verified)* on a real Sony BRAVIA VU3, or *(research)* when it comes from docs or reports.

| File | Read it when… |
|---|---|
| [sony-bravia-vu3.md](sony-bravia-vu3.md) | You're touching this TV: identity, ADB behaviour, safe and never-touch packages, remote buttons, sound, app-ops reset, the Speech Services crash, the launcher |
| [android-tv-adb-playbook.md](android-tv-adb-playbook.md) | You're writing ADB code or an on-TV agent: the protocol, safe package changes, batching, self-ADB, and dead ends |
| [youtube-shorts-and-smarttube.md](youtube-shorts-and-smarttube.md) | The goal is "YouTube without Shorts": options, SmartTube security and quirks, voice search |
| [launchers-and-debloat.md](launchers-and-debloat.md) | You're choosing a launcher or debloat tool |
| [performance-and-latency.md](performance-and-latency.md) | Something feels slow: the phone Wi-Fi power-save trap, fast paths, UI perception, agent timings |
| [decisions-and-rationale.md](decisions-and-rationale.md) | Before re-opening a settled design question |

Related:

- Design spec: [../superpowers/specs/2026-10-28-boretube-v2-design.md](../superpowers/specs/2026-10-28-boretube-v2-design.md)
- Plans: [P1](../superpowers/plans/2026-10-28-boretube-v2-p1.md) (app core) and [P2](../superpowers/plans/2026-10-28-boretube-v2-p2.md) (TV Guard, safety, restore)
- Debloat kit: [../../debloat/](../../debloat/)
- Legacy v1 story (Cast/DIAL reverse engineering): [../history/v1-README.md](../history/v1-README.md)

## How to add knowledge

- Put new device facts in a `<brand>-<model>.md` file alongside these.
- Mark each claim *(verified)* or *(research)*, with a date.
- Prefer exact commands and outputs over prose.
