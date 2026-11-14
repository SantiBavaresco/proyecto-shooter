#!/usr/bin/env python3
"""Manchas de sangre irregulares (provisorias) para los Decals: assets/textures/fx/blood_N.png"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'textures', 'fx')
rng = np.random.default_rng(7171)
SZ = 128


def noise(sz, scale):
    g = rng.random((sz // scale + 2, sz // scale + 2))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((sz, sz), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def main():
    os.makedirs(OUT, exist_ok=True)
    yy, xx = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    for v in range(6):
        f = np.zeros((SZ, SZ), np.float32)
        blobs = []
        for k in range(rng.integers(4, 9)):
            r = rng.uniform(10, 30) * (1.0 if k == 0 else 0.7)
            c = np.array([64, 64]) + rng.uniform(-28, 28, 2) * (0.3 if k == 0 else 1.0)
            blobs.append((c, r))
        for k in range(rng.integers(5, 13)):
            a = rng.uniform(0, 2 * np.pi)
            blobs.append((np.array([64, 64]) + np.array([np.cos(a), np.sin(a)]) * rng.uniform(35, 58), rng.uniform(1.5, 4)))
        for c, r in blobs:
            d = np.sqrt((xx - c[0]) ** 2 + (yy - c[1]) ** 2) / r
            f = np.maximum(f, 1 - d)
        f += (noise(SZ, 8) - 0.5) * 0.5 + (noise(SZ, 3) - 0.5) * 0.2
        a = np.clip(f * 4, 0, 1)
        dark = np.clip(f * 1.5, 0, 1)
        base = np.array([0.33, 0.02, 0.02])
        deep = np.array([0.18, 0.0, 0.01])
        col = base[None, None, :] * (1 - dark[..., None]) + deep[None, None, :] * dark[..., None]
        rgba = np.concatenate([col, (a * 0.95)[..., None]], axis=-1)
        Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, f'blood_{v}.png'))
    print('ok')


if __name__ == '__main__':
    main()
