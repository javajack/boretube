#!/usr/bin/env python3
"""Renders boretube Learn's sounds (spec §6) into app/src/main/res/raw/*.ogg.

Everything is synthesised here, so we own every sound outright. All pitches
come from one scale, C major pentatonic, so overlapping sounds never clash.
Micro sounds stay under 300 ms; celebrations under 2 s; nothing harsh, no
buzzers. Needs numpy and ffmpeg (libvorbis).

    python3 tools/sfx.py
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44_100
OUT = os.path.join(os.path.dirname(__file__), "..", "app", "src", "main", "res", "raw")

# C major pentatonic, C4 up to E7.
_NAMES = ["C", "D", "E", "G", "A"]
_SEMIS = [0, 2, 4, 7, 9]
PENT = {}
for octave in range(4, 8):
    for name, semi in zip(_NAMES, _SEMIS):
        PENT[f"{name}{octave}"] = 261.63 * 2 ** (octave - 4) * 2 ** (semi / 12)
LADDER = [PENT[k] for k in ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6"]]


def t(dur):
    return np.arange(int(SR * dur)) / SR


def fade(x, ms_in=4, ms_out=8):
    n_in, n_out = int(SR * ms_in / 1000), int(SR * ms_out / 1000)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def marimba(f, dur=0.35):
    tt = t(dur)
    x = (np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.13)
         + 0.28 * np.sin(2 * np.pi * 3.9 * f * tt) * np.exp(-tt / 0.025)
         + 0.08 * np.sin(2 * np.pi * 9.2 * f * tt) * np.exp(-tt / 0.008))
    return fade(x, 2, 20)


def bell(f, dur=0.8, bright=1.0):
    tt = t(dur)
    parts = [(1, 1.0, 0.55), (2.76, 0.45 * bright, 0.28), (5.4, 0.22 * bright, 0.13), (8.93, 0.1 * bright, 0.06)]
    x = sum(a * np.sin(2 * np.pi * f * r * tt) * np.exp(-tt / d) for r, a, d in parts)
    return fade(x, 3, 40)


def woodblock(f, dur=0.12):
    tt = t(dur)
    x = np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.035) + 0.4 * np.sin(2 * np.pi * 1.48 * f * tt) * np.exp(-tt / 0.02)
    click = np.random.default_rng(1).normal(0, 1, len(tt)) * np.exp(-tt / 0.002) * 0.15
    return fade(x + click, 1, 10)


def soft(f, dur, attack=0.03):
    tt = t(dur)
    env = np.minimum(1, tt / attack) * np.exp(-tt / (dur * 0.6))
    return fade(np.sin(2 * np.pi * f * tt) * env, 1, 20)


def glide(f0, f1, dur, decay):
    tt = t(dur)
    f = np.geomspace(f0, f1, len(tt))
    phase = 2 * np.pi * np.cumsum(f) / SR
    return fade(np.sin(phase) * np.exp(-tt / decay), 1, 10)


def noise_sweep(dur, start, end, seed=2):
    """Soft filtered noise whose brightness moves from start to end (0..1)."""
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    raw = rng.normal(0, 1, n)
    cut = np.linspace(start, end, n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):  # one-pole low-pass with a moving cutoff
        a = 0.02 + 0.25 * cut[i]
        acc += a * (raw[i] - acc)
        y[i] = acc
    env = np.sin(np.pi * np.linspace(0, 1, n)) ** 2
    return fade(y * env, 2, 20)


def seq(*parts):
    """[(offset_s, signal), ...] mixed into one buffer."""
    end = max(o + len(s) / SR for o, s in parts)
    out = np.zeros(int(SR * end) + 1)
    for o, s in parts:
        i = int(SR * o)
        out[i:i + len(s)] += s
    return out


def sparkle(base=0.0):
    return [(base + i * 0.035, 0.25 * bell(PENT[n], 0.35, 0.6)) for i, n in enumerate(["C7", "E7", "G7"])]


def tabla(f=180, dur=0.25):
    return glide(f * 1.6, f, dur, 0.08)


def norm(x, db):
    """Peak to [db] dBFS (micro sounds sit lower than celebrations)."""
    peak = np.max(np.abs(x)) or 1
    return x / peak * 10 ** (db / 20)


SOUNDS = {
    # Getting around.
    "select": lambda: norm(glide(900, 320, 0.07, 0.03), -12),
    "back": lambda: norm(noise_sweep(0.22, 0.7, 0.1), -16),
    "focus_bazaar": lambda: norm(marimba(PENT["G6"], 0.09), -20),
    "focus_garden": lambda: norm(bell(PENT["E6"], 0.14, 0.4), -22),
    "focus_trail": lambda: norm(woodblock(PENT["C6"], 0.08), -20),
    "enter_bazaar": lambda: norm(seq((0, 0.5 * noise_sweep(0.28, 0.1, 0.8)),
                                     (0.18, marimba(PENT["G5"])), (0.30, marimba(PENT["A5"])), (0.42, marimba(PENT["C6"], 0.5))), -10),
    # Questions.
    "q_show": lambda: norm(bell(PENT["E6"], 0.4, 0.5), -18),
    **{f"right_{n}": (lambda n=n: norm(seq((0, marimba(LADDER[n - 1], 0.25)), (0.09, marimba(LADDER[n + 1], 0.4))), -10))
       for n in range(1, 6)},
    # A miss is a warm "hmm": two soft notes falling. Never a buzzer.
    "miss": lambda: norm(seq((0, soft(PENT["A4"], 0.2)), (0.17, soft(PENT["E4"], 0.32))), -16),
    "learn_open": lambda: norm(bell(PENT["C5"], 0.9, 0.5), -16),
    "followup_win": lambda: norm(seq((0, marimba(PENT["C5"])), (0.04, marimba(PENT["E5"])), (0.08, marimba(PENT["G5"], 0.6)),
                                     *sparkle(0.12)), -10),
    # Catch.
    "catch_drop": lambda: norm(glide(1400, 880, 0.26, 0.2), -22),
    "catch_move": lambda: norm(noise_sweep(0.09, 0.3, 0.6, seed=5), -22),
    "catch_right": lambda: norm(seq((0, glide(620, 160, 0.09, 0.05)), *sparkle(0.05)), -12),
    "catch_miss": lambda: norm(glide(330, 220, 0.28, 0.12) * (1 + 0.2 * np.sin(2 * np.pi * 18 * t(0.28))), -18),
    # Build.
    "build_ten": lambda: norm(woodblock(PENT["G4"], 0.14), -14),
    "build_one": lambda: norm(woodblock(PENT["E6"], 0.07), -18),
    "build_undo": lambda: norm(glide(320, 900, 0.07, 0.04), -16),
    "build_hit": lambda: norm(seq((0, bell(PENT["C6"], 0.6, 0.8)), *sparkle(0.04)), -11),
    # Pairs.
    "card_flip": lambda: norm(noise_sweep(0.08, 0.2, 0.9, seed=7), -18),
    "card_back": lambda: norm(noise_sweep(0.1, 0.8, 0.15, seed=8), -22),
    "pair_match": lambda: norm(seq((0, bell(PENT["G5"], 0.4, 0.6)), (0.08, bell(PENT["C6"], 0.6, 0.6)), *sparkle(0.12)), -11),
    # Rewards.
    **{f"star_{n}": (lambda n=n: norm(seq((0, marimba([PENT["C6"], PENT["E6"], PENT["G6"]][n - 1], 0.5)),
                                          *sparkle(0.03)), -11)) for n in range(1, 4)},
    "level_done_bazaar": lambda: norm(seq(
        (0.00, tabla()), (0.16, tabla(150)),
        (0.00, marimba(PENT["C5"])), (0.12, marimba(PENT["E5"])), (0.24, marimba(PENT["G5"])),
        (0.36, marimba(PENT["C6"])), (0.48, marimba(PENT["E6"], 0.6)),
        (0.70, 0.7 * marimba(PENT["C5"], 1.0)), (0.70, 0.7 * marimba(PENT["G5"], 1.0)), (0.70, marimba(PENT["E6"], 1.0)),
        (0.62, tabla(200)), *sparkle(0.9)), -9),
}


def write_ogg(name, x):
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, f"{name}.ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    os.remove(path)
    return os.path.getsize(dst)


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name in sorted(SOUNDS):
        x = SOUNDS[name]()
        dur = len(x) / SR
        limit = 2.0 if name.startswith(("level_done", "enter_", "followup")) else 1.0
        if dur > limit:
            sys.exit(f"{name} is {dur:.2f} s (limit {limit} s)")
        total += write_ogg(name, x)
        print(f"{name:20s} {dur * 1000:5.0f} ms")
    print(f"{len(SOUNDS)} sounds, {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
