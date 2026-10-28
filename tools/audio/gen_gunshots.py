"""Genera los disparos por calibre (WAV 44.1 kHz estéreo) para Medoreador.

Síntesis "física" aproximada, sin muestras externas:
  1. Onda de presión del estampido (Friedlander: subida instantánea, caída y fase negativa).
  2. Ráfaga de gases: ruido de banda ancha muy corto (el "crack" del estampido).
  3. Cuerpo: ruido grave + tono que cae (el "boom" que se siente en el pecho).
  4. Crack supersónico (calibres de fusil): ruido agudo de menos de un milisegundo.
  5. Saturación suave (como un micrófono que se pasa con un disparo).
  6. Retumbe grave que rueda (fusiles largos, más en los de cerrojo) y una cola de
     ambiente oscura y corta (sin ecos: repetían el golpe y sonaba a pandereta).
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

# energía (0..1), cuerpo (Hz), crack supersónico (0..1), brillo (Hz, techo del estampido),
# pop (0..1, golpe seco de medios de las pistolas), retumbe (s, la cola grave que rueda
# a lo lejos: fusiles largos y más los de cerrojo), cola (s, ambiente oscuro)
CALIBERS = {
    "22lr":    dict(energy=0.2, body=260.0, crack=0.15, bright=3800.0, pop=1.0, roll=0.0, tail=0.35),
    "9x19":    dict(energy=0.5, body=150.0, crack=0.1, bright=4200.0, pop=1.0, roll=0.06, tail=0.55),
    "9x18":    dict(energy=0.45, body=160.0, crack=0.08, bright=4000.0, pop=1.0, roll=0.05, tail=0.5),
    "45acp":   dict(energy=0.6, body=110.0, crack=0.0, bright=3400.0, pop=0.9, roll=0.08, tail=0.6),
    "545x39":  dict(energy=0.75, body=118.0, crack=0.8, bright=7000.0, pop=0.4, roll=0.22, tail=0.9),
    "556x45":  dict(energy=0.78, body=122.0, crack=0.85, bright=7500.0, pop=0.4, roll=0.22, tail=0.9),
    "762x39":  dict(energy=0.85, body=95.0, crack=0.7, bright=6000.0, pop=0.5, roll=0.3, tail=1.0),
    "762x51":  dict(energy=1.0, body=78.0, crack=0.9, bright=6500.0, pop=0.5, roll=0.45, tail=1.2),
    "308":     dict(energy=1.0, body=74.0, crack=0.9, bright=6500.0, pop=0.5, roll=0.75, tail=1.5),
    "762x54r": dict(energy=1.0, body=72.0, crack=0.9, bright=6300.0, pop=0.5, roll=0.6, tail=1.4),
    "765x53":  dict(energy=1.0, body=72.0, crack=0.9, bright=6300.0, pop=0.5, roll=0.8, tail=1.6),
    "12g":     dict(energy=1.0, body=58.0, crack=0.0, bright=3000.0, pop=0.6, roll=0.5, tail=1.3),
}
VARIANTS = 3


def bp(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45)
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR * 0.45), btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def shot(p, rng):
    e = p["energy"]
    tail = p["tail"]
    roll = p["roll"]
    n = int(SR * (max(tail, roll * 3.0) + 0.3))
    t = np.arange(n) / SR
    # 1) Onda de presión (Friedlander): el golpe principal
    T = 0.0006 + 0.0014 * e
    fr = (1.0 - t / T) * np.exp(-1.6 * t / T)
    fr[t > 14 * T] = 0.0
    blast = lp(fr, p["bright"], 2) * 1.4
    # 2) Gases: ruido corto, sin agudos sueltos (eso sonaba a pandereta)
    tau_b = 0.003 + 0.008 * e
    env_b = (1.0 - np.exp(-t / 0.0002)) * np.exp(-t / tau_b)
    burst = bp(rng.standard_normal(n), 150.0, p["bright"], 3) * env_b * 1.1
    # 3) Pop: golpe seco de medios (300-1800 Hz), lo que da "cuerpo" a una pistola
    env_p = (1.0 - np.exp(-t / 0.0003)) * np.exp(-t / 0.006)
    pop = bp(rng.standard_normal(n), 300.0, 1800.0, 2) * env_p * 2.0 * p["pop"]
    # 4) Cuerpo grave: ruido grave + tono que cae
    tau_c = 0.018 + 0.04 * e
    env_c = (1.0 - np.exp(-t / 0.0008)) * np.exp(-t / tau_c)
    body_noise = lp(rng.standard_normal(n), p["body"] * 3.0, 4) * env_c * 2.4
    f = p["body"] * (0.65 + 0.35 * np.exp(-t / 0.04))
    phase = 2 * np.pi * np.cumsum(f) / SR
    body_tone = np.sin(phase) * np.exp(-t / (0.012 + 0.035 * e)) * 0.55 * e
    # 5) Crack supersónico (muy corto)
    crack = hp(rng.standard_normal(n), 3000.0, 2) * np.exp(-t / 0.0005) * 1.6 * p["crack"]
    dry = blast + burst + pop + body_noise + body_tone + crack
    dry /= np.max(np.abs(dry)) + 1e-9
    drive = 1.4 + 1.4 * e
    dry = np.tanh(dry * drive) / np.tanh(drive)
    out = []
    for ch in range(2):
        r = np.random.default_rng(rng.integers(1 << 30))
        y = dry.copy()
        # 6) Retumbe: grave que rueda (sube un poco y se apaga lento, con vaivén)
        if roll > 0:
            wob = 1.0 + 0.35 * lp(r.standard_normal(n), 6.0, 2) / 0.05
            wob = np.clip(wob, 0.3, 1.8)
            env_r = (1.0 - np.exp(-t / 0.03)) * np.exp(-t / roll)
            rum = lp(r.standard_normal(n), 220.0, 4) * env_r * wob
            rum = rum / (np.max(np.abs(rum)) + 1e-9) * (0.16 + 0.12 * e)
            y += rum
        # 7) Ambiente: cola oscura y corta, sin ecos que repitan el golpe
        onset = 1.0 - np.exp(-np.maximum(t - 0.008, 0) / 0.025)
        dark = lp(r.standard_normal(n), 520.0, 2) * np.exp(-t * 6.9 / tail) * onset
        y += dark * (0.035 + 0.03 * e)
        out.append(y)
    y = np.stack(out, axis=1)
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
