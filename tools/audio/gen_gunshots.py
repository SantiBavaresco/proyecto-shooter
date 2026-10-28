"""Genera los disparos por calibre (WAV 44.1 kHz estéreo) para Medoreador.

Síntesis "física" aproximada, sin muestras externas:
  1. Onda de presión del estampido (Friedlander: subida instantánea, caída y fase negativa).
  2. Ráfaga de gases: ruido de banda ancha muy corto (el "crack" del estampido).
  3. Cuerpo: ruido grave + tono que cae (el "boom" que se siente en el pecho).
  4. Crack supersónico (calibres de fusil): ruido agudo de menos de un milisegundo.
  5. Saturación suave (como un micrófono que se pasa con un disparo).
  6. Rebote en el suelo, cola de reverberación que se oscurece y ecos lejanos.
Cada calibre sale con 3 variantes (semillas y parámetros apenas distintos).

Uso: python3 tools/audio/gen_gunshots.py  (escribe en assets/audio/weapons/)
"""
import os
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "weapons")

# energía (0..1), cuerpo (Hz), crack supersónico (0..1), brillo (Hz), cola (s), golpe (0..1)
CALIBERS = {
    "22lr":    dict(energy=0.18, body=230.0, crack=0.35, bright=7000.0, tail=0.7, punch=0.5),
    "9x19":    dict(energy=0.48, body=140.0, crack=0.25, bright=5200.0, tail=1.1, punch=0.8),
    "9x18":    dict(energy=0.42, body=150.0, crack=0.2, bright=5000.0, tail=1.0, punch=0.8),
    "45acp":   dict(energy=0.55, body=105.0, crack=0.08, bright=3600.0, tail=1.1, punch=1.0),
    "545x39":  dict(energy=0.75, body=118.0, crack=1.0, bright=8000.0, tail=1.5, punch=0.8),
    "556x45":  dict(energy=0.78, body=122.0, crack=1.0, bright=8500.0, tail=1.5, punch=0.8),
    "762x39":  dict(energy=0.85, body=92.0, crack=0.8, bright=6200.0, tail=1.6, punch=0.95),
    "762x51":  dict(energy=1.0, body=76.0, crack=1.0, bright=6800.0, tail=1.9, punch=1.0),
    "762x54r": dict(energy=1.0, body=72.0, crack=1.0, bright=6500.0, tail=1.9, punch=1.0),
    "765x53":  dict(energy=0.98, body=74.0, crack=1.0, bright=6500.0, tail=1.9, punch=1.0),
    "12g":     dict(energy=1.0, body=58.0, crack=0.0, bright=3000.0, tail=2.1, punch=1.15),
}
VARIANTS = 3


def bp(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45)
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR * 0.45), btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def delay(x, sec, gain):
    d = int(sec * SR)
    y = np.zeros_like(x)
    if d < len(x):
        y[d:] = x[: len(x) - d] * gain
    return y


def shot(p, rng):
    e = p["energy"]
    tail = p["tail"]
    n = int(SR * (tail + 0.45))
    t = np.arange(n) / SR
    # 1) Onda de presión (Friedlander): más larga cuanto más energía
    T = 0.0005 + 0.0013 * e
    fr = (1.0 - t / T) * np.exp(-1.6 * t / T)
    fr[t > 14 * T] = 0.0
    blast = lp(fr, 9000.0) * 1.2
    # 2) Ráfaga de gases de banda ancha (muy corta)
    tau_b = 0.004 + 0.012 * e
    env_b = (1.0 - np.exp(-t / 0.00015)) * np.exp(-t / tau_b)
    burst = bp(rng.standard_normal(n), 120.0, p["bright"]) * env_b * 1.6
    # 3) Cuerpo grave: ruido grave + tono que cae
    tau_c = 0.015 + 0.04 * e
    env_c = (1.0 - np.exp(-t / 0.0006)) * np.exp(-t / tau_c)
    body_noise = lp(rng.standard_normal(n), p["body"] * 3.5, 4) * env_c * 2.4
    f = p["body"] * (0.65 + 0.35 * np.exp(-t / 0.04))
    phase = 2 * np.pi * np.cumsum(f) / SR
    body_tone = np.sin(phase) * np.exp(-t / (0.02 + 0.03 * e)) * 0.6 * p["punch"]
    # 4) Crack supersónico
    crack = hp(rng.standard_normal(n), 2500.0, 2) * np.exp(-t / 0.0007) * 2.2 * p["crack"]
    dry = blast + burst + body_noise * p["punch"] + body_tone + crack
    dry /= np.max(np.abs(dry)) + 1e-9
    # 5) Saturación suave: más energía, más "aplastado"
    drive = 1.4 + 1.6 * e
    dry = np.tanh(dry * drive) / np.tanh(drive)
    # 6) Rebote en el suelo (pocos ms) y ambiente
    ground = lp(delay(dry, 0.0035 + rng.uniform(0, 0.0015), 0.45), 2500.0)
    near = dry + ground
    out = []
    for ch in range(2):
        r = np.random.default_rng(rng.integers(1 << 30))
        # Cola: dos bandas, la aguda muere antes (el sonido se oscurece al apagarse)
        onset = 1.0 - np.exp(-np.maximum(t - 0.006, 0) / 0.02)
        dark = lp(r.standard_normal(n), 700.0, 2) * np.exp(-t * 6.9 / tail)
        brite = bp(r.standard_normal(n), 900.0, 5000.0) * np.exp(-t * 6.9 / (tail * 0.35))
        rev = (dark * 1.5 + brite * 0.5) * onset * (0.09 + 0.07 * e)
        # Ecos de edificios / árboles lejanos
        e1 = lp(delay(near, rng.uniform(0.16, 0.24) + ch * 0.011, 0.16), 1600.0)
        e2 = lp(delay(near, rng.uniform(0.36, 0.5) - ch * 0.017, 0.07), 1000.0)
        out.append(near + rev + e1 + e2)
    y = np.stack(out, axis=1)
    # Fundido final y normalización a −1 dBFS
    fade = int(0.08 * SR)
    y[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    y /= np.max(np.abs(y)) + 1e-9
    return y * 0.89


def write_wav(path, y):
    data = (np.clip(y, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, p in CALIBERS.items():
        for v in range(VARIANTS):
            rng = np.random.default_rng(1000 + v * 7919 + sum(map(ord, key)))
            q = dict(p)
            q["body"] *= rng.uniform(0.94, 1.06)
            q["bright"] *= rng.uniform(0.9, 1.1)
            q["tail"] *= rng.uniform(0.92, 1.08)
            write_wav(os.path.join(OUT, "shot_%s_%d.wav" % (key, v + 1)), shot(q, rng))
        print("ok", key)


if __name__ == "__main__":
    sys.exit(main())
