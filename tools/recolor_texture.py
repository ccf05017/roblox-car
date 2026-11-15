"""Repaint one hue band of a GLB's base colour texture, for a second car that shares the same mesh.

Usage:
  uv run --python 3.12 --with trimesh --with pillow --with numpy --with scipy --with networkx python tools/recolor_texture.py IN.glb OUT.png [--hue 0.085] [--sat 1.5] [--val 1.4]
"""
import argparse

import numpy as np
import trimesh
from PIL import Image


def rgb_to_hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    high, low = rgb.max(-1), rgb.min(-1)
    spread = np.maximum(high - low, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.select([high == r, high == g], [((g - b) / spread) % 6, (b - r) / spread + 2], (r - g) / spread + 4) / 6
    sat = np.where(high > 0, (high - low) / np.maximum(high, 1e-6), 0)
    return hue, sat, high


def hsv_to_rgb(hue: np.ndarray, sat: np.ndarray, val: np.ndarray) -> np.ndarray:
    sector = (np.floor(hue * 6) % 6).astype(int)
    f = hue * 6 - np.floor(hue * 6)
    p, q, t = val * (1 - sat), val * (1 - f * sat), val * (1 - (1 - f) * sat)
    return np.stack([
        np.choose(sector, [val, q, p, p, t, val]),
        np.choose(sector, [t, val, val, q, p, p]),
        np.choose(sector, [p, p, t, val, val, q]),
    ], -1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("src")
    parser.add_argument("dst")
    parser.add_argument("--band", type=float, nargs=2, default=(0.42, 0.62), help="hue range to repaint, 0-1")
    parser.add_argument("--min-sat", type=float, default=0.2)
    parser.add_argument("--hue", type=float, default=0.085)
    parser.add_argument("--sat", type=float, default=1.5, help="saturation multiplier")
    parser.add_argument("--val", type=float, default=1.4, help="brightness multiplier")
    args = parser.parse_args()

    mesh = trimesh.load(args.src, force="mesh")
    rgb = np.asarray(mesh.visual.material.baseColorTexture.convert("RGB")).astype(np.float32) / 255
    hue, sat, val = rgb_to_hsv(rgb)
    band = (sat > args.min_sat) & (hue > args.band[0]) & (hue < args.band[1])

    out = rgb.copy()
    out[band] = hsv_to_rgb(np.full(band.sum(), args.hue), np.clip(sat[band] * args.sat, 0, 1), np.clip(val[band] * args.val, 0, 1))
    Image.fromarray((out * 255).round().astype(np.uint8)).save(args.dst)
    print(f"repainted {band.mean() * 100:.1f}% of {rgb.shape[1]}x{rgb.shape[0]}, mean {np.round(out[band].mean(0) * 255).astype(int).tolist()}")


if __name__ == "__main__":
    main()
