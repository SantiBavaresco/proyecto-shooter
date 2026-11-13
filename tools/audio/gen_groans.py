#!/usr/bin/env python3
"""Quejidos sintéticos (provisorios) de los enemigos: el grito al recibir el tiro que
los mata ("death_cry") y los quejidos mientras agonizan en el piso ("groan").

Se arman a mano en MBROLA (fonemas con su curva de tono) y se ensucian con aire,
temblor y un filtro: no son palabras, son ruidos de dolor. Usa las mismas voces que
gen_voices.py y suma las claves a data/audio/voice_lines.json (correr después de
gen_voices.py, que reescribe ese archivo).

Mismo aviso de licencia que las voces: MBROLA no se puede usar en un juego que se
venda; es solo para probar.
"""
import json, os, subprocess, tempfile, wave
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'audio', 'voice')
INDEX = os.path.join(ROOT, 'data', 'audio', 'voice_lines.json')
VOICES = {'v1': 'mb-mx2', 'v2': 'mb-mx1', 'v3': 'mb-vz1'}
SR = 22050

# [(fonema, ms, [(%, Hz), ...]), ...] — tono relativo a 120 Hz (se escala por voz)
CRIES = [
    [('a', 140, [(0, 1.6), (25, 1.85), (100, 1.1)]), ('x', 120, [])],                  # ¡Agh!
    [('a', 220, [(0, 1.9), (15, 2.0), (100, 1.0)])],                                     # ¡Ah!
    [('u', 160, [(0, 1.5), (30, 1.7), (100, 0.95)]), ('x', 90, [])],                    # ¡Ugh!
    [('a', 90, [(0, 1.7), (100, 1.9)]), ('i', 200, [(0, 1.9), (40, 1.7), (100, 0.9)])],  # ¡Ay!
    [('o', 180, [(0, 1.6), (20, 1.8), (100, 1.05)]), ('x', 100, [])],                   # ¡Ogh!
    [('a', 300, [(0, 2.0), (10, 2.1), (60, 1.4), (100, 0.8)])],                          # ¡Aaah!
]
GROANS = [
    [('m', 420, [(0, 0.95), (60, 1.05), (100, 0.85)]), ('a', 650, [(0, 1.0), (30, 1.1), (100, 0.7)])],   # mmmaaah
    [('a', 900, [(0, 1.05), (20, 1.15), (70, 0.9), (100, 0.7)])],                                        # aaaah...
    [('u', 700, [(0, 0.9), (40, 1.0), (100, 0.75)])],                                                    # uuuh
    [('a', 260, [(0, 1.0), (100, 1.1)]), ('i', 420, [(0, 1.1), (100, 0.8)]), ('_', 250, []),
     ('a', 220, [(0, 0.95), (100, 1.0)]), ('i', 380, [(0, 1.0), (100, 0.72)])],                            # ay... ay
    [('m', 800, [(0, 0.85), (50, 0.95), (100, 0.75)])],                                                  # mmmh
    [('o', 500, [(0, 1.0), (30, 1.08), (100, 0.8)]), ('x', 180, [])],                                    # oooh-gh
    [('a', 380, [(0, 1.1), (100, 0.9)]), ('x', 140, []), ('_', 200, []), ('a', 500, [(0, 0.9), (100, 0.68)])],  # agh... aah
]
BASE = {'v1': 118.0, 'v2': 104.0, 'v3': 128.0}


def synth(voice: str, ph: list, base: float) -> np.ndarray:
    x = _synth(voice, ph, base)
    if len(x) < SR * 0.1:
        # A esta voz le falta algún par de fonemas (vz1 no tiene "a-x"): sin la jota
        x = _synth(voice, [q for q in ph if q[0] != 'x'], base)
    return x


def _synth(voice: str, ph: list, base: float) -> np.ndarray:
    lines = ['_ 60']
    for p, ms, curve in ph:
        lines.append(' '.join([p, str(ms)] + [f'{a} {int(base * f)}' for a, f in curve]))
    lines.append('_ 80')
    db = '/usr/share/mbrola/%s/%s' % (voice[3:], voice[3:])
    with tempfile.TemporaryDirectory() as td:
        pp, wp = os.path.join(td, 'x.pho'), os.path.join(td, 'x.wav')
        open(pp, 'w').write('\n'.join(lines) + '\n')
        r = subprocess.run(['mbrola', db, pp, wp], capture_output=True)
        if b'Fatal' in r.stderr or not os.path.exists(wp):
            return np.zeros(0, np.float32)
        w = wave.open(wp)
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    if sr != SR:
        t = np.arange(int(len(x) * SR / sr)) * sr / SR
        x = np.interp(t, np.arange(len(x)), x).astype(np.float32)
    return x


def lowpass(x: np.ndarray, k: float) -> np.ndarray:
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += (v - acc) * k
        y[i] = acc
    return y


def dirty(x: np.ndarray, rng: np.random.Generator, cry: bool, loud: bool) -> np.ndarray:
    x = x / (np.abs(x).max() + 1e-6)
    n = len(x)
    t = np.arange(n) / SR
    env = lowpass(np.abs(x), 0.004)
    env = env / (env.max() + 1e-6)
    # Temblor (de dolor) y aire: más aire en los quejidos
    trem = 1.0 + 0.18 * np.sin(2 * np.pi * rng.uniform(5.0, 8.0) * t) * (0.4 if cry else 1.0)
    breath = lowpass(rng.normal(0, 1, n).astype(np.float32), 0.25) * env * (0.25 if cry else 0.55)
    y = x * trem + breath
    if cry and loud:
        hp = np.concatenate([[0], np.diff(y)])
        y = np.tanh((y + hp * 1.2) * 2.6) / np.tanh(2.6)
    else:
        y = lowpass(y, 0.55 if loud else 0.4)
        y = np.tanh(y * 1.4) / np.tanh(1.4)
    out = y.copy()
    for d, g in ((int(SR * 0.021), 0.15), (int(SR * 0.037), 0.08)):
        out[d:] += y[:-d] * g
    e = np.abs(out) > 0.02
    if e.any():
        i0, i1 = np.argmax(e), len(e) - np.argmax(e[::-1])
        out = out[max(0, i0 - 100):min(len(out), i1 + 600)]
    out = out / (np.abs(out).max() + 1e-6) * (0.95 if loud else 0.7)
    f = min(600, len(out) // 4)
    out[-f:] *= np.linspace(1, 0, f)
    out[:60] *= np.linspace(0, 1, 60)
    return out


def save(path: str, x: np.ndarray) -> None:
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def main() -> None:
    idx = json.load(open(INDEX))
    rng = np.random.default_rng(7)
    for vid, voice in VOICES.items():
        os.makedirs(os.path.join(OUT, vid), exist_ok=True)
        for key, sets in (('death_cry', CRIES), ('groan', GROANS)):
            ok = []
            for n, ph in enumerate(sets):
                x = synth(voice, ph, BASE[vid])
                if len(x) < SR * 0.1:
                    print('sin variante', vid, key, n)
                    continue
                for mode in ('shout', 'talk'):
                    save(os.path.join(OUT, vid, f'{key}_{n}_{mode}.wav'),
                         dirty(x, rng, key == 'death_cry', mode == 'shout'))
                ok.append(n)
            idx['lines'].setdefault(vid, {})[key] = ok
    idx.setdefault('text', {})['death_cry'] = ['(grito)'] * len(CRIES)
    idx['text']['groan'] = ['(quejido)'] * len(GROANS)
    json.dump(idx, open(INDEX, 'w'), ensure_ascii=False, indent=1)
    print('ok')


if __name__ == '__main__':
    main()
