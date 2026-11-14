#!/usr/bin/env python3
"""Sonidos sintéticos (provisorios) de animales: perros y jabalíes.

Todo armado con osciladores, ruido y filtros (sin grabaciones ni voces de terceros), así
que no tiene problemas de licencia; igual son de prueba hasta tener audio real (F8).

Escribe assets/audio/animals/<especie>_<sonido>_<n>.wav
"""
import os
import wave

import numpy as np
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'audio', 'animals')
SR = 22050
rng = np.random.default_rng(11)


def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def env_ad(n, a, d_curve=3.0):
    """Envolvente: ataque `a` (s) y caída exponencial hasta el final."""
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na)
    e[na:] = np.exp(-d_curve * np.linspace(0, 1, n - na))
    return e


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype='band')
    return signal.lfilter(b, a, x)


def lowpass(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), btype='low')
    return signal.lfilter(b, a, x)


def pulses(f0, dur, harsh=1.0):
    """Tren de pulsos glotales con tono variable f0 (array o número): voz animal."""
    n = int(dur * SR)
    f = np.broadcast_to(np.asarray(f0, dtype=float), (n,)) if np.ndim(f0) == 0 else np.interp(
        np.linspace(0, 1, n), np.linspace(0, 1, len(f0)), f0)
    ph = np.cumsum(f / SR)
    saw = 2.0 * (ph - np.floor(ph)) - 1.0
    # Más "áspero" = más armónicos y algo de jitter
    jit = rng.normal(0, 0.04 * harsh, n)
    return np.tanh((saw + jit) * (1.0 + 2.0 * harsh))


def formants(x, fs):
    return sum(bandpass(x, f * 0.8, f * 1.25) * g for f, g in fs)


def finish(x, peak=0.9):
    x = x - np.mean(x)
    m = np.abs(x).max() + 1e-9
    x = x / m * peak
    f = min(220, len(x) // 6)
    x[-f:] *= np.linspace(1, 0, f)
    x[:20] *= np.linspace(0, 1, 20)
    return x


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def silence(d):
    return np.zeros(int(d * SR))


# --- Perro -----------------------------------------------------------------------------

def dog_bark(size):
    """Ladrido: golpe de voz que sube y cae, con mucho ruido de soplo. size 0 chico–1 grande."""
    dur = rng.uniform(0.13, 0.22)
    n = int(dur * SR)
    base = np.interp(size, [0, 1], [620, 300]) * rng.uniform(0.9, 1.1)
    f0 = np.concatenate([np.linspace(base * 0.8, base * 1.15, n // 4), np.linspace(base * 1.15, base * 0.7, n - n // 4)])
    v = pulses(f0, dur, 1.4)
    noise = rng.normal(0, 1, n)
    x = formants(v, [(base * 2.2, 1.0), (1500 - size * 400, 0.8), (2900, 0.35)]) + bandpass(noise, 600, 3500) * 0.5
    return x * env_ad(n, 0.008, 4.5)


def dog_barks(size, k):
    out = []
    for i in range(k):
        out.append(dog_bark(size))
        out.append(silence(rng.uniform(0.09, 0.22)))
    return finish(np.concatenate(out))


def dog_growl():
    dur = rng.uniform(0.9, 1.5)
    n = int(dur * SR)
    t = t_of(dur)
    f0 = rng.uniform(85, 120) * (1 + 0.06 * np.sin(2 * np.pi * 1.3 * t))
    v = pulses(f0, dur, 2.5)
    # Rugosidad: modulación de amplitud rápida (la "vibración" del gruñido)
    am = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * rng.uniform(24, 34) * t)) * rng.uniform(0.6, 1.0, n) ** 0.2
    x = formants(v * am, [(380, 1.0), (900, 0.6), (2100, 0.2)]) + lowpass(rng.normal(0, 1, n), 900) * 0.25
    e = np.minimum(1, t / 0.15) * np.minimum(1, (dur - t) / 0.2)
    return finish(x * e, 0.75)


def dog_yelp():
    dur = rng.uniform(0.22, 0.34)
    n = int(dur * SR)
    f0 = np.concatenate([np.linspace(700, 1350, n // 3), np.linspace(1350, 650, n - n // 3)]) * rng.uniform(0.9, 1.1)
    v = pulses(f0, dur, 0.7)
    x = formants(v, [(1400, 1.0), (2700, 0.5)]) + bandpass(rng.normal(0, 1, n), 1500, 4000) * 0.15
    return finish(x * env_ad(n, 0.01, 2.5))


def dog_whine():
    dur = rng.uniform(0.7, 1.1)
    n = int(dur * SR)
    t = t_of(dur)
    f0 = rng.uniform(750, 950) * (1 + 0.08 * np.sin(2 * np.pi * 5 * t)) * np.linspace(1.05, 0.85, n)
    ph = np.cumsum(f0 / SR)
    x = np.sin(2 * np.pi * ph) + 0.25 * np.sin(4 * np.pi * ph) + bandpass(rng.normal(0, 1, n), 800, 3000) * 0.12
    e = np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.3)
    return finish(x * e, 0.55)


def dog_pant():
    out = []
    for i in range(rng.integers(3, 6)):
        d = rng.uniform(0.12, 0.18)
        nn = int(d * SR)
        out.append(bandpass(rng.normal(0, 1, nn), 900, 3200) * env_ad(nn, 0.03, 2.0))
        out.append(silence(rng.uniform(0.07, 0.12)))
    return finish(np.concatenate(out), 0.4)


# --- Jabalí ----------------------------------------------------------------------------

def boar_grunt():
    """Gruñido corto y nasal: pulsos bajos, de a 1–3."""
    out = []
    for i in range(rng.integers(1, 4)):
        dur = rng.uniform(0.12, 0.26)
        n = int(dur * SR)
        f0 = np.linspace(rng.uniform(95, 130), rng.uniform(70, 90), n)
        v = pulses(f0, dur, 2.0)
        x = formants(v, [(320, 1.0), (750, 0.7), (1700, 0.25)]) + lowpass(rng.normal(0, 1, n), 1200) * 0.35
        out.append(x * env_ad(n, 0.02, 2.2))
        out.append(silence(rng.uniform(0.06, 0.2)))
    return finish(np.concatenate(out), 0.8)


def boar_squeal():
    dur = rng.uniform(0.7, 1.2)
    n = int(dur * SR)
    t = t_of(dur)
    f0 = np.interp(t, [0, 0.1, dur * 0.6, dur], [900, 1500, 1300, 800]) * (1 + 0.04 * np.sin(2 * np.pi * 9 * t))
    v = pulses(f0, dur, 2.5)
    x = formants(v, [(1600, 1.0), (3000, 0.6), (4200, 0.25)]) + bandpass(rng.normal(0, 1, n), 1200, 5000) * 0.4
    e = np.minimum(1, t / 0.04) * np.minimum(1, (dur - t) / 0.25)
    return finish(x * e)


def boar_snort():
    dur = rng.uniform(0.18, 0.3)
    n = int(dur * SR)
    x = bandpass(rng.normal(0, 1, n), 500, 2500) + lowpass(rng.normal(0, 1, n), 300) * 0.6
    return finish(x * env_ad(n, 0.015, 3.0), 0.7)


def main():
    for i in range(6):
        save(f'dog_bark_{i}', dog_barks(rng.uniform(0.2, 0.9), int(rng.integers(1, 4))))
    for i in range(3):
        save(f'dog_growl_{i}', dog_growl())
    for i in range(4):
        save(f'dog_yelp_{i}', dog_yelp())
    for i in range(3):
        save(f'dog_whine_{i}', dog_whine())
    for i in range(2):
        save(f'dog_pant_{i}', dog_pant())
    for i in range(6):
        save(f'boar_grunt_{i}', boar_grunt())
    for i in range(3):
        save(f'boar_squeal_{i}', boar_squeal())
    for i in range(3):
        save(f'boar_snort_{i}', boar_snort())
    print('ok', len(os.listdir(OUT)))


if __name__ == '__main__':
    main()
