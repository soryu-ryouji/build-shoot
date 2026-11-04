#!/usr/bin/env python3
"""Turn the generated industrial texture into a seamless 64px Godot atlas."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "ui" / "source"
TARGET = ROOT / "assets" / "tilesets" / "industrial.png"
TILE = 64
WORK = 256


def seamless_patch(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    patch = source.crop(box).resize((WORK, WORK), Image.Resampling.LANCZOS)
    # 只在边缘混入对侧内容，中央保留原始材质，避免整格镜像的对称条纹。
    fade = [max(0.0, 1.0 - min(x, WORK - 1 - x) / 88.0) * 128 for x in range(WORK)]
    mask_x = Image.new("L", (WORK, WORK))
    mask_x.putdata([int(value) for y in range(WORK) for value in fade])
    mixed = Image.composite(ImageOps.mirror(patch), patch, mask_x)
    mask_y = mask_x.transpose(Image.Transpose.ROTATE_90)
    mixed = Image.composite(ImageOps.flip(mixed), mixed, mask_y)
    result = mixed.resize((TILE, TILE), Image.Resampling.LANCZOS).convert("RGBA")
    result = ImageEnhance.Contrast(result).enhance(1.10)
    pixels = result.load()
    for index in range(TILE):
        left = pixels[0, index]
        right = pixels[TILE - 1, index]
        average = tuple((left[channel] + right[channel]) // 2 for channel in range(4))
        pixels[0, index] = average
        pixels[TILE - 1, index] = average
        top = pixels[index, 0]
        bottom = pixels[index, TILE - 1]
        average = tuple((top[channel] + bottom[channel]) // 2 for channel in range(4))
        pixels[index, 0] = average
        pixels[index, TILE - 1] = average
    return result


def exterior(tile: Image.Image, variant: int) -> Image.Image:
    rgb = tile.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(0.90 if variant == 0 else 0.92)
    rgb = ImageEnhance.Color(rgb).enhance(0.78)
    tint = Image.new("RGB", rgb.size, (118, 130, 136))
    rgb = Image.blend(rgb, tint, 0.08)
    return rgb.convert("RGBA")


def transparent_tile() -> Image.Image:
    return Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))


def pipe_tile() -> Image.Image:
    image = transparent_tile()
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 105, 256, 151), radius=15, fill=(51, 61, 66, 220))
    draw.rectangle((0, 114, 256, 130), fill=(137, 148, 150, 230))
    draw.line((0, 109, 256, 109), fill=(211, 215, 208, 170), width=4)
    for x in (28, 220):
        draw.rectangle((x, 94, x + 18, 162), fill=(57, 65, 68, 245))
        draw.rectangle((x + 4, 98, x + 9, 158), fill=(184, 188, 180, 220))
    return image.resize((TILE, TILE), Image.Resampling.LANCZOS)


def vent_tile() -> Image.Image:
    image = transparent_tile()
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((48, 66, 208, 190), radius=12, fill=(48, 57, 61, 215), outline=(194, 199, 193, 210), width=5)
    draw.rectangle((61, 79, 195, 177), fill=(91, 102, 106, 210))
    for y in range(88, 174, 17):
        draw.line((70, y, 187, y), fill=(32, 40, 44, 235), width=7)
        draw.line((70, y + 3, 187, y + 3), fill=(161, 168, 165, 150), width=2)
    return image.resize((TILE, TILE), Image.Resampling.LANCZOS)


def stain_tile() -> Image.Image:
    image = transparent_tile()
    draw = ImageDraw.Draw(image)
    for box, alpha in [((42, 76, 211, 195), 18), ((72, 49, 182, 180), 16), ((28, 112, 153, 220), 12)]:
        draw.ellipse(box, fill=(52, 61, 61, alpha))
    image = image.filter(ImageFilter.GaussianBlur(15))
    return image.resize((TILE, TILE), Image.Resampling.LANCZOS)


def crack_tile() -> Image.Image:
    image = transparent_tile()
    draw = ImageDraw.Draw(image)
    points = [(26, 41), (91, 89), (76, 132), (143, 162), (127, 221)]
    draw.line(points, fill=(54, 62, 63, 105), width=4)
    draw.line([(91, 89), (145, 64), (181, 79)], fill=(54, 62, 63, 85), width=3)
    draw.line([(76, 132), (38, 158), (21, 185)], fill=(54, 62, 63, 75), width=3)
    return image.resize((TILE, TILE), Image.Resampling.LANCZOS)


def orange_mark_tile() -> Image.Image:
    image = transparent_tile()
    draw = ImageDraw.Draw(image)
    draw.line([(26, 218), (26, 46), (76, 46)], fill=(216, 139, 48, 185), width=11)
    draw.line([(45, 218), (45, 66), (94, 66)], fill=(246, 195, 95, 85), width=3)
    return image.resize((TILE, TILE), Image.Resampling.LANCZOS)


def main() -> None:
    sources = sorted(SOURCE.glob("industrial_tiles_*.png"))
    if not sources:
        raise FileNotFoundError("No generated industrial_tiles_*.png found")
    source = Image.open(sources[-1]).convert("RGB")
    if source.width < 1024 or source.height < 1024:
        raise ValueError(f"Expected at least 1024x1024, got {source.size}")

    boxes = [
        (32, 32, 416, 416),
        (544, 32, 928, 416),
        (32, 544, 416, 928),
        (544, 544, 928, 928),
        (256, 32, 640, 416),
        (256, 544, 640, 928),
    ]
    floors = [seamless_patch(source, box) for box in boxes]
    atlas = Image.new("RGBA", (TILE * 8, TILE * 2), (0, 0, 0, 0))
    for index in range(4):
        atlas.paste(floors[index], (index * TILE, 0))
        # Mirrored construction must make opposite edges exactly continuous.
        tile = floors[index]
        assert tile.getpixel((0, 20)) == tile.getpixel((TILE - 1, 20))
        assert tile.getpixel((20, 0)) == tile.getpixel((20, TILE - 1))
    atlas.paste(exterior(floors[4], 0), (4 * TILE, 0))
    atlas.paste(exterior(floors[5], 1), (5 * TILE, 0))

    decorations = [pipe_tile(), vent_tile(), stain_tile(), crack_tile(), orange_mark_tile()]
    for index, tile in enumerate(decorations):
        atlas.paste(tile, (index * TILE, TILE), tile)

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(TARGET, optimize=True)
    print(f"saved: {TARGET.relative_to(ROOT)} from {sources[-1].name}")


if __name__ == "__main__":
    main()
