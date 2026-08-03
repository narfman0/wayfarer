#!/usr/bin/env python3
"""Synthesize Wayfarer's placeholder audio: combat SFX + per-plane ambient
loops. 44.1 kHz 16-bit mono WAVs into assets/audio/. Loops are made seamless
by crossfading the tail into the head. Deliberately quiet — the game mixes
them at low default volume; placeholder quality, real identity."""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent
OUT = Path("assets/audio")  # run from repo root


def write_wav(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    if peak > 0.98:
        samples = [s / peak * 0.98 for s in samples]
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    print("wrote", OUT / name, f"{len(samples)/SR:.2f}s")


def env_exp(n, i, k=6.0):
    return math.exp(-k * i / n)


def lowpass(xs, alpha):
    out, y = [], 0.0
    for x in xs:
        y += alpha * (x - y)
        out.append(y)
    return out


def seamless(samples, fade=0.5):
    nf = int(fade * SR)
    body = samples[:-nf]
    tail = samples[-nf:]
    for i in range(nf):
        t = i / nf
        body[i] = body[i] * t + tail[i] * (1.0 - t)
    return body


rng = random.Random(7)

# ── SFX ──────────────────────────────────────────────────────────────────────

def sfx_swing():
    n = int(0.16 * SR)
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    out = []
    y = 0.0
    for i, x in enumerate(noise):
        a = 0.04 + 0.3 * (i / n)          # opening filter = whoosh sweep
        y += a * (x - y)
        w = math.sin(math.pi * i / n)     # swell in and out
        out.append(y * w * 0.9)
    return out


def sfx_hit():
    n = int(0.13 * SR)
    out = []
    for i in range(n):
        t = i / SR
        thump = math.sin(2 * math.pi * (95 - 40 * i / n) * t) * env_exp(n, i, 9)
        click = rng.uniform(-1, 1) * env_exp(n, i, 40) * 0.5
        out.append(0.85 * thump + click)
    return out


def sfx_crit():
    n = int(0.22 * SR)
    out = []
    for i in range(n):
        t = i / SR
        thump = math.sin(2 * math.pi * (120 - 55 * i / n) * t) * env_exp(n, i, 8)
        ring = (math.sin(2 * math.pi * 830 * t) + 0.6 * math.sin(2 * math.pi * 1247 * t)) \
            * env_exp(n, i, 12) * 0.35
        click = rng.uniform(-1, 1) * env_exp(n, i, 35) * 0.6
        out.append(0.8 * thump + ring + click)
    return out


def sfx_death():
    n = int(0.55 * SR)
    out = []
    phase = 0.0
    for i in range(n):
        f = 200 * (1.0 - 0.75 * i / n)    # falling groan
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) + 0.3 * math.sin(2 * phase)
        out.append(s * env_exp(n, i, 4) * 0.7)
    return out


def sfx_telegraph():
    n = int(0.45 * SR)
    out = []
    phase = 0.0
    for i in range(n):
        f = 520 + 360 * (i / n)           # rising alarm
        phase += 2 * math.pi * f / SR
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * 13 * i / SR)
        out.append(math.sin(phase) * trem * min(1.0, 4.0 * (1.0 - i / n)) * 0.5)
    return out


def sfx_portal():
    n = int(0.9 * SR)
    out = [0.0] * n
    for k, f in enumerate([392, 523, 659, 784]):  # rising shimmer arpeggio
        start = int(k * 0.12 * SR)
        for i in range(start, n):
            t = (i - start) / SR
            out[i] += math.sin(2 * math.pi * f * t) * math.exp(-3.5 * t) * 0.28
    return out


# ── Ambient loops (10 s seamless) ────────────────────────────────────────────

def wind(n, base_alpha=0.02, gust_hz=0.1, depth=0.5, gain=1.0):
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    ys = lowpass(noise, base_alpha)
    return [y * (1.0 - depth + depth * 0.5 *
                 (1 + math.sin(2 * math.pi * gust_hz * i / SR))) * gain
            for i, y in enumerate(ys)]


def drone(n, freqs, gain=0.2, lfo_hz=0.1, lfo_depth=0.25):
    out = []
    for i in range(n):
        t = i / SR
        s = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        s *= 1.0 - lfo_depth + lfo_depth * 0.5 * (1 + math.sin(2 * math.pi * lfo_hz * t))
        out.append(s * gain)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    return [sum(l[i] if i < len(l) else 0.0 for l in layers) for i in range(n)]


DUR = 10.5
N = int(DUR * SR)

def amb_meadow():
    base = wind(N, 0.03, 0.2, 0.45, 0.8)
    # a few soft distant bird figures
    for start_s, f in [(1.2, 2400), (4.7, 2800), (7.9, 2200)]:
        s0 = int(start_s * SR)
        for i in range(int(0.18 * SR)):
            t = i / SR
            base[s0 + i] += math.sin(2 * math.pi * (f + 400 * math.sin(2 * math.pi * 9 * t)) * t) \
                * math.exp(-14 * t) * 0.10
    return base

def amb_fields():
    return mix(wind(N, 0.025, 0.15, 0.55, 0.9), drone(N, [55, 55.7], 0.10, 0.07))

def amb_reach():
    hum = drone(N, [60, 120, 180.4], 0.12, 0.2, 0.35)
    thud = [0.0] * N
    for b in range(int(DUR / 2.1)):                 # slow machine strokes
        s0 = int(b * 2.1 * SR)
        for i in range(min(int(0.3 * SR), N - s0)):
            t = i / SR
            thud[s0 + i] += math.sin(2 * math.pi * 48 * t) * math.exp(-8 * t) * 0.22
    return mix(wind(N, 0.02, 0.12, 0.5, 0.55), hum, thud)

def amb_kaveth():
    base = mix(drone(N, [110, 110.8, 164.8], 0.14, 0.05), wind(N, 0.01, 0.08, 0.4, 0.25))
    for _ in range(22):                              # night crickets
        s0 = rng.randrange(0, N - int(0.06 * SR))
        for i in range(int(0.05 * SR)):
            t = i / SR
            base[s0 + i] += math.sin(2 * math.pi * 4300 * t) \
                * (0.5 + 0.5 * math.sin(2 * math.pi * 55 * t)) * math.exp(-40 * t) * 0.06
    return base

def amb_verath():
    swell = []
    noise = lowpass([rng.uniform(-1, 1) for _ in range(N)], 0.06)
    for i, x in enumerate(noise):                    # two wave periods per loop
        w = 0.25 + 0.75 * (0.5 * (1 + math.sin(2 * math.pi * 0.19 * i / SR))) ** 2
        swell.append(x * w * 0.9)
    return mix(swell, wind(N, 0.015, 0.3, 0.3, 0.3))

def amb_between():
    return mix(drone(N, [220, 223, 146.6], 0.13, 0.09, 0.5),
               drone(N, [440.5, 445], 0.04, 0.13, 0.6))

def amb_ashan():
    return mix(wind(N, 0.035, 0.18, 0.35, 0.5), drone(N, [196, 246.9, 293.7], 0.07, 0.08))

def amb_convergence():
    pulse = []
    for i in range(N):
        t = i / SR
        g = 0.5 + 0.5 * math.sin(2 * math.pi * 1.4 * t)
        pulse.append(math.sin(2 * math.pi * 82 * t) * g * 0.18)
    return mix(pulse, drone(N, [620, 661, 987], 0.05, 0.3, 0.6),
               wind(N, 0.008, 0.2, 0.5, 0.2))


write_wav("sfx_swing.wav", sfx_swing())
write_wav("sfx_hit.wav", sfx_hit())
write_wav("sfx_crit.wav", sfx_crit())
write_wav("sfx_death.wav", sfx_death())
write_wav("sfx_telegraph.wav", sfx_telegraph())
write_wav("sfx_portal.wav", sfx_portal())

# Short seamless hum for VeilTear's AudioStreamPlayer3D (B3 shared language).
def veil_hum():
    n = int(4.0 * SR)
    return mix(drone(n, [72, 72.5, 144.5], 0.5, 0.5, 0.35),
               drone(n, [288.5], 0.06, 1.0, 0.5))

write_wav("veil_hum.wav", seamless(veil_hum()))

write_wav("ambient_meadow.wav", seamless(amb_meadow()))
write_wav("ambient_fields.wav", seamless(amb_fields()))
write_wav("ambient_reach.wav", seamless(amb_reach()))
write_wav("ambient_kaveth.wav", seamless(amb_kaveth()))
write_wav("ambient_verath.wav", seamless(amb_verath()))
write_wav("ambient_between.wav", seamless(amb_between()))
write_wav("ambient_ashan.wav", seamless(amb_ashan()))
write_wav("ambient_convergence.wav", seamless(amb_convergence()))
