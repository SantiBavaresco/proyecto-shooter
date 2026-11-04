"""Genera los sonidos de "foley" (WAV 44.1 kHz mono) para Medoreador, sin muestras externas.

  - Pasos por superficie (4 variantes cada uno): hormigón, tierra, madera, metal.
      golpe del talón (grave, corto) + roce de la suela (ruido filtrado según el piso)
      + granos (tierra: crujido de piedritas) o resonancia (madera, metal).
  - Abrir: cajón de madera (crujido + golpe de la tapa), caja metálica (traba + chapa),
    alijo (cierre de bolso + tela).
  - Equipar (tela + hebilla), agarrar un objeto (roce de tela), agarrar un arma
    (golpe metálico + correa), tirar al suelo (golpe sordo).

Uso: python3 tools/audio/gen_foley.py   (escribe en assets/audio/foley/)
"""
import os
import wave
import zlib

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "foley")


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


def thump(rng, f0, dur, gain):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + 0.6 * np.exp(-t / 0.01))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    noise = lp(rng.standard_normal(n), f0 * 3)
    return (tone * 0.7 + noise * 0.5) * env(n, 0.002, dur / 4) * gain


def scuff(rng, lo, hi, dur, gain):
    n = int(dur * SR)
    return bp(rng.standard_normal(n), lo, hi) * env(n, dur * 0.25, dur / 3) * gain


def ring(rng, freqs, dur, gain):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        f2 = f * rng.uniform(0.97, 1.03)
        out += np.sin(2 * np.pi * f2 * t + rng.uniform(0, 6.28)) * np.exp(-t / rng.uniform(dur * 0.15, dur * 0.35))
    return out / max(len(freqs), 1) * gain


def grains(rng, n_grains, dur, lo, hi, gain):
    n = int(dur * SR)
    out = np.zeros(n)
    for _ in range(n_grains):
        g = int(rng.uniform(0.002, 0.006) * SR)
        x = bp(rng.standard_normal(g), lo, hi) * np.hanning(g)
        place(out, x * rng.uniform(0.3, 1.0), rng.uniform(0, dur * 0.7))
    return out * gain


def step(surface, rng):
    dur = 0.32
    buf = np.zeros(int(dur * SR))
    heel = 0.0
    toe = rng.uniform(0.045, 0.07)
    if surface == "concrete":
        place(buf, thump(rng, 70, 0.08, 0.9), heel)
        place(buf, hp(scuff(rng, 1500, 7000, 0.06, 0.35), 900), heel + 0.004)
        place(buf, thump(rng, 95, 0.06, 0.5), toe)
        place(buf, scuff(rng, 2000, 8000, 0.08, 0.25), toe)
    elif surface == "dirt":
        place(buf, thump(rng, 55, 0.1, 0.8), heel)
        place(buf, grains(rng, 28, 0.16, 1200, 6000, 0.55), heel + 0.005)
        place(buf, scuff(rng, 300, 2500, 0.12, 0.35), toe)
        place(buf, grains(rng, 16, 0.12, 1500, 7000, 0.4), toe)
    elif surface == "wood":
        place(buf, thump(rng, 110, 0.1, 0.8), heel)
        place(buf, ring(rng, [190, 340, 520], 0.14, 0.45), heel)
        place(buf, thump(rng, 140, 0.07, 0.45), toe)
        place(buf, scuff(rng, 1200, 5000, 0.06, 0.15), toe)
    else:  # metal
        place(buf, thump(rng, 90, 0.07, 0.6), heel)
        place(buf, ring(rng, [640, 1270, 2210, 3400], 0.28, 0.45), heel)
        place(buf, ring(rng, [700, 1500, 2600], 0.2, 0.25), toe)
        place(buf, scuff(rng, 2500, 9000, 0.05, 0.15), toe)
    return buf


def crate_open(rng):
    buf = np.zeros(int(0.9 * SR))
    # Crujido de la bisagra / madera (tono que sube y baja con rozamiento)
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 240 + 120 * np.sin(2 * np.pi * 3 * t) + rng.uniform(-20, 20)
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3
    creak = bp(creak * (0.6 + 0.4 * rng.standard_normal(n) * 0.2), 300, 2500) * env(n, 0.06, 0.15)
    place(buf, creak * 0.6, 0.0)
    place(buf, thump(rng, 85, 0.18, 0.9), 0.36)
    place(buf, ring(rng, [160, 290, 450], 0.25, 0.4), 0.36)
    place(buf, grains(rng, 10, 0.2, 800, 4000, 0.2), 0.38)
    return buf


def box_open(rng):
    buf = np.zeros(int(0.8 * SR))
    for i, at in enumerate([0.0, 0.09]):  # dos trabas
        place(buf, hp(scuff(rng, 2500, 9000, 0.012, 0.9), 2000), at)
        place(buf, ring(rng, [1800, 3100, 4700], 0.08, 0.35), at)
    place(buf, scuff(rng, 600, 3000, 0.25, 0.25), 0.18)
    place(buf, ring(rng, [420, 880, 1430, 2300], 0.5, 0.5), 0.42)
    place(buf, thump(rng, 120, 0.08, 0.5), 0.42)
    return buf


def stash_open(rng):
    buf = np.zeros(int(0.8 * SR))
    # Cierre: muchos "dientes" seguidos
    for i in range(34):
        g = int(0.004 * SR)
        x = bp(rng.standard_normal(g), 2000, 8000) * np.hanning(g)
        place(buf, x * rng.uniform(0.3, 0.7), 0.02 + i * 0.012 + rng.uniform(0, 0.003))
    place(buf, scuff(rng, 400, 3500, 0.35, 0.35), 0.4)
    return buf


def equip(rng):
    buf = np.zeros(int(0.55 * SR))
    place(buf, scuff(rng, 500, 4000, 0.22, 0.45), 0.0)
    place(buf, scuff(rng, 700, 5000, 0.15, 0.3), 0.18)
    place(buf, ring(rng, [2400, 3900], 0.06, 0.35), 0.3)  # hebilla
    place(buf, hp(scuff(rng, 3000, 9000, 0.01, 0.6), 2500), 0.3)
    return buf


def pickup_item(rng):
    buf = np.zeros(int(0.35 * SR))
    place(buf, scuff(rng, 600, 4500, 0.18, 0.45), 0.0)
    place(buf, thump(rng, 160, 0.05, 0.25), 0.16)
    return buf


def pickup_weapon(rng):
    buf = np.zeros(int(0.6 * SR))
    place(buf, scuff(rng, 500, 3500, 0.2, 0.35), 0.0)
    place(buf, thump(rng, 130, 0.06, 0.6), 0.18)
    place(buf, ring(rng, [900, 1700, 2900, 4200], 0.18, 0.5), 0.18)  # metal contra metal
    place(buf, hp(scuff(rng, 3000, 9000, 0.008, 0.8), 2500), 0.33)  # clic de la correa
    place(buf, ring(rng, [2100, 3600], 0.05, 0.3), 0.33)
    return buf


def drop_item(rng):
    buf = np.zeros(int(0.4 * SR))
    place(buf, thump(rng, 75, 0.12, 0.9), 0.0)
    place(buf, scuff(rng, 300, 2500, 0.1, 0.3), 0.0)
    return buf


def save(name, x, peak=0.8):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1.0
    x = np.tanh(x / m * 1.2) / np.tanh(1.2) * peak
    pcm = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    for surf in ["concrete", "dirt", "wood", "metal"]:
        for i in range(4):
            rng = np.random.default_rng(zlib.crc32(f"{surf}{i}".encode()))
            save(f"step_{surf}_{i + 1}", step(surf, rng), 0.75)
    for name, fn in [("crate_open", crate_open), ("box_open", box_open), ("stash_open", stash_open),
                     ("equip", equip), ("pickup_item", pickup_item), ("pickup_weapon", pickup_weapon),
                     ("drop_item", drop_item)]:
        save(name, fn(np.random.default_rng(zlib.crc32(name.encode()))), 0.8)
    print("ok")


if __name__ == "__main__":
    main()
