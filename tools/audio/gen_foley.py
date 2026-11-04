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


def soft_thud(rng, f0, dur, gain):
    """Golpe sordo: tono grave que cae un poco + ruido grave, sin ataque duro."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + 0.35 * np.exp(-t / 0.012))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    noise = lp(rng.standard_normal(n), f0 * 6, 4)
    e = env(n, 0.004, dur / 5)
    return (tone * 0.6 + noise * 0.6) * e * gain


def tap(rng, lo, hi, dur, gain):
    """Contacto corto de la suela (ruido filtrado con caída rápida, ataque suave)."""
    n = int(dur * SR)
    return bp(rng.standard_normal(n), lo, hi, 3) * env(n, 0.0025, dur / 4) * gain


def resonance(rng, freqs, dur, gain, q=0.25):
    """Cuerpo hueco (madera, chapa): parciales graves que se apagan rápido."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        f2 = f * rng.uniform(0.96, 1.04)
        out += np.sin(2 * np.pi * f2 * t + rng.uniform(0, 6.28)) * np.exp(-t / (dur * q * rng.uniform(0.7, 1.2)))
    return out / max(len(freqs), 1) * env(n, 0.003, dur) * gain


def step(surface, rng):
    dur = 0.3
    buf = np.zeros(int(dur * SR))
    toe = rng.uniform(0.065, 0.1)
    k = rng.uniform(0.85, 1.1)
    if surface == "concrete":
        place(buf, soft_thud(rng, 70 * k, 0.09, 0.9), 0.0)
        place(buf, tap(rng, 350, 2200, 0.04, 0.35), 0.002)
        place(buf, tap(rng, 2500, 6000, 0.05, 0.05), 0.004)  # arenilla, muy baja
        place(buf, soft_thud(rng, 95 * k, 0.07, 0.45), toe)
        place(buf, tap(rng, 400, 2600, 0.035, 0.2), toe)
    elif surface == "dirt":
        place(buf, soft_thud(rng, 55 * k, 0.11, 0.8), 0.0)
        place(buf, grains(rng, 22, 0.13, 600, 3000, 0.22), 0.004)
        place(buf, soft_thud(rng, 70 * k, 0.08, 0.35), toe)
        place(buf, grains(rng, 12, 0.1, 700, 3500, 0.16), toe)
    elif surface == "wood":
        place(buf, soft_thud(rng, 90 * k, 0.1, 0.8), 0.0)
        place(buf, resonance(rng, [140, 260, 410], 0.16, 0.35), 0.0)
        place(buf, tap(rng, 500, 2500, 0.03, 0.18), 0.002)
        place(buf, soft_thud(rng, 120 * k, 0.07, 0.4), toe)
    else:  # metal (chapa, rejilla)
        place(buf, soft_thud(rng, 80 * k, 0.08, 0.7), 0.0)
        place(buf, resonance(rng, [310, 640, 1050], 0.22, 0.3), 0.0)
        place(buf, tap(rng, 800, 3500, 0.03, 0.15), 0.002)
        place(buf, resonance(rng, [340, 700], 0.15, 0.15), toe)
    return lp(buf, 5000, 2)


def creak(rng, dur, f_lo, f_hi, rate0, rate1, gain):
    """Crujido de madera/bisagra: tren de impulsos (traba y desliza) que excita
    resonancias de la madera; la frecuencia del tren sube y baja."""
    n = int(dur * SR)
    out = np.zeros(n)
    t = 0.0
    while t < dur:
        u = t / dur
        rate = rate0 + (rate1 - rate0) * np.sin(np.pi * u) + rng.uniform(-4, 4)
        i = int(t * SR)
        if i < n:
            out[i] += rng.uniform(0.5, 1.0)
        t += 1.0 / max(rate, 5.0)
    out = bp(out, f_lo, f_hi, 2) + bp(out, f_lo * 1.9, f_hi * 1.4, 2) * 0.4
    return out * env(n, dur * 0.2, dur * 0.5) * gain


def crate_open(rng):
    buf = np.zeros(int(1.0 * SR))
    place(buf, soft_thud(rng, 110, 0.06, 0.35), 0.0)          # se destraba la tapa
    place(buf, creak(rng, 0.42, 380, 900, 28, 70, 0.9), 0.05)  # bisagra / madera
    place(buf, soft_thud(rng, 75, 0.2, 0.9), 0.5)             # la tapa cae de costado
    place(buf, resonance(rng, [130, 230, 360], 0.25, 0.45), 0.5)
    return lp(buf, 6000)


def box_open(rng):
    buf = np.zeros(int(0.85 * SR))
    for at in [0.0, 0.11]:  # dos trabas: clic sordo
        place(buf, tap(rng, 900, 3500, 0.02, 0.7), at)
        place(buf, resonance(rng, [1100, 1900], 0.05, 0.25), at)
    place(buf, creak(rng, 0.2, 700, 1600, 60, 110, 0.25), 0.2)  # bisagra
    place(buf, soft_thud(rng, 95, 0.12, 0.6), 0.45)
    place(buf, resonance(rng, [260, 540, 910, 1450], 0.35, 0.45), 0.45)  # chapa
    return lp(buf, 6500)


def stash_open(rng):
    buf = np.zeros(int(0.85 * SR))
    # Cierre: dientes a ~200 por segundo, con la mano que acelera y frena
    n = int(0.5 * SR)
    teeth = np.zeros(n)
    t = 0.0
    while t < 0.5:
        rate = 140 + 120 * np.sin(np.pi * t / 0.5)
        i = int(t * SR)
        teeth[i] += rng.uniform(0.4, 1.0)
        t += 1.0 / rate
    teeth = bp(teeth, 1800, 5500, 2) * env(n, 0.04, 0.25)
    place(buf, teeth * 0.8, 0.02)
    # Tela que se abre
    m = int(0.35 * SR)
    rustle = bp(rng.standard_normal(m), 300, 2200, 2) * (0.5 + 0.5 * np.abs(np.sin(np.linspace(0, 9, m))))
    place(buf, rustle * env(m, 0.08, 0.15) * 0.35, 0.45)
    return lp(buf, 7000)


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
    x = x / m * peak  # sin saturar (la saturación los hacía ásperos)
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
            save(f"step_{surf}_{i + 1}", step(surf, rng), 0.7)
    for name, fn in [("crate_open", crate_open), ("box_open", box_open), ("stash_open", stash_open),
                     ("equip", equip), ("pickup_item", pickup_item), ("pickup_weapon", pickup_weapon),
                     ("drop_item", drop_item)]:
        save(name, fn(np.random.default_rng(zlib.crc32(name.encode()))), 0.8)
    print("ok")


if __name__ == "__main__":
    main()
