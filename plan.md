# Power Off TV via Sony Bravia REST API

## Why
CastV2 (port 8009) and DIAL (port 8008) cannot power off the TV — they're casting protocols only. Sony Bravia exposes a JSON-RPC REST API on port 80 that can.

## TV Setup Required
1. **Settings > Network & Internet > Home Network > IP Control**
2. Set **Authentication** to **Normal and Pre-Shared Key**
3. Set a **Pre-Shared Key** (e.g. `1234`)
4. Enable **Simple IP Control** if available

## API Usage

```bash
# Power off
curl -s -X POST "http://192.168.1.3/sony/system" \
  -H "Content-Type: application/json" \
  -H "X-Auth-PSK: 1234" \
  -d '{"method":"setPowerStatus","params":[{"status":false}],"id":1,"version":"1.0"}'

# Power on
curl -s -X POST "http://192.168.1.3/sony/system" \
  -H "Content-Type: application/json" \
  -H "X-Auth-PSK: 1234" \
  -d '{"method":"setPowerStatus","params":[{"status":true}],"id":1,"version":"1.0"}'

# Check power status
curl -s -X POST "http://192.168.1.3/sony/system" \
  -H "Content-Type: application/json" \
  -d '{"method":"getPowerStatus","params":[],"id":1,"version":"1.0"}'
```

## Implementation Plan
- Store PSK in `tv.conf` (e.g. `TV_PSK=1234`)
- Add `detect.sh` probe for port 80 Sony API availability
- Add boretube actions: `power_off`, `power_on` (CLI + menu)
- Could replace lock mode's "kill + mute" with "just turn the TV off" — nuclear option
- Unlocks other features: input switching, remote control emulation

## Status
- Port 80 not responding on TV currently (needs TV-side setup first)
- Tested 2026-02-25: `curl http://192.168.1.3/sony/system` → unreachable
