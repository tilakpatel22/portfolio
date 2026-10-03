#!/usr/bin/env python3
"""Synthesizes all original music, stingers, ambience and SFX for Ship Traffic Control Sim.

Usage: python3 tools/gen_audio.py  (writes OGG files to assets/audio/)
Requires: numpy, scipy, soundfile. Fully deterministic (seeded), royalty-free by construction.
"""
import os
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
TAU = 2 * np.pi


def tt(dur):
    return np.arange(int(dur * SR)) / SR


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def filt(x, kind, f, order=2):
    wn = np.asarray(f, dtype=float) / (SR / 2)
    sos = butter(order, wn if wn.ndim else float(wn), btype=kind, output="sos")
    return sosfilt(sos, x)


def attack(x, ms=4):
    n = min(len(x), int(SR * ms / 1000))
    x[:n] *= np.linspace(0, 1, n)
    return x


def fade_out(x, ms=30):
    n = min(len(x), int(SR * ms / 1000))
    x[-n:] *= np.linspace(1, 0, n)
    return x


# ---------------------------------------------------------------- instruments

def marimba(f, dur=0.9, vel=1.0):
    t = tt(dur)
    y = (np.sin(TAU * f * t) * np.exp(-t * (3.2 + f / 700))
         + 0.22 * np.sin(TAU * f * 3.93 * t) * np.exp(-t * 11)
         + 0.07 * np.sin(TAU * f * 9.2 * t) * np.exp(-t * 22))
    return attack(y * vel, 2)


def steel(f, dur=1.3, vel=1.0):
    t = tt(dur)
    bend = 1 + 0.012 * np.exp(-t * 30)
    y = np.zeros_like(t)
    for k, a, d in [(1, 1, 2.6), (2.0, .55, 3.5), (3.01, .3, 5), (4.23, .2, 7), (5.9, .1, 9)]:
        y += a * np.sin(TAU * f * k * np.cumsum(bend) / SR) * np.exp(-t * d)
    return attack(y * vel * 0.6, 3)


def pluck(f, dur=0.6, vel=1.0, bright=1.0):
    t = tt(dur)
    y = np.zeros_like(t)
    for k in range(1, 11):
        if f * k > 12000:
            break
        y += np.sin(TAU * f * k * t) / k ** (1.4 / bright) * np.exp(-t * (3 + k * 1.6))
    return attack(y * vel * 0.7, 2)


def bass(f, dur=0.5, vel=1.0):
    t = tt(dur)
    y = np.sin(TAU * f * t) + 0.35 * np.sin(TAU * 2 * f * t) + 0.1 * np.sin(TAU * 3 * f * t)
    y = np.tanh(1.6 * y) * np.exp(-t * 2.2)
    return fade_out(attack(y * vel * 0.8, 5), 25)


def pad(freqs, dur, vel=1.0, cutoff=2200):
    t = tt(dur)
    y = np.zeros_like(t)
    for f in freqs:
        for det in (-0.004, 0.0, 0.0045):
            for k in range(1, 9):
                y += np.sin(TAU * f * (1 + det) * k * t + k * 1.3) / k
    y = filt(y, "low", cutoff)
    env = np.minimum(1, t / 0.6) * np.minimum(1, (dur - t) / 0.8)
    return y * env * vel * 0.05


def brass(f, dur, vel=1.0):
    t = tt(dur)
    vib = 1 + 0.006 * np.sin(TAU * 5.2 * t) * np.minimum(1, t / 0.3)
    ph = TAU * f * np.cumsum(vib) / SR
    y = sum(np.sin(k * ph) / k for k in range(1, 12))
    env = np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.12)
    y = filt(y, "low", 900 + 2200 * min(1.0, vel))
    return y * env * vel * 0.35


def bell(f, dur=2.0, vel=1.0):
    t = tt(dur)
    y = np.zeros_like(t)
    for k, a, d in [(1, 1, 1.4), (2.76, .5, 2.2), (5.4, .25, 3.5), (8.93, .12, 5), (0.5, .3, 1.0)]:
        y += a * np.sin(TAU * f * k * t) * np.exp(-t * d)
    return attack(y * vel * 0.4, 1)


def noise(dur, seed=0):
    return np.random.default_rng(seed).standard_normal(int(dur * SR))


def kick(vel=1.0):
    t = tt(0.4)
    f = 45 + 85 * np.exp(-t * 28)
    y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    y[:80] += np.linspace(0.6, 0, 80)
    return y * vel


def snare(vel=1.0, seed=1):
    t = tt(0.25)
    n = filt(noise(0.25, seed), "band", [1200, 6000]) * np.exp(-t * 18)
    return (0.9 * n + 0.5 * np.sin(TAU * 190 * t) * np.exp(-t * 25)) * vel


def clap(vel=1.0, seed=2):
    y = np.zeros(int(0.3 * SR))
    for i, off in enumerate([0, 0.011, 0.022]):
        n = filt(noise(0.2, seed + i), "band", [900, 4000])
        n *= np.exp(-tt(0.2) * (60 if i < 2 else 14))
        s = int(off * SR)
        y[s:s + len(n)] += n[:len(y) - s]
    return y * vel * 0.8


def hat(vel=1.0, open_=False, seed=3):
    d = 0.3 if open_ else 0.06
    t = tt(d)
    return filt(noise(d, seed), "high", 7000) * np.exp(-t * (9 if open_ else 60)) * vel * 0.5


def shaker(vel=1.0, seed=4):
    t = tt(0.09)
    return filt(noise(0.09, seed), "band", [4500, 9500]) * np.sin(np.pi * t / 0.09) ** 2 * vel * 0.35


def tom(f, vel=1.0):
    t = tt(0.45)
    fr = f * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(TAU * np.cumsum(fr) / SR) * np.exp(-t * 6) * vel


def cymbal(dur=2.0, vel=1.0, swell=False, seed=5):
    t = tt(dur)
    n = filt(noise(dur, seed), "high", 5000)
    env = (t / dur) ** 2 if swell else np.exp(-t * 2.2)
    return n * env * vel * 0.35


# ---------------------------------------------------------------- mixing

class Mix:
    def __init__(self, dur, tail=3.0):
        self.loop = int(dur * SR)
        self.buf = np.zeros((self.loop + int(tail * SR), 2))
        self.dry = np.zeros_like(self.buf)

    def add(self, sig, at, pan=0.0, gain=1.0, verb=0.25):
        s = int(at * SR)
        e = min(s + len(sig), len(self.buf))
        if e <= s:
            return
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        part = sig[:e - s] * gain
        self.buf[s:e, 0] += part * l * verb
        self.buf[s:e, 1] += part * r * verb
        self.dry[s:e, 0] += part * l
        self.dry[s:e, 1] += part * r

    def render(self, room=1.6, loop=True):
        out = self.dry + reverb(self.buf, room)
        if loop:
            tail = out[self.loop:]
            out = out[:self.loop].copy()
            out[:len(tail)] += tail[:self.loop]
        return master(out)


def reverb(x, room=1.6):
    n = int(room * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(x)
    for ch, seed in ((0, 11), (1, 12)):
        ir = np.random.default_rng(seed).standard_normal(n) * np.exp(-t * 4.2 / room)
        ir = filt(ir, "low", 5000)
        ir[: int(0.012 * SR)] = 0
        out[:, ch] = fftconvolve(x[:, ch], ir)[: len(x)] * 0.09
    return out


def master(x, ceiling=0.89):
    x = x - np.mean(x, axis=0)
    peak = np.max(np.abs(x)) + 1e-9
    x = np.tanh(x / peak * 1.25) / np.tanh(1.25)
    return x * ceiling


def write(name, data, stereo=True, trim=True):
    os.makedirs(OUT, exist_ok=True)
    if not stereo and data.ndim == 2:
        data = data.mean(axis=1)
    if trim:
        level = np.abs(data) if data.ndim == 1 else np.abs(data).max(axis=1)
        end = min(len(data), int(np.nonzero(level > 0.002)[0][-1] + 0.08 * SR))
        data = data[:end].copy()
        data[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))[:, None] if data.ndim == 2 else np.linspace(1, 0, int(0.05 * SR))
    # Size-tuned Vorbis: long music loops compress harder than short effects.
    level = 0.8 if len(data) > 20 * SR else 0.7
    sf.write(os.path.join(OUT, name + ".ogg"), data.astype(np.float32), SR, format="OGG", subtype="VORBIS",
             compression_level=level)
    print(f"{name}.ogg  {len(data) / SR:5.1f}s")


# ---------------------------------------------------------------- composition

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]


def chord(root_midi, scale, degree, notes=3):
    return [root_midi + scale[(degree + 2 * i) % 7] + 12 * ((degree + 2 * i) // 7) for i in range(notes)]


def melody(rng, scale, root, prog, bars, beat, density=0.6, octave=2):
    """Phrase-based diatonic melody (A A' B A): chord tones on beats, scale neighbours off-beat."""
    motif_rhythms = [[0, 1, 1.5, 2, 3], [0, 0.5, 1, 2, 2.5, 3], [0, 1.5, 2, 3, 3.5], [0, 2, 2.5, 3]]
    base = root + 12 * octave

    def deg_to_midi(d):
        return base + scale[d % 7] + 12 * (d // 7)

    notes = []
    phrases = {}
    for bar in range(bars):
        sec = ["A", "A2", "B", "A"][(bar // 4) % 4]
        key = ("A" if sec == "A2" else sec, bar % 4)
        if key not in phrases:
            rhythm = motif_rhythms[rng.integers(len(motif_rhythms))]
            phrases[key] = [(r, int(rng.integers(0, 3)), int(rng.choice([-1, 1])))
                            for r in rhythm if rng.random() < density + 0.35]
        deg = prog[bar % len(prog)]
        for i, (r, tone, step) in enumerate(phrases[key]):
            d = deg + 2 * tone
            if r % 1:
                d += step
            if sec == "A2" and i == len(phrases[key]) - 1:
                d += 2
            notes.append(((bar * 4 + r) * beat, deg_to_midi(d)))
    return notes


def track(name, bpm, root, scale, prog, bars, lead, style, seed, room=1.6):
    rng = np.random.default_rng(seed)
    beat = 60 / bpm
    m = Mix(bars * 4 * beat)
    for bar in range(bars):
        t0 = bar * 4 * beat
        deg = prog[bar % len(prog)]
        ch = chord(root + 12, scale, deg)
        bass_root = root - 12 + scale[deg % 7]
        m.add(pad([mtof(n) for n in ch], 4 * beat + 0.4, 0.8), t0, 0, 1, 0.5)
        # arps / comping
        if style in ("calm", "menu"):
            for i in range(8):
                n = ch[[0, 1, 2, 1, 0, 2, 1, 2][i]] + 12
                m.add(marimba(mtof(n), 0.7, 0.45 if i % 2 else 0.6), t0 + i * beat / 2, -0.3 + 0.2 * (i % 3), 0.55)
        elif style == "island":
            for i in range(4):
                for n, p in zip(ch, (-0.4, 0, 0.4)):
                    m.add(pluck(mtof(n + 12), 0.25, 0.5), t0 + (i + 0.5) * beat + 0.008 * p, p, 0.5)
        elif style == "adventure":
            for i in range(8):
                n = ch[i % 3] + (12 if i in (3, 7) else 0)
                m.add(pluck(mtof(n), 0.3, 0.7, 0.6), t0 + i * beat / 2, 0.25, 0.6)
        elif style == "rush":
            for i in range(16):
                n = ch[[0, 2, 1, 2][i % 4]] + 12
                m.add(marimba(mtof(n), 0.3, 0.5), t0 + i * beat / 4, 0.3, 0.45)
        # bass
        if style == "rush":
            for i in range(8):
                m.add(bass(mtof(bass_root + (12 if i % 4 == 3 else 0)), beat / 2, 0.9), t0 + i * beat / 2, 0, 0.8, 0.05)
        elif style == "island":
            for r in (0, 1.5, 2, 3.5):
                m.add(bass(mtof(bass_root + (7 if r == 1.5 else 0)), beat * 0.9, 0.9), t0 + r * beat, 0, 0.8, 0.05)
        else:
            for r in (0, 2) if style != "adventure" else (0, 1.5, 2, 3):
                m.add(bass(mtof(bass_root), beat * 1.8, 0.85), t0 + r * beat, 0, 0.75, 0.05)
        # drums
        for b in range(4):
            tb = t0 + b * beat
            if style == "menu":
                m.add(shaker(0.5), tb + beat / 2, 0.4, 0.6)
                continue
            if style == "rush" or (style != "island" and b in (0, 2)) or (style == "island" and b == 2):
                m.add(kick(0.9), tb, 0, 0.9, 0.05)
            if b in (1, 3):
                m.add(clap(0.7) if style in ("calm", "island") else snare(0.8, b), tb, 0.1, 0.6, 0.3)
            for h in range(2 if style != "rush" else 4):
                m.add(hat(0.6 if h % 2 else 0.35, open_=(style == "rush" and h == 2)), tb + h * beat / (2 if style != "rush" else 4), -0.35, 0.5, 0.1)
            if style in ("calm", "island"):
                m.add(shaker(0.4, b), tb + beat * 0.75, 0.45, 0.6)
        if style == "adventure" and bar % 4 == 3:
            for i, f in enumerate((110, 98, 82)):
                m.add(tom(f, 0.8), t0 + (3 + i / 3) * beat, -0.2 + i * 0.2, 0.7)
        if bar % 4 == 3 and style == "rush":
            m.add(cymbal(4 * beat, 0.6, True), t0, 0, 0.6)
        if bar % 8 == 0 and style in ("rush", "adventure", "island"):
            m.add(cymbal(2.5, 0.5), t0, 0.2, 0.5)
    for when, n in melody(rng, scale, root, prog, bars, beat, 0.55 if style == "menu" else 0.65):
        if lead == "marimba":
            m.add(marimba(mtof(n), 1.0, 0.9), when, 0.1, 0.9)
        elif lead == "steel":
            m.add(steel(mtof(n), 1.2, 0.9), when, 0.1, 0.9)
        elif lead == "brass":
            m.add(brass(mtof(n - 12), beat * 0.9, 0.8), when, 0.05, 0.9)
    write(name, m.render(room), trim=False)


def tension():
    bpm, bars = 120, 16
    beat = 60 / bpm
    m = Mix(bars * 4 * beat)
    for b in range(bars * 4):
        tb = b * beat
        t = tt(0.3)
        m.add(np.sin(TAU * 52 * t) * np.exp(-t * 9), tb, 0, 0.9, 0.0)
        for h in range(4):
            m.add(hat(0.7 if h % 2 else 0.4, seed=10 + h), tb + h * beat / 4, 0.3 if h % 2 else -0.3, 0.6, 0.1)
    for bar in range(0, bars, 2):
        t = tt(1.2)
        ping = np.sin(TAU * 1240 * t) * np.exp(-t * 4)
        m.add(ping, bar * 4 * beat + 2 * beat, 0.5, 0.35, 0.8)
    for bar in range(0, bars, 4):
        d = 4 * 4 * beat
        t = tt(d)
        rise = filt(noise(d, 50 + bar), "band", [400, 2500]) * (t / d) ** 2 * 0.25
        m.add(rise, bar * 4 * beat, 0, 0.7, 0.3)
    write("tension", m.render(1.2), trim=False)


def ocean():
    dur = 24.0
    t = tt(dur)
    n = np.cumsum(noise(dur, 70)) * 0.02
    n = filt(n - filt(n, "low", 0.5), "low", 900)
    swell = np.zeros_like(t)
    for c in (2.0, 7.5, 12.5, 18.5):
        swell += np.exp(-((t - c) ** 2) / 3.0)
    swell = swell + np.roll(swell, -int(dur * SR)) + 0.35
    hiss = filt(noise(dur, 71), "band", [1500, 5000]) * swell * 0.15
    y = n * swell + hiss
    x = 2 * SR
    y[:x] = y[:x] * np.linspace(0, 1, x) + y[-x:] * np.linspace(1, 0, x)
    y = y[:-x]
    y = y / np.max(np.abs(y)) * 0.8
    write("ocean", np.stack([y, np.roll(y, 1500)], axis=1), trim=False)


# ---------------------------------------------------------------- stingers & sfx

def stingers():
    m = Mix(3.0)
    for i, n in enumerate([72, 76, 79, 84]):
        m.add(steel(mtof(n), 1.5), i * 0.11, -0.3 + 0.2 * i, 0.9)
    for n in (72, 76, 79, 84, 88):
        m.add(bell(mtof(n), 2.5, 0.5), 0.5, 0, 0.6)
    m.add(cymbal(0.5, 0.6, True), 0.0, 0, 0.5)
    m.add(cymbal(2.0, 0.5), 0.5, 0, 0.5)
    m.add(kick(), 0.5, 0, 0.8)
    write("win", m.render(2.0, loop=False))

    m = Mix(2.6)
    for i, n in enumerate([67, 66, 65, 61]):
        m.add(brass(mtof(n - 12), 0.32 if i < 3 else 1.1, 0.8), i * 0.34, 0, 0.9)
    t = tt(1.5)
    m.add(np.sin(TAU * np.cumsum(60 * np.exp(-t * 0.8)) / SR) * np.exp(-t * 2.5), 1.0, 0, 0.9)
    write("lose", m.render(1.8, loop=False))

    m = Mix(2.6)
    m.add(brass(mtof(55), 0.45, 0.9), 0.0, -0.2, 1.0)
    m.add(brass(mtof(62), 1.2, 1.0), 0.45, 0.2, 1.0)
    m.add(bell(mtof(86), 2.0, 0.6), 0.45, 0.3, 0.6)
    m.add(cymbal(1.8, 0.5), 0.45, 0, 0.5)
    write("newship", m.render(2.0, loop=False))

    m = Mix(2.2)
    for i, n in enumerate([79, 83, 86, 91, 95]):
        m.add(bell(mtof(n), 1.5, 0.6), i * 0.07, -0.4 + 0.2 * i, 0.7)
    m.add(cymbal(0.6, 0.5, True), 0.0, 0, 0.5)
    write("reward", m.render(2.0, loop=False))

    m = Mix(1.6)
    m.add(bell(mtof(81), 1.4, 0.8), 0.05, -0.2, 0.8)
    m.add(bell(mtof(81), 1.4, 0.8), 0.32, 0.2, 0.8)
    write("start", m.render(1.4, loop=False))


def sfx():
    def mono(sig, room=0.8, verb=0.2, dur=None):
        m = Mix(dur or len(sig) / SR + 0.05, tail=room)
        m.add(sig, 0, 0, 1, verb)
        out = m.dry + reverb(m.buf, room)
        return master(out, 0.85).mean(axis=1)

    write("click", mono(marimba(1568, 0.08, 1.0), verb=0.0), False)
    s = np.concatenate([pluck(mtof(88), 0.07), pluck(mtof(93), 0.15)])
    write("select", mono(s, verb=0.1), False)
    write("link", mono(bell(1046, 0.6) + 0.6 * bell(1568, 0.6), verb=0.35), False)
    t = tt(0.16)
    bloop = np.sin(TAU * np.cumsum(620 * np.exp(-t * 9) + 180) / SR) * np.exp(-t * 14)
    d = bell(880, 1.0)
    d[: len(bloop)] += 0.7 * bloop
    write("dock", mono(d, verb=0.3), False)
    t = tt(1.4)
    boom = np.sin(TAU * np.cumsum(70 * np.exp(-t * 1.5) + 30) / SR) * np.exp(-t * 3)
    burst = filt(noise(1.4, 80), "low", 2500) * np.exp(-t * 4)
    clank = sum(np.sin(TAU * f * t) * np.exp(-t * 9) for f in (523, 1307, 2211)) * 0.3
    splash = filt(noise(1.4, 81), "band", [600, 4000]) * np.exp(-((t - 0.35) ** 2) / 0.05) * 0.5
    write("crash", mono(boom + burst + clank + splash, verb=0.25), False)
    t = tt(0.9)
    write("warning", mono(np.sin(TAU * 1240 * t) * np.exp(-t * 5) * 0.8, room=1.5, verb=0.6), False)
    write("horn_big", mono(brass(92, 1.5, 0.9) + 0.6 * brass(46, 1.5, 0.7), verb=0.4), False)
    toot = brass(330, 0.18, 1.0)
    write("horn_small", mono(np.concatenate([toot, np.zeros(int(0.07 * SR)), toot]), verb=0.3), False)
    buzz = np.sign(np.sin(TAU * 140 * tt(0.12))) * 0.3
    write("error", mono(np.concatenate([buzz, np.zeros(2000), buzz]), verb=0.05), False)
    t = tt(1.0)
    wn = noise(1.0, 90)
    chunks = np.array_split(wn, 20)
    sweep = np.concatenate([filt(c, "band", [300 + 150 * i, 900 + 300 * i]) for i, c in enumerate(chunks)])
    write("whoosh", mono(sweep * np.sin(np.pi * t) ** 2 * 0.8 + 0.3 * bell(1318, 1.0, 0.4), verb=0.4), False)
    t = tt(0.9)
    sp = filt(noise(0.9, 91), "low", 1800) * np.exp(-t * 5)
    for i in range(6):
        bt = tt(0.08)
        b = np.sin(TAU * np.cumsum(np.linspace(500 + 90 * i, 1200 + 90 * i, len(bt))) / SR) * np.exp(-bt * 30) * 0.4
        s0 = int((0.15 + i * 0.09) * SR)
        sp[s0:s0 + len(b)] += b
    write("splash", mono(sp, verb=0.3), False)
    write("star", mono(bell(1760, 0.7, 0.7) + bell(2637, 0.7, 0.4), verb=0.35), False)
    calls = []
    for i, (f0, f1) in enumerate([(1900, 1250), (2000, 1300), (1800, 1200)]):
        t = tt(0.32)
        f = np.linspace(f0, f1, len(t)) * (1 + 0.03 * np.sin(TAU * 28 * t))
        ph = TAU * np.cumsum(f) / SR
        c = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)) * np.sin(np.pi * t / 0.32) ** 1.5
        calls += [c, np.zeros(int((0.12 + 0.05 * i) * SR))]
    write("seagull", mono(filt(np.concatenate(calls), "band", [900, 6000]) * 0.6, verb=0.3), False)


if __name__ == "__main__":
    track("menu", 92, 55, MAJOR, [0, 5, 3, 4], 16, "steel", "menu", 1, 2.0)
    track("sea1", 120, 60, MAJOR, [0, 4, 5, 3], 16, "marimba", "calm", 2)
    track("sea2", 120, 53, MAJOR, [3, 4, 2, 5], 16, "steel", "island", 3)
    track("sea3", 120, 57, MINOR, [0, 5, 2, 6], 16, "brass", "adventure", 4)
    track("rush", 120, 50, MINOR, [0, 6, 5, 6], 16, "steel", "rush", 5, 1.2)
    tension()
    ocean()
    stingers()
    sfx()
