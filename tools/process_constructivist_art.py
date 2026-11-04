#!/usr/bin/env python3
"""Fit constructivist turret samples to the existing pivots and shop icon."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from process_ui_assets import _body_center, _cut_chroma, _tint_base

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "ui" / "source"
TARGET = ROOT / "assets" / "ui"
BASE_SIZE = 320
HEAD_SIZE = (320, 384)
PIVOT_Y = 320


def latest(name: str) -> Path:
    paths = sorted(SOURCE.glob(f"{name}_*.png"))
    if not paths:
        raise FileNotFoundError(f"No generated {name}_*.png found")
    return paths[-1]


def process_base() -> Image.Image:
    image = _cut_chroma(Image.open(latest("construct_turret_base")))
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Empty turret base")
    image = image.crop(bounds)
    scale = 108.0 / image.width
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((BASE_SIZE - image.width) // 2, (BASE_SIZE - image.height) // 2))
    canvas = _tint_base(canvas)
    canvas.save(TARGET / "turret_base_field.png", optimize=True)
    return canvas


def process_head() -> Image.Image:
    image = _cut_chroma(Image.open(latest("construct_turret_head")))
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Empty turret head")
    image = image.crop(bounds)
    body_center_y = _body_center(image.getchannel("A"))
    scale = 77.0 / image.width
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", HEAD_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(image, (round(BASE_SIZE * 0.5 - image.width * 0.5), round(PIVOT_Y - body_center_y * scale)))
    canvas.save(TARGET / "turret_head_field.png", optimize=True)
    return canvas


def make_icon(base: Image.Image, head: Image.Image) -> None:
    icon = Image.new("RGBA", (320, 704), (0, 0, 0, 0))
    icon.alpha_composite(base, (0, PIVOT_Y - BASE_SIZE // 2))
    icon.alpha_composite(head)
    bounds = icon.getchannel("A").getbbox()
    pad = 12
    icon = icon.crop((max(0, bounds[0] - pad), max(0, bounds[1] - pad), min(icon.width, bounds[2] + pad), min(icon.height, bounds[3] + pad)))
    icon = icon.resize((256, 256), Image.Resampling.LANCZOS)
    icon.save(TARGET / "turret.png", optimize=True)


def main() -> None:
    base = process_base()
    head = process_head()
    make_icon(base, head)
    print("saved constructivist turret base, head and icon")


if __name__ == "__main__":
    main()
