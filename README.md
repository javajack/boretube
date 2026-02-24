# boretube

**A parental control tool for Sony Bravia Google TV, built from scratch using reverse-engineered Cast protocols.**

Your kid is glued to YouTube Shorts on the living room TV. The remote is "lost" (under the couch cushion, obviously). You need a way to kill apps, mute the TV, and cap the volume — all from your laptop on the other side of the house. No root access on the TV. No ADB. No special apps installed. Just raw network packets and stubbornness.

```
  ╔═══════════════════════════════════════════╗
  ║       BORETUBE - Parental Control         ║
  ║        Sony Bravia Google TV (VU3)        ║
  ╚═══════════════════════════════════════════╝

  Status:  ● Connected
  Running: YouTube (not whitelisted)
  Volume:  ██░░░░░░░░ 20%

  Allowed: 1 app(s) | Lock checks every 10s

  ───────────────────────────────────────────

  1)  Lock          Auto-enforce whitelist for X min
  2)  Volume Lock   Cap volume at max % for X min
  3)  Restore TV    Unmute TV, let all apps run
  4)  Whitelist     Manage which apps are allowed
  5)  Log           View activity log

  q)  Quit
```

---

## Table of Contents

- [The Problem](#the-problem)
- [How We Found the TV](#how-we-found-the-tv)
- [What Did NOT Work](#what-did-not-work)
- [What Worked](#what-worked)
- [Features Explained](#features-explained)
- [Project Structure](#project-structure)
- [Runtime Setup](#runtime-setup)
- [Known Cast App IDs](#known-cast-app-ids)
- [How It All Fits Together](#how-it-all-fits-together)

---

## The Problem

A Sony Bravia VU3 running Google TV. A kid who has memorized the exact sequence of remote button presses to get to YouTube faster than you can say "screen time limit." The built-in parental controls on Google TV are... let's call them "aspirational." They exist in settings menus but don't actually prevent a determined 8-year-old from watching "just one more" Shorts video for the 47th time.

**What we needed:**
- Kill YouTube (and any other app) remotely from a terminal
- Mute the TV to make watching boring (no sound = no dopamine hit)
- Cap volume so even allowed content can't shake the walls
- Auto-enforce a whitelist: if the kid opens a blocked app, it dies within 10 seconds
- All of this without installing anything on the TV itself

**Constraints:**
- No physical access to the TV (it's in the living room, we're in the study)
- No ADB enabled on the TV
- TV is on a different subnet than our laptop
- No root, no sideloaded apps, no companion device
- Must work with just a bash script and network access

---

## How We Found the TV

This was the first puzzle. Our laptop sits on a MiWiFi router (`192.168.31.x` subnet) that acts as an access point, connected upstream to a Hathway router (`192.168.1.x` subnet) where the TV lives. Two different subnets.

### Step 1: Discover the local network

```bash
# Our laptop
$ ip route
default via 192.168.31.1 dev wlp2s0
192.168.31.0/24 dev wlp2s0 proto kernel scope link
```

So we're on `192.168.31.x`. The MiWiFi router is at `192.168.31.1`. But the TV isn't here.

### Step 2: Find the upstream network

The MiWiFi router is in AP mode, bridged to a Hathway router. Common home router IPs: `192.168.0.1`, `192.168.1.1`, `10.0.0.1`. Let's try:

```bash
$ ping -c 1 -W 1 192.168.1.1
64 bytes from 192.168.1.1: icmp_seq=1 ttl=64 time=1.23 ms   # Bingo!
```

### Step 3: Find the TV on 192.168.1.x

Ping sweep of `192.168.1.2` through `192.168.1.10` found three live hosts:
- `192.168.1.1` — the Hathway router
- `192.168.1.2` — unknown device
- `192.168.1.3` — unknown device

### Step 4: Port fingerprinting to identify the TV

Google Cast devices have a distinctive port signature:

| Port | Protocol | Purpose |
|------|----------|---------|
| 8008 | HTTP | DIAL (Discovery and Launch) protocol |
| 8009 | TLS | CastV2 binary protocol |
| 8443 | HTTPS | CastV2 alternate |

```bash
$ nmap -p 8008,8009,8443 192.168.1.3
PORT     STATE SERVICE
8008/tcp open  http
8009/tcp open  ssl
8443/tcp open  https-alt
```

Three Cast ports open. This is our TV.

### Step 5: Confirm identity

```bash
$ curl -s http://192.168.1.3:8008/ssdp/device-desc.xml | grep friendlyName
<friendlyName>BRAVIA VU3</friendlyName>
```

Confirmed: **Sony BRAVIA VU3** at `192.168.1.3`.

---

## What Did NOT Work

We tried every "proper" approach before resorting to raw protocol hacking. Here's the graveyard:

### Sony Bravia REST API (Port 80)

Sony Bravia TVs supposedly have a REST API at `http://<ip>/sony/system` for controlling the TV. Official Sony documentation mentions endpoints like `/sony/system`, `/sony/avContent`, `/sony/audio`.

```bash
$ curl -s --max-time 5 http://192.168.1.3/sony/system
# ... timeout. Nothing. Port 80 is either firewalled or the API isn't enabled.
```

**Why it failed:** The REST API requires explicit enablement in TV settings (Settings > Network > Home Network > IP Control). On this Bravia VU3 running Google TV, the option either doesn't exist or is buried deep enough that we never found it. The port simply doesn't respond.

### ADB (Android Debug Bridge)

Google TV is Android under the hood. ADB on port 5555 would give us shell access — we could `am force-stop` any app, change volume via `media` commands, the works.

```bash
$ nmap -p 5555 192.168.1.3
PORT     STATE  SERVICE
5555/tcp closed adb
```

**Why it failed:** ADB over network is disabled by default on production Android TV devices. Enabling it requires: Settings > Device Preferences > About > Build (tap 7 times for Developer Options) > Network debugging. This requires the TV remote and physical presence. If we had that level of access, we wouldn't need this tool.

### pychromecast (Python library)

The "official" way to talk to Chromecast/Google Cast devices from Python. Installed it, tried it:

```python
import pychromecast
chromecasts, browser = pychromecast.get_chromecasts()
# ... hangs forever. No devices found.
```

**Why it failed — Reason 1: mDNS doesn't cross subnets.**

pychromecast uses Zeroconf/mDNS (multicast DNS) to discover Cast devices. mDNS uses multicast address `224.0.0.251` on port `5353`. Multicast is **link-local** — it doesn't get routed across subnets. Our laptop is on `192.168.31.x`, the TV is on `192.168.1.x`. The mDNS packets from pychromecast never reach the TV.

```bash
$ avahi-browse -r _googlecast._tcp.local
# ... nothing. Zero results.
```

**Why it failed — Reason 2: API changed.**

Even when we tried to bypass discovery and connect directly by IP:

```python
cast = pychromecast.Chromecast('192.168.1.3')
# AttributeError: 'str' object has no attribute 'cast_type'
```

pychromecast's `Chromecast()` constructor no longer accepts a plain IP string. It now requires a `CastInfo` object. We tried manually constructing one:

```python
from pychromecast.models import CastInfo
info = CastInfo(
    services={...},
    uuid=...,
    model_name="BRAVIA VU3",
    friendly_name="BRAVIA VU3",
    host="192.168.1.3",
    port=8009,
    cast_type="cast",
    manufacturer="Sony"
)
cast = pychromecast.get_chromecast_from_cast_info(info, zconf)
cast.wait()  # ... hangs indefinitely
```

It connects but `wait()` never returns because the internal Zeroconf browser keeps trying to discover the device via mDNS, which can't work cross-subnet.

### SSDP Discovery

Simple Service Discovery Protocol. Used by UPnP devices.

```bash
# Send M-SEARCH multicast
$ echo -e "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n..." | \
  socat - UDP4-DATAGRAM:239.255.255.250:1900
```

**Why it failed:** Same as mDNS — multicast is link-local. SSDP uses `239.255.255.250:1900`, which doesn't get routed across subnets. We only found the MiWiFi router.

---

## What Worked

After all the "proper" approaches failed, we went lower level.

### DIAL Protocol (Port 8008)

DIAL (Discovery and Launch) is an HTTP-based protocol developed by Netflix and YouTube for discovering and launching apps on smart TVs. It runs on port 8008 and speaks plain HTTP. No authentication. No encryption. No mDNS required.

**What DIAL can do:**
- Query if an app is running: `GET http://<ip>:8008/apps/YouTube`
- Launch an app: `POST http://<ip>:8008/apps/YouTube`
- **Kill a running app: `DELETE http://<ip>:8008/apps/YouTube/run`**

```bash
# Check if YouTube is running
$ curl -s http://192.168.1.3:8008/apps/YouTube
<?xml version="1.0" encoding="UTF-8"?>
<service xmlns="urn:dial-multiscreen-org:schemas:dial" dialVer="2.1">
  <name>YouTube</name>
  <state>running</state>
  ...
</service>

# Kill it
$ curl -s -X DELETE http://192.168.1.3:8008/apps/YouTube/run
```

**Limitations:**
- Can only target apps by name (you need to know the exact DIAL name)
- Only works for apps that register with DIAL (YouTube, Netflix — but not all apps)
- Cannot control volume, mute, or query what's currently running
- No way to get a list of ALL running apps

DIAL is used in our `do_bore()` function as a belt-and-suspenders kill alongside CastV2. It fires `DELETE` requests for YouTube and Netflix in parallel background processes.

### CastV2 Protocol (Port 8009) — The Real Deal

CastV2 is the binary protocol that Chromecast devices use for all communication. It runs over TLS on port 8009. This is what Google Home, Chrome browser, and every Cast-enabled app uses to talk to your TV.

**CastV2 gives us everything:**
- `GET_STATUS` — what app is running, volume level, mute state, idle status
- `SET_VOLUME` — set volume level (0.0 to 1.0) and mute/unmute
- `STOP` — kill the currently running app
- `LAUNCH` — start an app by ID

**The wire format is Protocol Buffers (protobuf).** Each message is:

```
[4 bytes: message length (big-endian)] [protobuf-encoded CastMessage]
```

The CastMessage protobuf schema (reverse-engineered from Chromium source):

```protobuf
message CastMessage {
  required ProtocolVersion protocol_version = 1;  // always 0 (CASTV2_1_0)
  required string source_id = 2;                   // "sender-0"
  required string destination_id = 3;              // "receiver-0"
  required string namespace = 4;                   // e.g. "urn:x-cast:com.google.cast.receiver"
  required PayloadType payload_type = 5;           // always 0 (STRING)
  optional string payload_utf8 = 6;                // JSON payload
}
```

The JSON payload inside field 6 is where the actual commands live:

```json
// Connect (must be sent first to establish a virtual connection)
{"type": "CONNECT"}

// Get current status
{"type": "GET_STATUS", "requestId": 1}

// Response contains everything we need:
{
  "type": "RECEIVER_STATUS",
  "status": {
    "volume": {"level": 0.15, "muted": false},
    "applications": [{
      "appId": "233637DE",
      "displayName": "YouTube",
      "isIdleScreen": false
    }]
  }
}

// Mute the TV
{"type": "SET_VOLUME", "volume": {"muted": true}, "requestId": 2}

// Set volume to 15%
{"type": "SET_VOLUME", "volume": {"level": 0.15}, "requestId": 3}

// Kill the running app
{"type": "STOP", "requestId": 4}
```

**Our implementation** encodes protobuf manually using Google's `protobuf` Python library internals (`_VarintBytes`, `_DecodeVarint32`). We don't use `.proto` files or generated code — just raw field encoding. This keeps the dependency footprint minimal and the code self-contained.

The entire CastV2 engine lives as a Python heredoc inside the bash script (lines 70-207 of `boretube.sh`). Each invocation:

1. Opens a TCP socket to `192.168.1.3:8009`
2. Wraps it in TLS (self-signed cert, no verification — standard for Cast devices)
3. Sends a `CONNECT` message to establish the virtual session
4. Sends the requested command(s)
5. Reads the response, extracts JSON from the protobuf envelope
6. Prints a clean JSON result to stdout
7. Closes the connection

**Performance optimization — the "bore" action:** The original implementation opened separate connections for STOP and MUTE (two TLS handshakes, ~2 seconds total). The `bore` action combines both into a single connection: send STOP, wait 300ms for the TV to process it, then send MUTE. One TLS handshake, ~0.5 seconds total.

---

## Features Explained

### 1) Lock Mode — Whitelist Enforcement

The core feature. You set a duration (default 60 minutes), and the script enters a polling loop:

```
Every 10 seconds:
  1. Connect to TV via CastV2
  2. GET_STATUS → what app is running?
  3. Is it in the whitelist?
     YES → log "whitelisted", do nothing
     NO  → STOP the app via CastV2
           MUTE the TV via CastV2 (same connection, "bore" action)
           DELETE YouTube and Netflix via DIAL (parallel, background)
           Log "Stopped: YouTube (not whitelisted)"
  4. Sleep 10 seconds
  5. Repeat until timer expires or Ctrl+C
```

**Why 10 seconds?** It's the sweet spot. Less than 5 seconds risks overwhelming the TV with requests (Cast devices aren't designed for rapid-fire polling). More than 30 seconds gives the kid too much viewing time before enforcement kicks in. At 10 seconds, the effective cycle is ~12-13 seconds (10s sleep + 2-3s for status check and enforcement). That means the kid gets at most ~13 seconds of a blocked app before it dies.

**The mute is intentional cruelty (by design).** Stopping the app alone isn't enough — the kid just re-opens it. But if the TV is also muted, even re-opening YouTube gives them a silent screen. They give up faster. The mute persists until you explicitly restore the TV (option 3).

**What happens when the TV is off?** The CastV2 connection fails, the script logs "TV is off or in standby", and moves on. It doesn't crash. When the TV comes back on, enforcement resumes automatically on the next poll.

**Ctrl+C handling:** A trap on `SIGINT`/`SIGTERM` catches interrupts. If lock mode is active, the cleanup function automatically unmutes the TV before exiting. No orphaned mute states.

### 2) Volume Lock — Sound Cap Enforcement

Sometimes the kid is allowed to watch TV — but not at earthquake volume levels. Volume Lock lets you set a maximum volume percentage (default 15%) for a duration.

```
Every 10 seconds:
  1. Connect to TV via CastV2
  2. GET_STATUS → current volume?
  3. Is it above the cap?
     YES → SET_VOLUME to the cap level
           Log "VOLLOCK: YouTube vol 45% → 15%"
     NO  → Log "vol=12% ok", do nothing
  4. Sleep 10 seconds
```

The kid can turn the volume up with the remote, but within 10 seconds it gets pushed back down. They learn pretty quickly that the volume fairy doesn't want them going above 15%.

**Why not just mute?** Because muting prevents all watching. Volume Lock is the "I'll allow it, but on my terms" mode. Great for when they're watching something educational and you just don't want to hear it from three rooms away.

### 3) Restore TV

Unmutes the TV via CastV2 `SET_VOLUME` with `muted: false`. Simple, instant, one connection.

This also runs automatically when:
- Lock mode is interrupted with Ctrl+C
- You quit the script and the TV is still muted (it asks you first)

### 4) Whitelist Management

An interactive submenu for managing which apps are allowed to run during lock mode.

**The whitelist file (`whitelist.conf`):**
```
# boretube whitelist - one app per line: APP_ID|Friendly Name
E8C28D3C|Backdrop (Home Screen)
```

Format: `APP_ID|Friendly Name`. One per line. Comments with `#`.

**Default entry:** `E8C28D3C` is the Backdrop app (Home Screen / screensaver). It's the idle state of the TV. Removing it would cause lock mode to fight the TV's own idle screen, which would be absurd. The script prevents you from removing it.

**How to find app IDs:** Use option `(i)` in the whitelist menu — it queries the TV for the currently running app and shows you the ID. Open the app you want to whitelist on the TV, then identify it.

**Duplicate protection:** If you try to add an app ID that's already in the whitelist, it tells you. No duplicate entries.

### 5) Activity Log

All enforcement actions are logged to `boretube.log`:

```
[2026-02-24 23:47:31] LOCK started for 60 min (interval=10s)
[2026-02-24 23:47:31] STOPPED: YouTube (2C6A6E3D)
[2026-02-24 23:48:02] STOPPED: YouTube (2C6A6E3D)
[2026-02-24 23:49:03] STOPPED: MX Player (AndroidNativeApp)
[2026-02-24 23:49:44] STOPPED: Apple TV (AndroidNativeApp)
[2026-02-24 23:53:26] LOCK stopped by user, TV unmuted
```

You can see exactly when the kid tried to open what, and how many times. The log viewer in the menu shows the last 20 entries, color-coded: red for enforcement actions (`STOPPED`), dim for routine events.

### Real-time Status Panel

The main menu header isn't static — it queries the TV every time the menu draws, and **auto-refreshes every 10 seconds** even while waiting for your input (using `read -t 10`). You see:

- **Connection state:** `● Connected` (green), `● OFF or unreachable` (red)
- **Running app:** name + whitelist status (`whitelisted` / `not whitelisted`)
- **Volume bar:** 10-segment visual (`████░░░░░░ 40%`) with red `MUTED` indicator
- **Whitelist count** and **polling interval**
- **Last log entry** (red if it was an enforcement action)

---

## Project Structure

```
boretube/
├── boretube.sh          # Main tool — interactive menu + CLI + CastV2 engine
├── detect.sh            # Smart TV finder — scans subnets, saves to tv.conf
├── tv.conf              # TV connection details (generated by detect.sh)
├── whitelist.conf       # Allowed app IDs (one per line: ID|Name)
├── boretube.log         # Enforcement history (auto-created)
├── .venv/               # Python virtual environment
│   └── lib/python3.12/site-packages/
│       └── protobuf/    # Google Protocol Buffers (the only runtime dependency)
└── README.md            # You are here
```

### Why is everything in one file?

Portability. `boretube.sh` is a single bash script you can `scp` to any Linux machine. The Python code is embedded as a heredoc — no separate `.py` files to keep track of. The only external dependency is the `protobuf` pip package (and Python 3 itself).

### Why bash + embedded Python?

Bash handles the interactive menu, file I/O, process management (parallel DIAL kills, traps, signals), and terminal UI (colors, `clear`, `read -t`). Python handles the parts bash can't: TLS sockets, protobuf encoding/decoding, JSON parsing. The Python code runs as a short-lived subprocess for each CastV2 command — typically 0.5-1 second per invocation.

---

## Runtime Setup

### Prerequisites

- Linux (tested on Ubuntu with kernel 6.17)
- Python 3.12+
- `curl` (for DIAL protocol)
- `bash` 4+ (for `read -t`, `((...))`, process substitution)
- Network route to the TV's subnet (the TV must be IP-reachable from your machine)

### First-time setup

```bash
# Clone the repo
git clone git@github.com:javajack/boretube.git && cd boretube

# Create the Python virtual environment
python3 -m venv .venv

# Install the only runtime dependency
.venv/bin/pip install protobuf

# Find your TV
bash detect.sh

# Run it
bash boretube.sh
```

**Why a venv?** Debian/Ubuntu ships Python as `EXTERNALLY-MANAGED` (PEP 668). You can't `pip install` system-wide without `--break-system-packages`. A venv keeps things clean and avoids polluting the system Python.

**Note:** The venv also contains `pychromecast`, `zeroconf`, `casttube`, and `requests` from earlier experimentation. These are NOT used at runtime — only `protobuf` is imported. You could create a minimal venv with just `pip install protobuf` and everything would work.

### Configuration

**Option A: Auto-detect (recommended)**

```bash
bash detect.sh
```

`detect.sh` scans your local and upstream subnets for Cast devices, identifies them via DIAL, and saves the result to `tv.conf`. It tries multiple discovery methods:

1. **Local subnet scan** — finds your gateway, scans the /24 for Cast ports (8008 + 8009)
2. **Upstream router probing** — checks common gateway IPs (192.168.0.1, 192.168.1.1, 10.0.0.1, etc.) to find TVs on other subnets
3. **mDNS/Zeroconf** — uses `avahi-browse` if installed (only works same-subnet)
4. **SSDP/UPnP** — multicast M-SEARCH for DIAL devices (only works same-subnet)

If multiple Cast devices are found, it lets you pick. The result is saved to `tv.conf`:

```bash
TV_IP=192.168.1.3
TV_NAME=BRAVIA VU3
DIAL_PORT=8008
CAST_PORT=8009
```

`boretube.sh` automatically loads `tv.conf` on startup. No manual editing needed.

**Option B: Manual config**

Create `tv.conf` yourself:

```bash
cat > tv.conf << EOF
TV_IP=192.168.1.3
TV_NAME=My TV
DIAL_PORT=8008
CAST_PORT=8009
EOF
```

### Running

```bash
# Interactive menu (recommended)
bash boretube.sh

# CLI mode (for scripting / cron)
bash boretube.sh status          # JSON status dump
bash boretube.sh lock 30         # Lock for 30 minutes
bash boretube.sh mute            # Mute TV
bash boretube.sh unmute          # Unmute TV
bash boretube.sh volume 20       # Set volume to 20%
bash boretube.sh bore            # Kill app + mute (one-shot)
bash boretube.sh restore         # Unmute
bash boretube.sh whitelist       # List allowed apps
bash boretube.sh allow ID Name   # Add app to whitelist
bash boretube.sh deny ID         # Remove app from whitelist
bash boretube.sh log             # Show recent log entries
```

---

## Known Cast App IDs

These are the app IDs we've discovered through runtime observation and DIAL queries. Use these when adding apps to the whitelist:

| App ID | App Name |
|--------|----------|
| `E8C28D3C` | Backdrop (Home Screen) |
| `233637DE` | YouTube |
| `2C6A6E3D` | YouTube (alternate ID, seen on some TVs) |
| `544CC425` | YouTube Kids |
| `2DB7CC49` | YouTube Music |
| `2C6A6BBD` | YouTube TV |
| `CA5E8412` | Netflix |
| `C3DE6BC2` | Disney+ |
| `10AAD887` | Amazon Prime Video |
| `CC32E753` | Spotify |
| `AndroidNativeApp` | Native Android apps (MX Player, Apple TV, etc.) |

**Note on `AndroidNativeApp`:** Native Android apps (installed from the Play Store, not Cast-enabled web apps) all report the same generic ID. This means you can't whitelist "MX Player but not Apple TV" — they both show as `AndroidNativeApp`. If you whitelist this ID, ALL native apps are allowed.

---

## How It All Fits Together

Here's the full data flow for a single lock mode enforcement cycle:

```
┌─────────────────────────────────────────────────────────┐
│                    boretube.sh (bash)                     │
│                                                          │
│  main_menu() loop                                        │
│    └── action_lock() polling loop                        │
│          │                                               │
│          ├── cast_command "status"                        │
│          │     └── Python subprocess (heredoc)            │
│          │           ├── TCP connect 192.168.1.3:8009     │
│          │           ├── TLS handshake (self-signed)      │
│          │           ├── Send CONNECT (protobuf)          │
│          │           ├── Send GET_STATUS (protobuf+JSON)  │
│          │           ├── Read RECEIVER_STATUS response     │
│          │           ├── Extract JSON from protobuf        │
│          │           └── Print {"volume":15,"muted":false, │
│          │                      "app_id":"233637DE",       │
│          │                      "app_name":"YouTube",      │
│          │                      "idle":false}              │
│          │                                               │
│          ├── json_fields (Python one-liner)               │
│          │     └── Parse app_id, app_name, idle           │
│          │                                               │
│          ├── is_whitelisted "233637DE"                    │
│          │     └── grep whitelist.conf → NOT FOUND        │
│          │                                               │
│          ├── do_bore()  ← app is not whitelisted!         │
│          │     ├── cast_command "bore"                     │
│          │     │     └── Python subprocess                 │
│          │     │           ├── TCP+TLS to :8009            │
│          │     │           ├── CONNECT                     │
│          │     │           ├── STOP (req_id=1)             │
│          │     │           ├── sleep(0.3)                  │
│          │     │           └── SET_VOLUME muted (req_id=2) │
│          │     │                                          │
│          │     ├── curl DELETE :8008/apps/YouTube/run &    │
│          │     ├── curl DELETE :8008/apps/Netflix/run &    │
│          │     └── wait  (parallel DIAL kills)            │
│          │                                               │
│          ├── log_action "STOPPED: YouTube (233637DE)"     │
│          │     └── append to boretube.log                  │
│          │                                               │
│          └── sleep 10                                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Connection count per enforcement cycle:**
- Happy path (app is whitelisted): 1 CastV2 connection + 1 Python for json_fields = **2 processes**
- Enforcement path (app blocked): 1 CastV2 status + 1 CastV2 bore + 2 parallel DIAL curls + 1 Python for json_fields = **5 processes**

**Typical latency:**
- Status check: ~0.5s (TLS handshake + GET_STATUS + response)
- Bore (stop + mute): ~0.8s (TLS + STOP + 300ms pause + MUTE)
- DIAL kills: ~0.2s each (plain HTTP DELETE, run in parallel)
- Total enforcement cycle: ~1.5s active, then 10s sleep

**Memory footprint:** Each Python subprocess lives for <1 second and uses ~15MB (Python interpreter + protobuf). The bash script itself uses negligible memory. There are no long-running daemons or background processes between poll cycles.

---

## The Nerdy Details

### Why manual protobuf encoding?

We use `google.protobuf.internal.encoder._VarintBytes` and `google.protobuf.internal.decoder._DecodeVarint32` directly instead of generated protobuf classes. This is technically using internal APIs, but:

1. **No `.proto` file needed.** The CastMessage schema is simple enough to encode by hand.
2. **No code generation step.** No `protoc` compiler, no generated `_pb2.py` files.
3. **Self-contained.** The entire protocol implementation is 140 lines of Python inside a bash heredoc.
4. **These internals haven't changed** in protobuf since v3. They're as stable as "internal" APIs get.

### The response parsing problem

CastV2 responses are protobuf messages containing multiple string fields. The JSON payload we want is in field 6 (`payload_utf8`), but the protobuf wire format doesn't include field names — just field numbers and wire types. Our parser can't just "read field 6" without a schema.

**Solution:** We scan ALL length-delimited (wire type 2) fields in the response, try to JSON-parse each one, collect all valid JSON objects, and then prefer the one that contains a `'status'` or `'type'` key (which is the actual Cast response). This is robust against protobuf field reordering and handles responses from different TV firmware versions.

### Cross-subnet communication

mDNS and SSDP are link-local (multicast). They don't cross subnet boundaries. But **unicast TCP does**. As long as there's a route from `192.168.31.x` to `192.168.1.x` (which there is, because the MiWiFi router forwards traffic to the Hathway router), we can reach the TV directly by IP. The Cast protocols (DIAL over HTTP, CastV2 over TLS) are all unicast TCP, so they work fine across subnets.

### The `set -e` trap

Early versions used `set -euo pipefail`. The `-e` flag (exit on error) caused a subtle crash: `((count++))` evaluates to `((0))` when count is 0, which is falsy in bash arithmetic, which triggers `set -e` to exit the script. Fixed by removing `-e` and using `set -uo pipefail` instead. Lesson: `set -e` and bash arithmetic are frenemies.

### The 300ms pause in "bore"

When sending STOP followed by MUTE in the same CastV2 connection, the TV needs a brief moment to process the STOP before it can handle the MUTE. Without the pause, the MUTE sometimes gets silently dropped. 300ms was determined experimentally — 100ms was too short (occasional drops), 500ms worked but was unnecessarily slow.

---

*Built with raw sockets, reverse-engineered protocols, and parental desperation.*
