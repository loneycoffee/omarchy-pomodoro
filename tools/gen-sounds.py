#!/usr/bin/env python3
"""Synthesize the alarm and ticking sounds shipped in ../sounds.

Stdlib only, so the files can be regenerated anywhere:

    python3 tools/gen-sounds.py

Alarms are short one-shots played N times; ticking and noise are loops the
player restarts back to back, so they are long enough that the restart gap is
rare and short enough to keep the plugin small.
"""

import math
import os
import random
import struct
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "sounds")
RATE = 22050


def write(name, samples, rate=RATE):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.89 / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print("wrote", os.path.relpath(path))


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix_into(buf, at, part):
    start = int(at * RATE)
    need = start + len(part)
    if need > len(buf):
        buf.extend([0.0] * (need - len(buf)))
    for i, s in enumerate(part):
        buf[start + i] += s


def tone(freq, seconds, decay, partials=((1.0, 1.0),), attack=0.004):
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * decay) * min(1.0, t / attack)
        s = 0.0
        for ratio, amp in partials:
            s += amp * math.sin(2 * math.pi * freq * ratio * t)
        out.append(s * env)
    return out


# ---------------------------------------------------------------- alarms

def bell():
    # A struck bell: inharmonic partials, the high ones dying first.
    n = int(2.6 * RATE)
    partials = ((1.0, 1.0, 1.6), (2.0, 0.6, 2.4), (2.76, 0.45, 3.2), (5.4, 0.25, 5.0), (8.93, 0.12, 7.5))
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.0
        for ratio, amp, decay in partials:
            s += amp * math.exp(-t * decay) * math.sin(2 * math.pi * 660 * ratio * t)
        out.append(s * min(1.0, t / 0.002))
    buf = []
    mix_into(buf, 0.0, out)
    mix_into(buf, 0.9, [s * 0.8 for s in out])
    return buf


def kitchen():
    # A wind-up kitchen timer: a clapper hammering a small bell ~22 times/s.
    seconds = 1.6
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        phase = (t * 22.0) % 1.0
        hit = math.exp(-phase * 9.0)
        s = math.sin(2 * math.pi * 2350 * t) * 0.7 + math.sin(2 * math.pi * 3720 * t) * 0.35
        fade = min(1.0, (seconds - t) / 0.08)
        out.append(s * hit * fade)
    return out + silence(0.25)


def digital():
    # Classic watch alarm: four quick beeps, twice.
    beep = tone(2048, 0.075, 4.0, ((1.0, 1.0), (3.0, 0.18)), attack=0.002)
    buf = []
    at = 0.0
    for group in range(2):
        for k in range(4):
            mix_into(buf, at, beep)
            at += 0.125
        at += 0.35
    return buf + silence(0.1)


def chime():
    # Soft ascending arpeggio, C6 E6 G6 C7.
    buf = []
    for k, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        mix_into(buf, k * 0.16, tone(f, 1.6, 2.6, ((1.0, 1.0), (2.0, 0.2), (3.0, 0.06))))
    return buf


def wood():
    # Three wood-block knocks.
    rnd = random.Random(7)
    n = int(0.12 * RATE)
    knock = []
    for i in range(n):
        t = i / RATE
        body = math.sin(2 * math.pi * 880 * t) * math.exp(-t * 55) + 0.5 * math.sin(2 * math.pi * 1410 * t) * math.exp(-t * 80)
        click = (rnd.random() * 2 - 1) * math.exp(-t * 900) * 0.6
        knock.append(body + click)
    buf = []
    for k, at in enumerate((0.0, 0.18, 0.36)):
        mix_into(buf, at, knock)
    return buf + silence(0.2)


# --------------------------------------------------------------- ticking

def tick_sample(rnd, pitch=1.0):
    n = int(0.03 * RATE)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / RATE
        noise = rnd.random() * 2 - 1
        hp = noise - prev
        prev = noise
        s = hp * math.exp(-t * 700) * 0.5 + math.sin(2 * math.pi * 3100 * pitch * t) * math.exp(-t * 260) * 0.7
        out.append(s)
    return out


def ticking(seconds, per_second):
    rnd = random.Random(3)
    buf = silence(seconds)
    step = 1.0 / per_second
    k = 0
    t = 0.0
    while t < seconds - 0.001:
        # Tick / tock: alternate pitch so the fast clock sounds mechanical.
        mix_into(buf, t, tick_sample(rnd, 1.0 if k % 2 == 0 else 0.86))
        k += 1
        t += step
    return buf[: int(seconds * RATE)]


def white_noise(seconds):
    rnd = random.Random(11)
    return [(rnd.random() * 2 - 1) * 0.35 for _ in range(int(seconds * RATE))]


def brown_noise(seconds):
    rnd = random.Random(13)
    out = []
    last = 0.0
    for _ in range(int(seconds * RATE)):
        last = (last + 0.02 * (rnd.random() * 2 - 1)) / 1.02
        out.append(last)
    # Remove DC drift so the loop seam does not thump.
    mean = sum(out) / len(out)
    return [s - mean for s in out]


def main():
    os.makedirs(OUT, exist_ok=True)
    write("alarm-bell", bell())
    write("alarm-kitchen", kitchen())
    write("alarm-digital", digital())
    write("alarm-chime", chime())
    write("alarm-wood", wood())
    write("tick-slow", ticking(10.0, 1))
    write("tick-fast", ticking(10.0, 2))
    write("noise-white", white_noise(15.0))
    write("noise-brown", brown_noise(15.0))


if __name__ == "__main__":
    main()
