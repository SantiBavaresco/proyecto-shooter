#!/usr/bin/env python3
"""Texturas de sangre (provisorias) para los Decals: assets/textures/fx/

  blood_pool_N.png   charco irregular (borde orgánico, más oscuro y espeso al centro)
  blood_splat_N.png  salpicadura por proyección: mancha central, gotas alrededor y
                     gotas alargadas con cola hacia +V (la dirección en que venía)
  blood_smear_N.png  arrastre: trazo alargado en V con estrías y bordes desflecados
  blood_drop_N.png   gotitas sueltas

Todas con alfa 0 en el borde (no se ve el cuadrado del Decal).
"""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'textures', 'fx')
rng = np.random.default_rng(7171)
SZ = 256
BASE = np.array([0.55, 0.04, 0.04])
DEEP = np.array([0.3, 0.0, 0.02])


def value_noise(sz, cells):
    g = rng.random((cells + 3, cells + 3)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((sz, sz), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def fbm(sz, base_cells=4, octaves=4):
    out = np.zeros((sz, sz), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(sz, base_cells * 2 ** o) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def edge_mask(sz, margin=0.06):
    """1 en el centro, 0 en los bordes de la imagen (el decal nunca muestra el borde)."""
    y, x = np.mgrid[0:sz, 0:sz].astype(np.float32) / (sz - 1)
    d = np.minimum.reduce([x, 1 - x, y, 1 - y])
    return np.clip(d / margin, 0, 1) ** 1.5


def to_rgba(field, thick):
    """field: 0..1 presencia; thick: 0..1 espesor (más oscuro)."""
    a = np.clip(field, 0, 1)
    col = BASE[None, None, :] * (1 - thick[..., None]) + DEEP[None, None, :] * thick[..., None]
    rgba = np.concatenate([col, a[..., None]], axis=-1)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA')


def grid():
    y, x = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    return (x - SZ / 2) / (SZ / 2), (y - SZ / 2) / (SZ / 2)


def disc(cx, cy, r):
    x, y = grid()
    return np.clip(1 - np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r, 0, 1)


def pool(v):
    x, y = grid()
    # Forma base: blob deformado por ruido (domain warp) + lóbulos
    wx = (fbm(SZ, 3) - 0.5) * 0.55
    wy = (fbm(SZ, 3) - 0.5) * 0.55
    r = np.sqrt((x + wx) ** 2 + (y + wy) ** 2)
    lobes = np.zeros_like(r)
    for k in range(rng.integers(3, 6)):
        a = rng.uniform(0, 2 * np.pi)
        lobes = np.maximum(lobes, disc(np.cos(a) * rng.uniform(0.25, 0.5), np.sin(a) * rng.uniform(0.25, 0.5), rng.uniform(0.18, 0.35)))
    base = np.clip((0.62 - r) * 16.0, 0, 1)
    f = np.maximum(base, np.clip(lobes * 9.0, 0, 1))
    # Gotas satélite
    for k in range(rng.integers(6, 14)):
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(0.62, 0.86)
        f = np.maximum(f, np.clip(disc(np.cos(a) * d, np.sin(a) * d, rng.uniform(0.012, 0.035)) * 8, 0, 1))
    f *= edge_mask(SZ)
    thick = np.clip(base * 1.2 + (fbm(SZ, 6) - 0.5) * 0.4, 0, 1)
    return to_rgba(f, thick)


def splat(v):
    x, y = grid()
    f = np.zeros((SZ, SZ), np.float32)
    # Mancha central irregular
    wx = (fbm(SZ, 5) - 0.5) * 0.3
    wy = (fbm(SZ, 5) - 0.5) * 0.3
    core = np.clip((0.22 - np.sqrt((x + wx) ** 2 + (y + 0.15 + wy) ** 2)) * 9, 0, 1)
    f = np.maximum(f, core)
    # Gotas alargadas con cola (en abanico hacia arriba, +V = hacia donde iba la bala)
    for k in range(rng.integers(14, 26)):
        ang = rng.normal(0, 0.55)
        dist = rng.uniform(0.15, 0.85)
        cx = np.sin(ang) * dist
        cy = -0.15 - np.cos(ang) * dist
        r = rng.uniform(0.012, 0.045) * (1.2 - dist * 0.6)
        head = disc(cx, cy, r)
        # Cola: elipse estirada en la dirección del vuelo
        tl = rng.uniform(2.5, 6.0)
        ux, uy = np.sin(ang), -np.cos(ang)
        px, py = x - cx, y - cy
        along = px * ux + py * uy
        perp = -px * uy + py * ux
        tail = np.clip(1 - np.sqrt((perp / (r * 0.6)) ** 2 + (np.clip(-along, 0, None) / (r * tl)) ** 2), 0, 1)
        tail *= (along < 0)
        f = np.maximum(f, np.clip(np.maximum(head, tail * 0.85) * 6, 0, 1))
    # Lluvia de gotitas
    for k in range(rng.integers(30, 60)):
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(0.2, 0.9)
        f = np.maximum(f, np.clip(disc(np.cos(a) * d, np.sin(a) * d - 0.1, rng.uniform(0.005, 0.014)) * 8, 0, 1))
    f *= edge_mask(SZ)
    thick = np.clip(core * 1.3, 0, 1)
    return to_rgba(f, thick)


def smear(v):
    x, y = grid()
    # Trazo vertical (V), más ancho y cargado al principio, que se va afinando
    t = (y + 1) / 2  # 0 arriba, 1 abajo
    width = 0.42 * (1 - t * 0.55) + (fbm(SZ, 3)[:, :1] - 0.5) * 0.12
    wob = (fbm(SZ, 2) - 0.5) * 0.25
    body = np.clip((width - np.abs(x + wob)) * 7, 0, 1)
    # Estrías a lo largo
    stri = value_noise(SZ, 40)
    stri = np.asarray(Image.fromarray((stri * 255).astype(np.uint8)).resize((SZ, 6)).resize((SZ, SZ), Image.BICUBIC)).astype(np.float32) / 255.0
    f = body * np.clip(0.45 + stri * 0.9, 0, 1)
    f *= np.clip((0.92 - np.abs(y)) * 5, 0, 1)
    # Puntas desflecadas
    f *= np.clip(0.6 + fbm(SZ, 10) * 0.8, 0, 1)
    f *= edge_mask(SZ)
    thick = np.clip(body * (1 - t) * 1.1, 0, 1)
    return to_rgba(f, thick)


def drops(v):
    f = np.zeros((SZ, SZ), np.float32)
    for k in range(rng.integers(10, 22)):
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(0, 0.8)
        f = np.maximum(f, np.clip(disc(np.cos(a) * d, np.sin(a) * d, rng.uniform(0.02, 0.07)) * 6, 0, 1))
    wx = fbm(SZ, 8)
    f *= np.clip(0.7 + wx * 0.6, 0, 1)
    f *= edge_mask(SZ)
    return to_rgba(f, f * 0.6)


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.startswith('blood_') and old.endswith('.png'):
            os.remove(os.path.join(OUT, old))
    for kind, fn, n in (('pool', pool, 6), ('splat', splat, 6), ('smear', smear, 4), ('drop', drops, 4)):
        for v in range(n):
            img = fn(v).filter(ImageFilter.GaussianBlur(0.6))
            img.save(os.path.join(OUT, f'blood_{kind}_{v}.png'))
    print('ok')


if __name__ == '__main__':
    main()
