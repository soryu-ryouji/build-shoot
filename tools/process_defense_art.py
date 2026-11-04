#!/usr/bin/env python3
"""Cut out and resize the generated base and nest sprites."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from process_ui_assets import _cut_chroma

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "ui" / "source"
TARGET = ROOT / "assets" / "ui"


def process(name: str, size: int) -> None:
    sources = sorted(SOURCE.glob(f"{name}_*.png"))
    if not sources:
        raise FileNotFoundError(f"No generated {name}_*.png found")
    image = _cut_chroma(Image.open(sources[-1]))
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"{name} has no visible subject")
    image = image.crop(bounds)
    side = max(image.size) + 64
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2), image)
    canvas = canvas.resize((size, size), Image.Resampling.LANCZOS)
    target = TARGET / f"{name}.png"
    canvas.save(target, optimize=True)
    print(f"saved: {target.relative_to(ROOT)}")


def main() -> None:
    process("base_core", 512)
    process("nest", 256)


if __name__ == "__main__":
    main()
