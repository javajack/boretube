#!/usr/bin/env python3
"""Generate Open Graph image for boretube."""

from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1280, 640
BG = (13, 17, 23)        # GitHub dark bg
CYAN = (80, 200, 220)
RED = (230, 80, 80)
GREEN = (80, 210, 120)
YELLOW = (230, 200, 80)
WHITE = (220, 220, 220)
DIM = (100, 110, 120)
DIMMER = (50, 58, 68)
ACCENT = (40, 48, 58)

img = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

# ── Fonts ─────────────────────────────────────────────────
SANS_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

def sfont(size):
    return ImageFont.truetype(SANS_BOLD, size)

def mfont(size):
    return ImageFont.truetype(MONO_BOLD, size)

def mfont_regular(size):
    return ImageFont.truetype(MONO, size)

# ── Draw subtle grid background ──────────────────────────
for x in range(0, W, 24):
    draw.line([(x, 0), (x, H)], fill=(18, 22, 28), width=1)
for y in range(0, H, 24):
    draw.line([(0, y), (W, y)], fill=(18, 22, 28), width=1)

# ── Decorative scan lines (very subtle) ──────────────────
for y in range(0, H, 4):
    draw.line([(0, y), (W, y)], fill=(15, 19, 25), width=1)

# ── Big text logo: "BORETUBE" ────────────────────────────
f_logo = sfont(108)
logo_text = "BORETUBE"
logo_w = draw.textlength(logo_text, font=f_logo)
logo_x = (W - logo_w) / 2
logo_y = 100

# Glow effect: draw text multiple times with decreasing opacity
# Layer 1: wide dim glow
for dx in range(-3, 4):
    for dy in range(-3, 4):
        draw.text((logo_x + dx, logo_y + dy), logo_text, font=f_logo, fill=(20, 50, 55))
# Layer 2: tighter glow
for dx in range(-1, 2):
    for dy in range(-1, 2):
        draw.text((logo_x + dx, logo_y + dy), logo_text, font=f_logo, fill=(35, 90, 100))
# Layer 3: the crisp text
draw.text((logo_x, logo_y), logo_text, font=f_logo, fill=CYAN)

# ── Underline accent bar ─────────────────────────────────
bar_y = logo_y + 120
bar_w = logo_w * 0.8
bar_x = (W - bar_w) / 2
draw.rectangle([(bar_x, bar_y), (bar_x + bar_w, bar_y + 3)], fill=DIMMER)
# Bright center segment
seg_w = bar_w * 0.4
seg_x = (W - seg_w) / 2
draw.rectangle([(seg_x, bar_y), (seg_x + seg_w, bar_y + 3)], fill=CYAN)

# ── Terminal prompt: "$ boretube lock 60" ─────────────────
f_cmd = mfont(20)
f_cmd_r = mfont_regular(20)
cmd_y = 280
cmd_parts = [
    ("$", GREEN),
    (" boretube", CYAN),
    (" lock", WHITE),
    (" 60", YELLOW),
]
cmd_total = sum(draw.textlength(t, font=f_cmd) for t, _ in cmd_parts)
cx = (W - cmd_total) / 2
for text, color in cmd_parts:
    f = f_cmd if text in ("$", " boretube") else f_cmd_r
    draw.text((cx, cmd_y), text, font=f, fill=color)
    cx += draw.textlength(text, font=f)

# ── Blinking cursor ──────────────────────────────────────
draw.rectangle([(cx + 4, cmd_y + 2), (cx + 16, cmd_y + 24)], fill=GREEN)

# ── Tagline ──────────────────────────────────────────────
f_tag = mfont(26)
tagline = "Make TV boring. Kids go outside."
tw = draw.textlength(tagline, font=f_tag)
draw.text(((W - tw) / 2, 370), tagline, font=f_tag, fill=YELLOW)

# ── Subtitle ─────────────────────────────────────────────
f_sub = mfont_regular(15)
sub = "Parental control via reverse-engineered CastV2 + DIAL protocols"
sw = draw.textlength(sub, font=f_sub)
draw.text(((W - sw) / 2, 415), sub, font=f_sub, fill=DIM)

# ── Protocol badges ──────────────────────────────────────
f_badge = mfont(13)
badges = [
    ("CastV2", CYAN),
    ("DIAL", GREEN),
    ("protobuf", YELLOW),
    ("bash", RED),
]
badge_gap = 20
badge_h = 28
badge_y = 460
# Calculate total width
total_bw = 0
for label, _ in badges:
    total_bw += draw.textlength(label, font=f_badge) + 20
total_bw += badge_gap * (len(badges) - 1)
bx = (W - total_bw) / 2

for label, color in badges:
    tw = draw.textlength(label, font=f_badge)
    pw = tw + 20
    # Pill background
    r = badge_h // 2
    draw.rounded_rectangle(
        [(bx, badge_y), (bx + pw, badge_y + badge_h)],
        radius=r,
        fill=(color[0] // 8, color[1] // 8, color[2] // 8),
        outline=color,
        width=1,
    )
    draw.text((bx + 10, badge_y + 5), label, font=f_badge, fill=color)
    bx += pw + badge_gap

# ── Fake terminal status line at bottom ──────────────────
f_term = mfont_regular(14)
# dark bar
draw.rectangle([(0, H - 50), (W, H)], fill=(18, 22, 28))
draw.line([(0, H - 50), (W, H - 50)], fill=DIMMER, width=1)

status_parts = [
    ("  [23:47:31] ", DIM),
    ("Stopped: YouTube ", RED),
    ("(not whitelisted)", DIM),
    ("    ", BG),
    ("[23:47:42] ", DIM),
    ("Home screen ", GREEN),
    ("(idle)", DIM),
]
x = 30
for text, color in status_parts:
    draw.text((x, H - 37), text, font=f_term, fill=color)
    x += draw.textlength(text, font=f_term)

# ── Save ─────────────────────────────────────────────────
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "og-image.png")
img.save(out, "PNG")
print(f"Saved: {out} ({W}x{H})")
