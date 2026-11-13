#!/usr/bin/env python3
"""Voces sintéticas provisorias de los militares (gritos y habla).

Usa eSpeak NG con voces MBROLA latinoamericanas (mx1, mx2, vz1); se instalan con
  apt-get install espeak-ng mbrola mbrola-mx1 mbrola-mx2 mbrola-vz1
Genera, por voz y frase, dos versiones: "shout" (grito, más agudo, rápido y saturado)
y "talk" (hablado, normal). Si MBROLA no tiene algún sonido de una frase (avisa
"unknown"), esa frase se descarta para esa voz.

Salida: assets/audio/voice/<voz>/<clave>_<n>_<shout|talk>.wav y
data/audio/voice_lines.json con las variantes que existen.
"""
import json, os, subprocess, sys, wave
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'audio', 'voice')
INDEX = os.path.join(ROOT, 'data', 'audio', 'voice_lines.json')
VOICES = {'v1': 'mb-mx2', 'v2': 'mb-mx1', 'v3': 'mb-vz1'}
LINES = {
    'contact': ['¡Contacto!', '¡Contacto al frente!', '¡Ahí está!', '¡Lo tengo!', '¡Enemigo a la vista!', '¡Ahí, ahí!', '¡Lo veo!'],
    'cover_me': ['¡Cubrí!', '¡Cubrí que avanzo!', '¡Fuego de cobertura!', '¡Cubrime, cubrime!', '¡Tapalo que paso!', '¡Necesito cobertura!'],
    'covering': ['¡Te cubro!', '¡Cubierto, andá!', '¡Dale, andá!', '¡Andá que te cubro!', '¡Lo tengo tapado, movete!', '¡Ya, ahora!'],
    'moving': ['¡Avanzo!', '¡Me muevo!', '¡Moviendo!', '¡Voy!', '¡Cambio de posición!', '¡Paso!'],
    'reloading': ['¡Recargando!', '¡Cambio cargador!', '¡Recargo, cubrí!', '¡Estoy seco!', '¡Sin balas, recargo!', '¡Cargador!'],
    'grenade_out': ['¡Granada!', '¡Va granada!', '¡Tiro granada!', '¡Granada va!', '¡Ahí te va!'],
    'grenade_incoming': ['¡Granada, al piso!', '¡Cuidado, granada!', '¡Granada, salgan!', '¡Corran, granada!'],
    'smoke': ['¡Humo!', '¡Tiro humo!', '¡Humo, humo!', '¡Pongan humo!'],
    'lost': ['¡Lo perdí!', '¿Dónde está?', 'Lo perdí de vista.', '¿Alguien lo ve?', '¡Se escondió!', 'No lo veo.'],
    'flank': ['¡Lo flanqueo!', '¡Rodeálo!', '¡Voy por el costado!', '¡Lo agarro de costado!', '¡Rodeo por acá!'],
    'man_down': ['¡Hombre abajo!', '¡Le dieron a uno!', '¡Cayó uno!', '¡Lo bajaron!', '¡Herido, herido!'],
    'left': ['¡Está a la izquierda!', '¡Izquierda!', '¡A tu izquierda!', '¡Por la izquierda!'],
    'right': ['¡Está a la derecha!', '¡Derecha!', '¡A tu derecha!', '¡Por la derecha!'],
    'search': ['Revisen la zona.', 'Atentos.', 'Abran los ojos.', 'Busquen bien.', 'Separados, revisen todo.', 'Tiene que estar cerca.'],
    'fall_back': ['¡Replegarse!', '¡Atrás, atrás!', '¡Retirada!', '¡Nos vamos, atrás!'],
    'hold': ['Mantengan la posición.', 'Quietos ahí.', 'Esperen.', 'Nadie se mueve.', 'Aguanten.'],
    'order_cover': ['¡Ustedes, cobertura!', '¡Tiren, tiren!', '¡Fuego, fuego!', '¡No paren de tirar!', '¡Tápenlo!'],
    'order_flank': ['¡Vos, rodeálo!', '¡Por el costado, vamos!', '¡Dos por la derecha!', '¡Rodéenlo!'],
    'jam': ['¡Se me trabó!', '¡Trabado!', '¡No dispara!', '¡Se trabó, cubrime!'],
}
SR = 22050


def synth(voice: str, text: str, shout: bool) -> tuple[np.ndarray, bool]:
    """eSpeak da los fonemas (.pho) y MBROLA los dice. El eSpeak de Ubuntu marca
    vocales "e/" y "o/" que las voces MBROLA no tienen: se cambian por "e" y "o"."""
    import io, re, tempfile
    args = ['espeak-ng', '-v', voice, '-q', '--pho', '-s', '182' if shout else '158', '-p', '64' if shout else '42', text]
    pho = subprocess.run(args, capture_output=True).stdout.decode('utf-8', 'replace')
    pho = re.sub(r'^([aeiou])/', r'\1', pho, flags=re.M)
    db = '/usr/share/mbrola/%s/%s' % (voice[3:], voice[3:])
    with tempfile.TemporaryDirectory() as td:
        pp, wp = os.path.join(td, 'x.pho'), os.path.join(td, 'x.wav')
        open(pp, 'w').write(pho)
        r = subprocess.run(['mbrola', db, pp, wp], capture_output=True)
        bad = b'unknown' in r.stderr or not os.path.exists(wp)
        if bad:
            return np.zeros(1, np.float32), True
        w = wave.open(wp)
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    if sr != SR:
        t = np.arange(int(len(x) * SR / sr)) * sr / SR
        x = np.interp(t, np.arange(len(x)), x).astype(np.float32)
    return x, bad


def process(x: np.ndarray, shout: bool) -> np.ndarray:
    # Recorta silencios
    e = np.abs(x) > 0.01
    if e.any():
        i0, i1 = np.argmax(e), len(e) - np.argmax(e[::-1])
        x = x[max(0, i0 - 200):min(len(x), i1 + 400)]
    x = x / (np.abs(x).max() + 1e-6)
    if shout:
        # Más presencia (realce de agudos) y algo de saturación: suena a grito
        hp = np.concatenate([[0], np.diff(x)])
        x = x + hp * 1.6
        x = np.tanh(x * 2.2) / np.tanh(2.2)
    else:
        x = np.tanh(x * 1.1) / np.tanh(1.1)
    # Pequeña sala (dos ecos cortos) para que no suene "seca" de computadora
    out = x.copy()
    for d, g in ((int(SR * 0.023), 0.18), (int(SR * 0.041), 0.1)):
        out[d:] += x[:-d] * g
    out = out / (np.abs(out).max() + 1e-6) * (0.95 if shout else 0.8)
    fade = min(300, len(out) // 4)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def save(path: str, x: np.ndarray) -> None:
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def main() -> None:
    index = {}
    skipped = []
    for vid, voice in VOICES.items():
        os.makedirs(os.path.join(OUT, vid), exist_ok=True)
        index[vid] = {}
        for key, texts in LINES.items():
            ok = []
            for n, text in enumerate(texts):
                good = True
                clips = {}
                for mode in ('shout', 'talk'):
                    x, bad = synth(voice, text, mode == 'shout')
                    if bad or len(x) < SR * 0.2:
                        good = False
                        break
                    clips[mode] = process(x, mode == 'shout')
                if not good:
                    skipped.append(f'{vid}:{text}')
                    continue
                for mode, x in clips.items():
                    save(os.path.join(OUT, vid, f'{key}_{n}_{mode}.wav'), x)
                ok.append(n)
            index[vid][key] = ok
    os.makedirs(os.path.dirname(INDEX), exist_ok=True)
    json.dump({'voices': list(VOICES), 'lines': index, 'text': LINES}, open(INDEX, 'w'), ensure_ascii=False, indent=1)
    print('descartadas:', skipped)
    missing = [(v, k) for v in index for k in index[v] if not index[v][k]]
    print('sin ninguna variante:', missing)


if __name__ == '__main__':
    main()
