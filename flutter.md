# Boretube Flutter App — Complete Implementation Reference

This document captures everything needed to build a Flutter mobile app that replaces the current bash+python `boretube.sh` tool. It is self-contained — no prior context about the codebase is needed.

---

## Table of Contents

- [What is Boretube?](#what-is-boretube)
- [The Current Bash Implementation](#the-current-bash-implementation)
  - [Architecture Overview](#architecture-overview)
  - [CastV2 Protocol Engine (Port 8009)](#castv2-protocol-engine-port-8009)
  - [DIAL Protocol (Port 8008)](#dial-protocol-port-8008)
  - [Sony Bravia REST API (Port 80) — Planned](#sony-bravia-rest-api-port-80--planned)
  - [Lock Mode — The Core Feature](#lock-mode--the-core-feature)
  - [Volume Lock Mode](#volume-lock-mode)
  - [Whitelist System](#whitelist-system)
  - [Known Tricks and Quirks](#known-tricks-and-quirks)
  - [Known Cast App IDs](#known-cast-app-ids)
  - [TV Discovery (detect.sh)](#tv-discovery-detectsh)
- [Flutter Feasibility Analysis](#flutter-feasibility-analysis)
  - [1. Raw TCP/TLS Sockets in Dart](#1-raw-tcptls-sockets-in-dart)
  - [2. Protobuf Support in Dart](#2-protobuf-support-in-dart)
  - [3. HTTP Requests for DIAL Protocol](#3-http-requests-for-dial-protocol)
  - [4. Background Execution — The Critical Challenge](#4-background-execution--the-critical-challenge)
  - [5. Existing Dart Cast Libraries](#5-existing-dart-cast-libraries)
  - [6. Network Discovery in Flutter](#6-network-discovery-in-flutter)
  - [7. Platform-Specific Concerns](#7-platform-specific-concerns)
  - [8. UX Opportunities on Mobile](#8-ux-opportunities-on-mobile)
- [Recommended Architecture for Flutter App](#recommended-architecture-for-flutter-app)
  - [Project Structure](#project-structure)
  - [CastV2 Client Design](#castv2-client-design)
  - [DIAL Client Design](#dial-client-design)
  - [Background Service Design (Android)](#background-service-design-android)
  - [State Management](#state-management)
  - [Data Persistence](#data-persistence)
- [Implementation Priority](#implementation-priority)
- [Feasibility Summary Matrix](#feasibility-summary-matrix)
- [Open Questions](#open-questions)

---

## What is Boretube?

Boretube is a parental control tool for Sony Bravia Google TV. It controls the TV remotely over the network using reverse-engineered Cast protocols — no root, no ADB, no apps installed on the TV itself.

**The philosophy:** You can't block the TV. Instead, you make it so boring and frustrating that the kid walks away on their own. Apps close by themselves. Sound disappears. Volume goes back down. The kid thinks the TV is broken.

**Target TV:** Sony BRAVIA VU3 running Google TV, at IP `192.168.1.3` on a different subnet than the controlling device.

**Current implementation:** A single bash script (`boretube.sh`, 875 lines) with an embedded Python subprocess for CastV2 protocol handling, plus a discovery script (`detect.sh`, 428 lines).

**Why replace with Flutter?** The bash tool requires a laptop running a terminal session. A Flutter mobile app would:
- Run from a phone in your pocket
- Persist in the background as an Android foreground service
- Provide better UX (notifications, widgets, quick settings tiles)
- Eliminate the laptop dependency entirely

---

## The Current Bash Implementation

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│           boretube.sh (875 lines bash)           │
├─────────────────────────────────────────────────┤
│                                                  │
│  Interactive Menu (TUI)  OR  CLI Mode            │
│  ├── action_lock()         (whitelist enforce)   │
│  ├── action_volume_lock()  (volume cap)          │
│  ├── do_bore()             (kill + mute combo)   │
│  ├── do_restore()          (unmute)              │
│  └── action_whitelist()    (manage allowed apps) │
│                                                  │
│  Each action calls cast_command() which spawns:  │
│                                                  │
│  Python subprocess (heredoc, lines 94-232)       │
│  ├── TCP socket to TV_IP:8009                    │
│  ├── TLS handshake (self-signed cert, no verify) │
│  ├── Protobuf message encoding (manual varint)   │
│  ├── JSON payload injection into protobuf        │
│  └── Protobuf response parsing → JSON stdout     │
│                                                  │
│  + curl subprocesses for DIAL (parallel, bg)     │
│                                                  │
└─────────────────────────────────────────────────┘
                      │
                      ▼ Network (unicast TCP, works cross-subnet)
                      │
        ┌─────────────────────────────────┐
        │  Sony BRAVIA VU3 (Google TV)    │
        │  IP: 192.168.1.3               │
        ├─────────────────────────────────┤
        │  Port 8008: DIAL (HTTP)         │
        │  Port 8009: CastV2 (TLS)       │
        │  Port 80:   REST API (disabled) │
        └─────────────────────────────────┘
```

### CastV2 Protocol Engine (Port 8009)

This is the primary control protocol. It runs over TLS on port 8009 and uses Protocol Buffers for message framing with JSON payloads inside.

#### Wire Format

Every CastV2 message on the wire is:
```
[4 bytes: message length, big-endian uint32] [protobuf-encoded CastMessage]
```

#### CastMessage Protobuf Schema

```protobuf
// From Chromium source, reverse-engineered
message CastMessage {
  required int32  protocol_version = 1;  // always 0 (CASTV2_1_0)
  required string source_id       = 2;   // always "sender-0"
  required string destination_id  = 3;   // always "receiver-0"
  required string namespace       = 4;   // see namespaces below
  required int32  payload_type    = 5;   // always 0 (STRING)
  optional string payload_utf8    = 6;   // JSON command/response
}
```

The `.proto` file for CastV2 is publicly available as `cast_channel.proto` in the Chromium source. For Flutter, you can compile it with `protoc` + `protoc_plugin` for Dart to get type-safe generated classes.

#### Namespaces

| Namespace | Purpose |
|-----------|---------|
| `urn:x-cast:com.google.cast.tp.connection` | Virtual connection setup (CONNECT message) |
| `urn:x-cast:com.google.cast.receiver` | All control commands (status, volume, stop) |

#### Connection Lifecycle

1. Open TCP socket to `TV_IP:8009`
2. Wrap in TLS — **must accept self-signed certificates** (TV uses self-signed)
3. Send `CONNECT` message on the connection namespace (no response expected)
4. Send command(s) on the receiver namespace
5. Read response(s) — may need to skip non-`RECEIVER_STATUS` messages
6. Close connection

#### JSON Commands (sent inside protobuf field 6)

**CONNECT** (must be first, on connection namespace):
```json
{"type": "CONNECT"}
```

**GET_STATUS** (on receiver namespace):
```json
{"type": "GET_STATUS", "requestId": 1}
```

**Response** (RECEIVER_STATUS):
```json
{
  "type": "RECEIVER_STATUS",
  "requestId": 1,
  "status": {
    "volume": {
      "level": 0.15,
      "muted": false,
      "controlType": "attenuation",
      "stepInterval": 0.01
    },
    "applications": [{
      "appId": "233637DE",
      "displayName": "YouTube",
      "isIdleScreen": false,
      "statusText": "",
      "transportId": "..."
    }]
  }
}
```

**Key fields in the response:**
- `status.volume.level` — float 0.0 to 1.0 (multiply by 100 for percentage)
- `status.volume.muted` — boolean
- `status.applications[0].appId` — hex string identifying the app
- `status.applications[0].displayName` — human-readable app name
- `status.applications[0].isIdleScreen` — true when TV is on home/screensaver

**STOP** (kill current app):
```json
{"type": "STOP", "requestId": 1}
```

**SET_VOLUME** (mute):
```json
{"type": "SET_VOLUME", "volume": {"muted": true}, "requestId": 1}
```

**SET_VOLUME** (unmute):
```json
{"type": "SET_VOLUME", "volume": {"muted": false}, "requestId": 1}
```

**SET_VOLUME** (set level, 0.0-1.0):
```json
{"type": "SET_VOLUME", "volume": {"level": 0.15}, "requestId": 1}
```

#### Current Python Implementation (Lines 94-232 of boretube.sh)

The Python code is embedded as a heredoc and spawned as a subprocess. Key implementation details:

**Protobuf encoding** (manual, no .proto compilation):
```python
from google.protobuf.internal.encoder import _VarintBytes
from google.protobuf.internal.decoder import _DecodeVarint32

def encode_string(field_number, value):
    tag = (field_number << 3) | 2  # wire type 2 = length-delimited
    encoded = value.encode('utf-8')
    return _VarintBytes(tag) + _VarintBytes(len(encoded)) + encoded

def encode_varint(field_number, value):
    return _VarintBytes((field_number << 3) | 0) + _VarintBytes(value)

def build_msg(namespace, payload, src="sender-0", dst="receiver-0"):
    msg = encode_varint(1, 0)          # protocol_version = 0
    msg += encode_string(2, src)       # source_id
    msg += encode_string(3, dst)       # destination_id
    msg += encode_string(4, namespace) # namespace
    msg += encode_varint(5, 0)         # payload_type = 0 (STRING)
    msg += encode_string(6, payload)   # payload_utf8 = JSON
    return struct.pack('>I', len(msg)) + msg  # 4-byte big-endian length prefix
```

**TLS setup** (self-signed cert acceptance):
```python
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
sock = socket.create_connection((TV_IP, CAST_PORT), timeout=5)
ssock = ctx.wrap_socket(sock, server_hostname=TV_IP)
```

**Response parsing** — This is the trickiest part. The response is protobuf but we parse it without a schema:
1. Scan all bytes for wire type 2 (length-delimited) fields
2. Try to decode each as UTF-8 string
3. Try to JSON-parse each string
4. Collect all valid JSON objects
5. Prefer the one with `'status'` or `'type'` key (the actual Cast response)
6. Return it

This approach is robust against protobuf field reordering and handles responses from different TV firmware versions. **In Flutter, if you compile `cast_channel.proto`, you won't need this hack — the generated class will extract `payload_utf8` directly by field number.**

**Timeouts:**
- Connection timeout: 5 seconds
- Receive timeout: 3 seconds
- Status read: tries up to 5 messages to find a `RECEIVER_STATUS` (skipping CONNECT ack etc.)

**Error handling:** On any failure, outputs `{"_error": "..."}` JSON so the bash caller can detect errors via string matching.

### DIAL Protocol (Port 8008)

DIAL (Discovery and Launch) is a simple HTTP protocol on port 8008. No authentication, no encryption, plain HTTP.

**Used for belt-and-suspenders app killing alongside CastV2:**

```
GET  http://192.168.1.3:8008/apps/YouTube       → XML with <state>running</state>
POST http://192.168.1.3:8008/apps/YouTube        → Launch app
DELETE http://192.168.1.3:8008/apps/YouTube/run   → Kill running app
```

**Current usage in `do_bore()`** (lines 278-289):
- After CastV2 STOP+MUTE, also fire DIAL DELETE for YouTube and Netflix in parallel background processes
- This provides redundancy: CastV2 STOP kills whatever app is running (by generic STOP), DIAL DELETE targets specific apps by name
- DIAL kills run in parallel (`&` backgrounded, then `wait`)
- Uses `timeout 2 curl -s -o /dev/null -X DELETE` for each

**Limitations of DIAL:**
- Can only target apps by exact DIAL name (YouTube, Netflix — not all apps register with DIAL)
- Cannot control volume, mute, or query what's currently running generically
- No way to get a list of ALL running apps
- Only useful as supplementary kill mechanism

**Device description endpoint** (used by detect.sh):
```
GET http://192.168.1.3:8008/ssdp/device-desc.xml
→ XML with <friendlyName>BRAVIA VU3</friendlyName>
            <manufacturer>Sony</manufacturer>
            <modelName>BRAVIA VU3</modelName>
```

### Sony Bravia REST API (Port 80) — Planned

Sony Bravia TVs expose a JSON-RPC REST API on port 80 for power control and other features that CastV2/DIAL can't do. This is **not yet implemented** because port 80 needs to be enabled on the TV side.

**TV Setup Required:**
1. Settings > Network & Internet > Home Network > IP Control
2. Set Authentication to "Normal and Pre-Shared Key"
3. Set a Pre-Shared Key (e.g. `1234`)

**API calls** (JSON-RPC 2.0):
```bash
# Power off
curl -X POST "http://192.168.1.3/sony/system" \
  -H "Content-Type: application/json" \
  -H "X-Auth-PSK: 1234" \
  -d '{"method":"setPowerStatus","params":[{"status":false}],"id":1,"version":"1.0"}'

# Power on
curl -X POST "http://192.168.1.3/sony/system" \
  -H "X-Auth-PSK: 1234" \
  -d '{"method":"setPowerStatus","params":[{"status":true}],"id":1,"version":"1.0"}'

# Check power status
curl -X POST "http://192.168.1.3/sony/system" \
  -d '{"method":"getPowerStatus","params":[],"id":1,"version":"1.0"}'
```

**For Flutter:** Implement this as a simple HTTP POST with `X-Auth-PSK` header. Store PSK in app settings alongside TV IP. This would unlock:
- Power off TV (nuclear option for lock mode)
- Input switching
- Remote control emulation

### Lock Mode — The Core Feature

Lock mode is a polling loop that enforces a whitelist every 10 seconds for a configurable duration.

**Algorithm** (lines 459-506):
```
1. User picks duration (default 60 minutes)
2. Load whitelist IDs into memory cache
3. Loop until timer expires or Ctrl+C:
   a. GET_STATUS via CastV2
   b. If TV unreachable → log "TV off/standby", sleep 10s, continue
   c. If app is idle (home screen) → log, sleep 10s, continue
   d. If app_id is in whitelist → log "whitelisted", sleep 10s, continue
   e. If app is NOT whitelisted:
      - do_bore():
        - CastV2 STOP + MUTE in single connection (300ms pause between)
        - DIAL DELETE YouTube (background)
        - DIAL DELETE Netflix (background)
      - Log "STOPPED: {app_name} ({app_id})"
   f. Sleep 10 seconds
4. On exit: unmute TV (cleanup via signal trap)
```

**Why 10 seconds?** Sweet spot. <5s overwhelms the TV. >30s gives kid too much time. Effective cycle is ~12-13 seconds (10s sleep + 2-3s for check+enforce). Kid gets at most ~13 seconds of a blocked app.

**Why mute alongside stop?** Stopping alone isn't enough — kid just reopens the app. Muting makes even re-opened apps give a silent screen. They give up faster.

**Signal handling:**
- `SIGINT` (Ctrl+C), `SIGTERM`, `SIGQUIT`, `SIGHUP` → cleanup: unmute TV, log, exit
- `SIGTSTP` (Ctrl+Z) → blocked entirely (suspending would leave TV in bad state)
- On TV unreachable during cleanup → skip unmute gracefully

### Volume Lock Mode

Similar polling loop but caps volume instead of killing apps. Kid can watch, but not at earthquake levels.

**Algorithm** (lines 542-581):
```
1. User picks max volume % (default 15%) and duration (default 60 minutes)
2. Loop until timer expires or Ctrl+C:
   a. GET_STATUS via CastV2
   b. If TV unreachable → log, sleep 10s, continue
   c. If volume > max → SET_VOLUME to max, log "vol 45% → 15%"
   d. If volume <= max → log "vol ok"
   e. Sleep 10 seconds
```

Kid turns volume up with remote, within 10 seconds it gets pushed back down. They learn the volume fairy doesn't want them going above 15%.

### Whitelist System

**File:** `whitelist.conf`
```
# boretube whitelist - one app per line: APP_ID|Friendly Name
# Only these apps are allowed to run. Everything else gets killed.
E8C28D3C|Backdrop (Home Screen)
```

**Format:** `APP_ID|Friendly Name`, one per line. Lines starting with `#` are comments.

**Default entry:** `E8C28D3C` (Backdrop / Home Screen) is the idle state. Cannot be removed — removing it would cause lock mode to fight the TV's own idle screen.

**Whitelist management** (interactive submenu):
- Add app by ID + name
- Remove app by ID (except Backdrop)
- Identify current app (queries TV, shows app_id for easy whitelisting)
- Duplicate protection (can't add same ID twice)

**Performance optimization:** During lock/volume-lock loops, the whitelist is cached in memory (`_WL_CACHE` variable) to avoid re-reading the file every 10 seconds. Cache is loaded at loop start and cleared at loop end.

### Known Tricks and Quirks

1. **The "bore" action combines STOP + MUTE in a single TLS connection.** Two separate connections would mean two TLS handshakes (~1s each). The combined action sends STOP, waits 300ms, then sends MUTE on the same socket. Total: ~0.5s instead of ~2s. The 300ms pause was experimentally determined — 100ms was too short (MUTE gets silently dropped), 500ms was unnecessarily slow.

2. **JSON parsing without Python.** The bash script has a `json_val()` function (line 243) that extracts values from the flat JSON using `grep -oP` regex. This avoids spawning a Python subprocess just for JSON parsing — significant performance saving in the polling loop. The Flutter app won't need this (Dart has `dart:convert`).

3. **Response parsing scans ALL protobuf string fields.** The CastV2 response contains multiple protobuf string fields. Without a compiled schema, the Python parser can't just read field 6. Instead it tries JSON-parsing every string field and picks the one with `'status'` or `'type'` key. Compiled `.proto` in Flutter eliminates this.

4. **DIAL kills run in parallel.** `do_bore()` fires YouTube and Netflix DIAL DELETE requests as background processes (`&`) and then `wait`s for all of them. This means DIAL failures don't block the main flow.

5. **Menu auto-refreshes.** `read -rp "Choose [1-5, q]: " -t 10 choice` — the `-t 10` timeout means the menu redraws every 10 seconds with fresh TV status even if the user doesn't press anything. Ctrl+D (EOF) detection distinguishes timeout from pipe close.

6. **The `set -e` trap.** Early versions used `set -euo pipefail`. The `-e` flag caused `((count++))` to kill the script when count was 0 (bash evaluates `((0))` as false → exit). Fixed by removing `-e`.

7. **Cross-subnet works because everything is unicast TCP.** mDNS (multicast) doesn't cross subnets, but direct TCP connections to a known IP do. The laptop is on `192.168.31.x`, TV is on `192.168.1.x` — routed through the upstream router.

8. **Sanity check on message length.** Response parser rejects messages >65536 bytes to prevent buffer issues from malformed responses.

9. **Quit asks about muting state.** When user quits, the script checks if TV is currently muted (queries via CastV2) and offers to unmute before exiting. If TV is unreachable, skips gracefully.

10. **`AndroidNativeApp` is a catch-all ID.** Native Android apps (MX Player, Apple TV, etc. installed from Play Store) all report the same generic `AndroidNativeApp` ID. You can't whitelist one native app but block another — they all share this ID.

### Known Cast App IDs

| App ID | App Name | Notes |
|--------|----------|-------|
| `E8C28D3C` | Backdrop (Home Screen) | Default idle state, always in whitelist |
| `233637DE` | YouTube | Primary video app |
| `2C6A6E3D` | YouTube | Alternate ID (seen on some TV firmware versions) |
| `544CC425` | YouTube Kids | |
| `2DB7CC49` | YouTube Music | |
| `2C6A6BBD` | YouTube TV | |
| `CA5E8412` | Netflix | |
| `C3DE6BC2` | Disney+ | |
| `10AAD887` | Amazon Prime Video | |
| `CC32E753` | Spotify | |
| `AndroidNativeApp` | Native Android apps | Generic ID for MX Player, Apple TV, etc. — cannot distinguish between them |

### TV Discovery (detect.sh)

The discovery script (428 lines) finds Cast-enabled TVs on the network using multiple methods:

1. **Local interface detection** — reads gateway IP from `ip route`, extracts subnet
2. **Upstream router probing** — pings common gateway IPs (`192.168.0.1`, `192.168.1.1`, `10.0.0.1`, etc.) to find TVs on other subnets
3. **TCP port scan** — scans all IPs (1-254) on discovered subnets for ports 8008 + 8009 open (max 50 parallel probes)
4. **DIAL identification** — fetches `http://{ip}:8008/ssdp/device-desc.xml` to get friendly name, manufacturer, model
5. **mDNS** (optional) — `avahi-browse -rpt _googlecast._tcp` (only works same-subnet)
6. **SSDP** (optional) — multicast M-SEARCH for DIAL devices (only works same-subnet)

If multiple devices found, user picks. Result saved to `tv.conf`:
```bash
TV_IP=192.168.1.3
TV_NAME="BRAVIA VU3"
DIAL_PORT=8008
CAST_PORT=8009
```

**For Flutter:** The phone is likely on the same subnet as the TV (connected to the same WiFi router), so mDNS discovery would actually work. But also support manual IP entry for cross-subnet setups.

---

## Flutter Feasibility Analysis

### 1. Raw TCP/TLS Sockets in Dart

**Verdict: FULLY FEASIBLE**

Dart's `dart:io` provides everything needed:

```dart
// Equivalent of Python's socket.create_connection + ssl.wrap_socket
final socket = await SecureSocket.connect(
  tvIp,
  8009,
  timeout: Duration(seconds: 5),
  onBadCertificate: (_) => true,  // Accept self-signed certs
);

// Send bytes
socket.add(messageBytes);

// Receive bytes
socket.listen((data) {
  // Process protobuf response
});

// Or for simple request/response:
await socket.flush();
// Read from socket...
socket.destroy();
```

**Key classes:**
- `Socket.connect(host, port)` — raw TCP
- `SecureSocket.connect(host, port)` — TLS in one step
- `SecureSocket.secure(socket)` — wrap existing socket in TLS
- `onBadCertificate: (cert) => true` — accept self-signed (equivalent to Python's `ctx.verify_mode = ssl.CERT_NONE`)

**Platform restrictions:** None. Raw TCP/TLS sockets work on both Android and iOS with no special permissions for outbound connections. Flutter's cleartext HTTP restrictions (ATS on iOS, Network Security Config on Android) only apply to the HTTP client layer, **not raw sockets**.

**Timeouts:** `Socket.connect()` accepts a `timeout` parameter. For read timeouts, use `stream.timeout(Duration(seconds: 3))` or `Future.timeout()`.

### 2. Protobuf Support in Dart

**Verdict: FULLY FEASIBLE**

**Recommended approach: Compile `cast_channel.proto`**

Google provides an official Dart protobuf ecosystem:
- [`protobuf`](https://pub.dev/packages/protobuf) (v4.x) — Dart protobuf runtime (Google-maintained, actively updated)
- [`protoc_plugin`](https://pub.dev/packages/protoc_plugin) — Dart code generator for `protoc` compiler

Steps:
1. Get `cast_channel.proto` from Chromium source
2. Run `protoc --dart_out=. cast_channel.proto`
3. Get generated `cast_channel.pb.dart` with typed `CastMessage` class
4. Use it:

```dart
import 'cast_channel.pb.dart';

CastMessage buildMessage(String namespace, String payload) {
  return CastMessage()
    ..protocolVersion = CastMessage_ProtocolVersion.CASTV2_1_0
    ..sourceId = 'sender-0'
    ..destinationId = 'receiver-0'
    ..namespace = namespace
    ..payloadType = CastMessage_PayloadType.STRING
    ..payloadUtf8 = payload;
}

// Encode to bytes:
final msgBytes = msg.writeToBuffer();
// Add 4-byte big-endian length prefix:
final lengthPrefix = ByteData(4)..setUint32(0, msgBytes.length, Endian.big);
socket.add(lengthPrefix.buffer.asUint8List());
socket.add(msgBytes);

// Decode response:
final response = CastMessage.fromBuffer(responseBytes);
final json = jsonDecode(response.payloadUtf8);
```

This is **much cleaner** than the current Python approach of manual varint encoding. The generated class handles field encoding/decoding automatically, and `response.payloadUtf8` gives you the JSON payload directly (no need for the current hack of scanning all string fields).

**Alternative: Manual varint encoding** (if you want to avoid protoc toolchain)
- The [`varint`](https://pub.dev/packages/varint) package provides varint encode/decode
- Or use `CodedBufferWriter`/`CodedBufferReader` from the `protobuf` package runtime
- Dart's `ByteData.setUint32(0, length, Endian.big)` handles the 4-byte length prefix
- Would be a direct port of the current Python code

### 3. HTTP Requests for DIAL Protocol

**Verdict: FEASIBLE with one-time platform config**

Dart's `http` package or `dart:io`'s `HttpClient` fully supports plain HTTP:

```dart
import 'package:http/http.dart' as http;

// Kill YouTube via DIAL
await http.delete(Uri.parse('http://$tvIp:8008/apps/YouTube/run'));

// Kill Netflix via DIAL
await http.delete(Uri.parse('http://$tvIp:8008/apps/Netflix/run'));

// Can run in parallel:
await Future.wait([
  http.delete(Uri.parse('http://$tvIp:8008/apps/YouTube/run')),
  http.delete(Uri.parse('http://$tvIp:8008/apps/Netflix/run')),
]);

// Get device description
final response = await http.get(Uri.parse('http://$tvIp:8008/ssdp/device-desc.xml'));
// Parse XML for friendlyName, manufacturer, modelName
```

**Platform configuration required:**

**Android** (cleartext HTTP blocked since Android 9):
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<application android:usesCleartextTraffic="true" ...>
```
Or for more targeted approach, create `android/app/src/main/res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">192.168.1.3</domain>
    </domain-config>
</network-security-config>
```
And reference it in the manifest:
```xml
<application android:networkSecurityConfig="@xml/network_security_config" ...>
```

**iOS** (App Transport Security):
Add to `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```
`NSAllowsLocalNetworking` (iOS 10+) specifically allows cleartext for LAN addresses without globally disabling ATS.

### 4. Background Execution — The Critical Challenge

This is the **make-or-break** question. Lock mode and volume lock require 10-second polling indefinitely in the background.

#### Android: FULLY FEASIBLE via Foreground Service

**Package:** [`flutter_background_service`](https://pub.dev/packages/flutter_background_service) (v5.1.0, Dec 2024, actively maintained)

**Alternative:** [`flutter_foreground_task`](https://pub.dev/packages/flutter_foreground_task) — similar functionality, also actively maintained.

**How it works:**
- Runs a Dart isolate as an Android foreground service
- `Timer.periodic(Duration(seconds: 10), callback)` inside the service for polling
- Survives: app backgrounded, screen off, app removed from recents (with config)
- Requires a **persistent notification** (mandatory by Android for foreground services) — this actually aligns perfectly with our UX: "Lock Active: 45 min remaining"

**Configuration required:**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<!-- Android 14+ requires specifying foreground service type -->
<service
    android:name="..."
    android:foregroundServiceType="connectedDevice"/>
```

**Battery considerations:**
- 10-second polling with TLS handshakes is non-trivial battery drain
- **Key optimization: keep TLS socket open between polls** instead of reconnecting every 10s. The current bash script creates a new TLS connection every cycle (because it spawns a new Python subprocess). A Flutter app can maintain a persistent `SecureSocket` connection and reuse it, saving ~0.5s and CPU per cycle
- Consider adaptive intervals: 10s when screen on, 30s when screen off (user-configurable)
- WiFi Lock: some devices drop WiFi when screen is off. Use `WifiLock` to keep WiFi radio active during lock mode

**OEM battery optimization quirks:**
Xiaomi (MIUI), Samsung (One UI), Huawei (EMUI), Oppo (ColorOS) aggressively kill background apps. Users on these devices may need to:
- Disable battery optimization for the app
- Add to "allowed to run in background" list
- This is a common pain point for all foreground service apps, not specific to boretube

**Android Doze mode:** Foreground services are **exempt** from Doze restrictions. Polling will continue even in Doze mode.

#### iOS: NOT FEASIBLE for background polling

**The hard truth:** iOS suspends apps within seconds of going to background. There is **no API** to run persistent 10-second background polling. This is a platform design decision, not a Flutter limitation.

- `flutter_background_service` on iOS uses Background Fetch — OS-controlled, minimum ~15 minute intervals, 15-30 second execution windows. Completely inadequate for 10-second polling.
- No workaround passes App Store review (silent audio trick, VoIP push abuse, location background mode abuse all violate guidelines and will get rejected).

**What iOS CAN do:**
- Foreground-only remote control: user opens app, taps "Kill App" or "Mute", controls TV while app is on screen
- "Kiosk mode": if the phone is a dedicated wall-mounted controller, use `wakelock` to prevent screen dimming and keep app in foreground
- Push notification trigger from a separate server (adds cloud infra and latency)

**Recommendation:** Build Android-first. iOS is a stretch goal as a foreground-only "remote control" variant (no lock mode, no volume lock).

### 5. Existing Dart Cast Libraries

| Package | Version | Updated | Status |
|---------|---------|---------|--------|
| [`cast`](https://pub.dev/packages/cast) | 2.1.0 | Aug 2024 | Semi-maintained. Implements CastV2 in pure Dart with `SecureSocket`. 94 likes. |
| [`dart_chromecast`](https://pub.dev/packages/dart_chromecast) | 0.3.3 | Jan 2022 | Abandoned. Port of `node-castv2-client`. |
| [`flutter_chrome_cast`](https://pub.dev/packages/flutter_chrome_cast) | Recent | 2024 | Uses native Google Cast SDK (NOT raw CastV2 — requires app registration with Google) |
| [`flutter_cast_framework_v2`](https://pub.dev/packages/flutter_cast_framework_v2) | | 2024 | Same as above — native SDK wrapper |

**Analysis:**
- `cast` package is the closest to what we need — pure Dart CastV2 with `SecureSocket` + `onBadCertificate`. Good **reference code** for the socket handling pattern.
- `dart_chromecast` is abandoned but its source shows the full CastV2 Dart pattern.
- `flutter_chrome_cast` and `flutter_cast_framework_v2` use Google's native Cast SDK which requires sender app registration with Google. **NOT suitable** — our app sends raw CastV2 commands without being a registered Cast sender.

**Recommendation:** Write a custom CastV2 client (~200 lines Dart). Our usage is simple (4 commands: CONNECT, GET_STATUS, SET_VOLUME, STOP). Avoids dependency on semi-maintained packages. Use `cast` package source code as reference for the `SecureSocket` + protobuf pattern.

### 6. Network Discovery in Flutter

**mDNS packages:**
- [`nsd`](https://pub.dev/packages/nsd) (v1.5.6) — Native NSD/DNS-SD/Bonjour. Android, iOS, macOS, Windows. Actively maintained.
- [`bonsoir`](https://pub.dev/packages/bonsoir) — Cross-platform mDNS. Used by the `cast` package.

Chromecast/Android TV devices advertise via mDNS as `_googlecast._tcp`.

**Manual IP entry:**
Trivial in Flutter — `TextField` + `SharedPreferences` to persist. No discovery needed.

**Cross-subnet:**
mDNS (multicast) does NOT work across subnets. But the phone is typically on the same WiFi as the TV, so mDNS should work. For cross-subnet setups (like the current laptop setup), manual IP entry is the fallback.

**Subnet scanning** (replicating detect.sh's TCP port scan):
- Dart `Socket.connect()` with short timeouts can probe IP ranges
- But scanning 254 IPs sequentially is slow. Would need `Future.wait()` for parallel probes
- Less important on mobile since phone is usually on same subnet as TV

**Recommendation:** Primary = manual IP entry (simplest, works everywhere). Secondary = mDNS scan button for convenient same-subnet discovery.

### 7. Platform-Specific Concerns

#### Android

| Concern | Detail | Mitigation |
|---------|--------|------------|
| WiFi Lock | Some devices drop WiFi when screen off | Acquire `WifiManager.WifiLock` via method channel or `flutter_background` package |
| Wake Lock | CPU may sleep during background polling | Handled by `flutter_background_service` foreground service |
| Doze mode | Suspends network and wake locks | Foreground services are **exempt** from Doze |
| OEM battery optimization | Xiaomi/Samsung/Huawei kill background apps | Show user instructions to whitelist the app. Common for all background service apps |
| Cleartext HTTP | Blocked since Android 9 for HTTP client | `android:usesCleartextTraffic="true"` or network security config |
| Android 14+ foreground service type | Must declare `foregroundServiceType` | Use `connectedDevice` type |

#### iOS

| Concern | Detail | Mitigation |
|---------|--------|------------|
| Local Network Permission | iOS 14+ requires user consent for LAN access | Declare `NSLocalNetworkUsageDescription` in Info.plist. User sees one-time prompt |
| App Transport Security | Blocks cleartext HTTP | `NSAllowsLocalNetworking = true` in Info.plist |
| Background execution | iOS kills background apps in seconds | **No mitigation.** Lock mode is foreground-only on iOS |
| Bonjour declaration | Required if using mDNS | Add `NSBonjourServices` with `_googlecast._tcp` to Info.plist |

#### Battery Impact

Current bash script: Creates new TLS connection + Python subprocess each 10-second cycle (~15MB memory per subprocess, ~0.5s CPU).

Flutter app optimization opportunities:
- **Persistent TLS connection** — keep `SecureSocket` open between polls. Eliminates repeated TLS handshakes (most expensive part)
- **No subprocess overhead** — Dart isolate runs continuously, no process spawn/tear-down
- **Adaptive polling** — 10s in foreground, 20-30s in background (configurable)
- **Estimated battery drain:** Moderate with persistent connection. Heavy without (TLS handshake every 10s). Should be comparable to a music streaming app keeping a connection alive.

### 8. UX Opportunities on Mobile

#### Persistent Notification (Android Foreground Service)
Required by Android for foreground services. Can show:
- "Lock Active — 42 min remaining"
- "Last action: Stopped YouTube 30s ago"
- Action buttons: "Stop Lock", "Extend 30 min"
- Tapping opens the full app

#### Quick Settings Tile (Android)
- [`quick_settings`](https://github.com/Apparence-io/quick_settings) Flutter plugin
- One-tap toggle from notification shade to start/stop lock mode
- Supported since Android 7.0 (API 24)
- Android 13+ can prompt user to add the tile

#### Home Screen Widget
- [`home_widget`](https://pub.dev/packages/home_widget) package (Google-endorsed)
- Show: lock status, time remaining, current app on TV, volume
- **Caveat:** Widget rendering is native code (Kotlin on Android, SwiftUI on iOS). Flutter provides data bridge only.

#### Other UX Ideas
- Haptic feedback on kill/mute actions
- Lock mode countdown timer with circular progress
- Multiple TV profiles (just multiple saved IPs + names)
- Quick presets: "Bore" button, "Homework Mode" (lock + volume cap), "Bedtime" (lock + power off via REST API)
- Activity log with pull-to-refresh
- Schedule lock modes (e.g., auto-lock YouTube 4pm-7pm daily)

---

## Recommended Architecture for Flutter App

### Project Structure

```
boretube_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # MaterialApp + routing
│   │
│   ├── protocols/
│   │   ├── castv2_client.dart       # CastV2 TLS + protobuf client
│   │   ├── dial_client.dart         # DIAL HTTP client
│   │   └── bravia_rest_client.dart  # Sony REST API (future)
│   │
│   ├── proto/
│   │   └── cast_channel.pb.dart     # Generated from cast_channel.proto
│   │
│   ├── models/
│   │   ├── tv_status.dart           # Volume, muted, app_id, app_name, idle
│   │   ├── tv_config.dart           # IP, name, ports, PSK
│   │   └── whitelist_entry.dart     # App ID + friendly name
│   │
│   ├── services/
│   │   ├── tv_service.dart          # High-level TV operations (status, bore, restore, etc.)
│   │   ├── lock_service.dart        # Lock mode polling logic
│   │   ├── volume_lock_service.dart # Volume lock polling logic
│   │   └── background_service.dart  # Android foreground service setup
│   │
│   ├── screens/
│   │   ├── home_screen.dart         # Main dashboard (status panel + action buttons)
│   │   ├── lock_screen.dart         # Active lock mode view (countdown + live log)
│   │   ├── whitelist_screen.dart    # Whitelist management
│   │   ├── log_screen.dart          # Activity log viewer
│   │   └── settings_screen.dart     # TV config, polling interval, etc.
│   │
│   └── widgets/
│       ├── volume_bar.dart          # Visual volume bar (like the bash TUI one)
│       ├── status_indicator.dart    # Connected/disconnected indicator
│       └── app_tile.dart            # Whitelist app entry
│
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml      # Foreground service, wake lock, cleartext
│       └── res/xml/
│           └── network_security_config.xml
│
├── ios/
│   └── Runner/
│       └── Info.plist               # NSAllowsLocalNetworking, NSLocalNetworkUsageDescription
│
├── proto/
│   └── cast_channel.proto           # CastV2 protobuf schema (from Chromium)
│
└── pubspec.yaml
```

### CastV2 Client Design

```dart
// Pseudocode — key design decisions

class CastV2Client {
  SecureSocket? _socket;
  final String tvIp;
  final int tvPort;

  // Maintain persistent connection for performance
  Future<void> connect() async {
    _socket = await SecureSocket.connect(
      tvIp, tvPort,
      timeout: Duration(seconds: 5),
      onBadCertificate: (_) => true,  // Self-signed cert
    );
    // Send CONNECT on connection namespace
    _send('urn:x-cast:com.google.cast.tp.connection', '{"type":"CONNECT"}');
  }

  // Reuse connection if alive, reconnect if dead
  Future<TvStatus> getStatus() async {
    await _ensureConnected();
    _send(_receiverNs, '{"type":"GET_STATUS","requestId":${_nextReqId()}}');
    final response = await _readResponse();
    return TvStatus.fromJson(response);
  }

  Future<void> stop() async {
    await _ensureConnected();
    _send(_receiverNs, '{"type":"STOP","requestId":${_nextReqId()}}');
  }

  Future<void> setVolume({double? level, bool? muted}) async {
    await _ensureConnected();
    final vol = <String, dynamic>{};
    if (level != null) vol['level'] = level;
    if (muted != null) vol['muted'] = muted;
    _send(_receiverNs, jsonEncode({
      'type': 'SET_VOLUME', 'volume': vol, 'requestId': _nextReqId(),
    }));
  }

  // The "bore" combo: STOP + wait 300ms + MUTE (single connection)
  Future<void> bore() async {
    await _ensureConnected();
    _send(_receiverNs, '{"type":"STOP","requestId":${_nextReqId()}}');
    await Future.delayed(Duration(milliseconds: 300));
    _send(_receiverNs, jsonEncode({
      'type': 'SET_VOLUME', 'volume': {'muted': true}, 'requestId': _nextReqId(),
    }));
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
  }
}
```

**Key design decisions:**
- **Persistent connection** — unlike the bash script, keep the TLS socket open between polls. Massive performance/battery win.
- **Auto-reconnect** — `_ensureConnected()` checks if socket is alive and reconnects if needed (TV rebooted, network blip, etc.)
- **Request ID counter** — increment per command, like the bash script
- **300ms pause in bore()** — must preserve this timing. TV needs it to process STOP before MUTE.

### DIAL Client Design

```dart
class DialClient {
  final String tvIp;
  final int dialPort;

  // Kill specific apps (belt-and-suspenders alongside CastV2)
  Future<void> killApps() async {
    await Future.wait([
      http.delete(Uri.parse('http://$tvIp:$dialPort/apps/YouTube/run'))
          .timeout(Duration(seconds: 2))
          .catchError((_) => http.Response('', 500)),
      http.delete(Uri.parse('http://$tvIp:$dialPort/apps/Netflix/run'))
          .timeout(Duration(seconds: 2))
          .catchError((_) => http.Response('', 500)),
    ]);
  }

  // Get device info (for discovery)
  Future<DeviceInfo?> identify() async {
    final response = await http.get(
      Uri.parse('http://$tvIp:$dialPort/ssdp/device-desc.xml'),
    ).timeout(Duration(seconds: 3));
    // Parse XML for friendlyName, manufacturer, modelName
  }
}
```

### Background Service Design (Android)

```dart
// Using flutter_background_service

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,  // User explicitly starts lock mode
      isForegroundMode: true,
      notificationChannelId: 'boretube_lock',
      initialNotificationTitle: 'Boretube',
      initialNotificationContent: 'Lock mode active',
      foregroundServiceNotificationId: 1,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,  // iOS: foreground only
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // This runs in a separate Dart isolate (Android foreground service)

  final castClient = CastV2Client(tvIp: savedTvIp, tvPort: 8009);
  final dialClient = DialClient(tvIp: savedTvIp, dialPort: 8008);

  Timer.periodic(Duration(seconds: 10), (timer) async {
    final status = await castClient.getStatus();

    if (status.isError) {
      // TV off/unreachable — update notification, continue
      service.invoke('update', {'state': 'tv_off'});
      return;
    }

    if (status.isIdle || whitelist.contains(status.appId)) {
      // OK — update notification with current status
      service.invoke('update', {'state': 'ok', 'app': status.appName});
      return;
    }

    // NOT WHITELISTED — bore it
    await castClient.bore();
    await dialClient.killApps();
    log('STOPPED: ${status.appName} (${status.appId})');
    service.invoke('update', {'state': 'stopped', 'app': status.appName});
  });

  // Listen for stop command from UI
  service.on('stop').listen((_) {
    timer.cancel();
    castClient.setVolume(muted: false);  // Unmute on stop
    castClient.disconnect();
    service.stopSelf();
  });
}
```

### State Management

Recommended: **Riverpod** (lightweight, good for service-oriented apps) or **Provider** (simpler).

Key state:
- `TvConfig` — IP, name, ports, PSK (persisted)
- `TvStatus` — volume, muted, app, idle (live, refreshed)
- `LockState` — active/inactive, remaining time, last action
- `Whitelist` — list of allowed app IDs + names (persisted)
- `ActivityLog` — timestamped enforcement actions (persisted)

### Data Persistence

- **TV config:** `SharedPreferences` or `Hive` (simple key-value)
- **Whitelist:** `SharedPreferences` (small list) or SQLite via `sqflite` (if list grows)
- **Activity log:** SQLite via `sqflite` (structured, queryable, can grow large)
- **Lock state:** in-memory + `SharedPreferences` for crash recovery (restore lock mode if app restarts)

---

## Implementation Priority

### Phase 1: Core Remote Control (MVP)
1. TV config screen (manual IP entry + save)
2. CastV2 client (connect, status, stop, mute, unmute, volume)
3. Home screen with live status panel
4. One-tap actions: Kill App, Mute, Unmute, Bore (stop+mute), Restore
5. DIAL client for belt-and-suspenders kills

### Phase 2: Lock Mode
1. Whitelist management screen
2. Lock mode with foreground service (Android)
3. Persistent notification with status + stop button
4. Volume lock mode
5. Activity log (SQLite + log viewer screen)

### Phase 3: Discovery & Polish
1. mDNS TV discovery scan
2. Quick Settings tile (Android)
3. Home screen widget
4. Adaptive polling intervals (configurable)
5. Multiple TV profiles

### Phase 4: Extended Features
1. Sony REST API integration (power off, input switching)
2. Scheduled lock modes (daily recurring)
3. Quick presets (Homework Mode, Bedtime Mode)

---

## Feasibility Summary Matrix

| Feature | Android | iOS | Difficulty | Notes |
|---------|---------|-----|------------|-------|
| CastV2 TLS connection | Yes | Yes | Low | `SecureSocket.connect()` + `onBadCertificate` |
| Self-signed cert bypass | Yes | Yes | Low | `onBadCertificate: (_) => true` |
| Protobuf framing | Yes | Yes | Low | Compile `cast_channel.proto` or manual varint |
| DIAL HTTP (cleartext) | Yes (config) | Yes (config) | Low | One-time manifest/plist change |
| Background 10s polling | **Yes** | **No** | Medium | Android foreground service only |
| Volume lock polling | **Yes** | **No** | Medium | Same as above |
| mDNS discovery | Yes | Yes (permission) | Low-Medium | `nsd` or `bonsoir` package |
| Manual IP (cross-subnet) | Yes | Yes | Low | TextField + SharedPreferences |
| Persistent notification | Yes (required) | N/A | Low | Built into foreground service |
| Quick Settings tile | Yes (API 24+) | N/A | Medium | `quick_settings` plugin |
| Home screen widget | Yes | Yes | Medium-High | Requires native code (Kotlin/SwiftUI) |
| Sony REST API | Yes | Yes | Low | Simple HTTP POST with PSK header |
| Persistent TLS connection | Yes | Yes | Medium | Keep socket alive between polls — key perf win |

---

## Open Questions

1. **Should the app support multiple TVs simultaneously?** (e.g., lock mode on two TVs at once)
2. **Should lock mode survive phone reboot?** (auto-restart foreground service on boot — possible on Android with `RECEIVE_BOOT_COMPLETED` permission)
3. **Should there be a parent PIN/biometric lock on the app itself?** (prevent kid from disabling lock mode)
4. **Is the Sony REST API (port 80) setup doable on the target TV?** If yes, power-off becomes the nuclear option for lock mode.
5. **What minimum Android version to target?** Android 8.0 (API 26) for foreground service channels, or Android 10+ (API 29) to simplify?
6. **Should volume lock and app lock be combinable?** (e.g., whitelist enforcement + volume cap simultaneously)
7. **Persistent TLS connection: what's the idle timeout?** Need to test how long the TV keeps a CastV2 connection alive without activity. May need periodic heartbeat (PING).

---

*This document was generated from analysis of `boretube.sh` (875 lines), `detect.sh` (428 lines), `README.md`, `plan.md`, `tv.conf`, and `whitelist.conf` in the boretube repository.*
