#!/usr/bin/env python3
"""Analyze comfy-home.png against Catppuccin Frappe accent colors."""

import tomllib
from pathlib import Path

import numpy as np
from PIL import Image

ACCENT_NAMES = [
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon",
    "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
]
MAX_DISTANCE = 60

root = Path(__file__).resolve().parent.parent
palette_path = root / "themes" / "catppuccin-frappe" / "palette.toml"
image_path = root / "assets" / "comfy-home.png"

with open(palette_path, "rb") as f:
    palette = tomllib.load(f)["colors"]

accent_rgb = np.array([
    [int(palette[name][1:3], 16), int(palette[name][3:5], 16), int(palette[name][5:7], 16)]
    for name in ACCENT_NAMES
], dtype=np.float64)

img = np.array(Image.open(image_path).convert("RGB"), dtype=np.float64)
pixels = img.reshape(-1, 3)

# Euclidean distance from each pixel to each accent color: (N, 14)
dists = np.sqrt(((pixels[:, np.newaxis, :] - accent_rgb[np.newaxis, :, :]) ** 2).sum(axis=2))

nearest_idx = dists.argmin(axis=1)
nearest_dist = dists[np.arange(len(pixels)), nearest_idx]

mask = nearest_dist <= MAX_DISTANCE
classified = nearest_idx[mask]
total = classified.size

print(f"Image: {image_path.name} ({pixels.shape[0]} pixels, {total} classified within threshold {MAX_DISTANCE})\n")
print(f"{'Color':<12} {'Hex':<10} {'Pixels':>8} {'%':>7}")
print("-" * 40)

counts = np.bincount(classified, minlength=len(ACCENT_NAMES))
for i in np.argsort(-counts):
    if counts[i] == 0:
        continue
    pct = counts[i] / total * 100
    print(f"{ACCENT_NAMES[i]:<12} {palette[ACCENT_NAMES[i]]:<10} {counts[i]:>8} {pct:>6.1f}%")
