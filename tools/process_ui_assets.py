#!/usr/bin/env python3
"""Crop and optimize the raw ComfyUI paintings for the Godot game."""

import argparse
from pathlib import Path
import statistics

from PIL import Image, ImageChops, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "ui" / "source"
TARGET = ROOT / "assets" / "ui"


def process_arena() -> None:
    image = Image.open(SOURCE / "arena.png").convert("RGB")
    image = image.resize((720, 960), Image.Resampling.LANCZOS)
    image = ImageEnhance.Brightness(image).enhance(0.90)
    tint = Image.new("RGB", image.size, (184, 188, 186))
    image = Image.blend(image, tint, 0.08)
    image.save(TARGET / "arena.png", optimize=True)


def process_menu() -> None:
    image = Image.open(SOURCE / "menu.png").convert("RGB")
    # Cover the viewport without changing the character's aspect ratio.
    scale = max(720.0 / image.width, 960.0 / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - 720) // 2
    top = (resized.height - 960) // 2
    image = resized.crop((left, top, left + 720, top + 960))
    image = ImageEnhance.Brightness(image).enhance(0.98)
    image.save(TARGET / "menu_background.png", optimize=True)


def build_sprite(
    sheet: Image.Image,
    box: tuple[int, int, int, int],
    name: str,
    output_size: int = 256,
    base_anchor: bool = False,
) -> Image.Image:
    icon = sheet.crop(box).convert("RGB")
    if "swift" in name:
        icon = ImageEnhance.Brightness(icon).enhance(2.15)
    elif "elite" in name:
        icon = ImageEnhance.Brightness(icon).enhance(1.45)
    elif "normal" in name:
        icon = ImageEnhance.Brightness(icon).enhance(1.20)
    corners = [icon.getpixel(point) for point in [(2, 2), (icon.width - 3, 2), (2, icon.height - 3)]]
    background = tuple(int(statistics.median(channel)) for channel in zip(*corners))
    bg = Image.new("RGB", icon.size, background)
    difference = ImageChops.difference(icon, bg).convert("L")

    # Locate the painted object, then retain enough padding for its barrel and base.
    mask = difference.point(lambda value: 255 if value > 22 else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise RuntimeError(f"No foreground found for {name}")
    pad = 22
    bounds = (
        max(0, bounds[0] - pad),
        max(0, bounds[1] - pad),
        min(icon.width, bounds[2] + pad),
        min(icon.height, bounds[3] + pad),
    )
    icon = icon.crop(bounds)
    if base_anchor:
        # Field sprites rotate around the base, not around the barrel's bounding box.
        # Put the estimated base center at the canvas center before removing the backdrop.
        side = 320
        scale = 230.0 / icon.height
        icon = icon.resize((round(icon.width * scale), 230), Image.Resampling.LANCZOS)
        square = Image.new("RGB", (side, side), background)
        anchor_y = round(icon.height * 0.75)
        square.paste(icon, ((side - icon.width) // 2, side // 2 - anchor_y))
    else:
        side = max(icon.size)
        square = Image.new("RGB", (side, side), background)
        square.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2))

    # The generated background is nearly uniform. Feather only its color difference,
    # preserving the metallic dark outlines while removing the rectangular backdrop.
    difference = ImageChops.difference(square, Image.new("RGB", square.size, background)).convert("L")
    alpha = difference.point(lambda value: max(0, min(255, round((value - 3) * 255 / 20))))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.45))
    result = square.convert("RGBA")
    result.putalpha(alpha)
    return result.resize((output_size, output_size), Image.Resampling.LANCZOS)


def process_sprite(
    sheet: Image.Image,
    box: tuple[int, int, int, int],
    name: str,
    output_size: int = 256,
    base_anchor: bool = False,
) -> None:
    build_sprite(sheet, box, name, output_size, base_anchor).save(TARGET / f"{name}.png", optimize=True)


def process_units() -> None:
    monsters = Image.open(SOURCE / "monsters.png")
    half_w, half_h = monsters.width // 2, monsters.height // 2
    boxes = {
        "monster_normal": (0, 0, half_w, half_h),
        "monster_swift": (half_w, 0, monsters.width, half_h),
        "monster_armored": (0, half_h, half_w, monsters.height),
        "monster_elite": (half_w, half_h, monsters.width, monsters.height),
    }
    for name, box in boxes.items():
        process_sprite(monsters, box, name)

    turrets = Image.open(SOURCE / "turrets.png")
    boxes = {
        "turret": (0, 0, turrets.width // 2, turrets.height),
        "heavy_turret": (turrets.width // 2, 0, turrets.width, turrets.height),
    }
    for name, box in boxes.items():
        process_sprite(turrets, box, name)
        process_sprite(turrets, box, f"{name}_field", output_size=320, base_anchor=True)


def process_animations() -> None:
    for kind in ("normal", "swift", "armored", "elite"):
        sheet = Image.open(SOURCE / f"anim_{kind}.png")
        half_w, half_h = sheet.width // 2, sheet.height // 2
        boxes = [
            (0, 0, half_w, half_h),
            (half_w, 0, sheet.width, half_h),
            (0, half_h, half_w, sheet.height),
            (half_w, half_h, sheet.width, sheet.height),
        ]
        atlas = Image.new("RGBA", (1024, 256), (0, 0, 0, 0))
        for index, box in enumerate(boxes):
            frame = build_sprite(sheet, box, f"anim_{kind}_{index}")
            atlas.paste(frame, (index * 256, 0))
            if index == 0:
                frame.save(TARGET / f"monster_{kind}.png", optimize=True)
        atlas.save(TARGET / f"monster_{kind}_anim.png", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("preset", nargs="?", default="all", choices=["all", "ui", "arena", "menu", "units", "animations"])
    args = parser.parse_args()
    TARGET.mkdir(parents=True, exist_ok=True)
    if args.preset in ("all", "ui"):
        process_arena()
        process_menu()
    if args.preset == "arena":
        process_arena()
    if args.preset == "menu":
        process_menu()
    if args.preset in ("all", "units"):
        process_units()
    if args.preset in ("all", "animations"):
        process_animations()
    print(f"Processed {args.preset} assets into assets/ui/")


if __name__ == "__main__":
    main()
