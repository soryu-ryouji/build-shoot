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


# ---------------------------------------------------------------- 炮塔分层素材

LAYER_SIZE = 320
# 头部贴图比基盘高，给长炮管留出空间；绘制时按头部枢轴对齐到基盘中心
HEAD_CANVAS = (LAYER_SIZE, 384)
HEAD_PIVOT_Y = 320
# 每个炮塔在场上贴图里基盘应占的宽度：绘制时整张贴图按 base_radius * factor 缩放，
# 基盘直径需要正好是 2 * base_radius。
LAYER_TARGETS = {
    "turret": {
        "source": "turret_layers.png",
        "base_source": "turret_base.png",
        "base_width": LAYER_SIZE * 2.0 / 6.0,
        "folds": 36,
    },
    "heavy_turret": {
        "source": "heavy_turret_layers.png",
        "base_source": "heavy_turret_base.png",
        "base_width": LAYER_SIZE * 2.0 / 4.8,
        "folds": 8,
    },
}
# 头部贴图里炮塔机身的中心行对齐到基盘圆心


def _background_color(image: Image.Image) -> tuple[int, int, int]:
    points = [(2, 2), (image.width - 3, 2), (2, image.height - 3)]
    return tuple(int(statistics.median(channel)) for channel in zip(*(image.getpixel(p) for p in points)))


def _cut_foreground(image: Image.Image) -> tuple[Image.Image, Image.Image]:
    image = image.convert("RGB")
    background = _background_color(image)
    difference = ImageChops.difference(image, Image.new("RGB", image.size, background)).convert("L")
    strong = difference.point(lambda value: 255 if value > 22 else 0)
    alpha = difference.point(lambda value: max(0, min(255, round((value - 3) * 255 / 20))))
    # 背景带轻微渐变，先按强边缘裁掉低幅噪声，再轻微羽化
    alpha = ImageChops.multiply(alpha, strong)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.45))
    alpha = alpha.point(lambda value: 0 if value < 8 else value)
    rgba = image.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba, strong


def _row_filled(mask: Image.Image, y: int) -> bool:
    return mask.crop((0, y, mask.width, y + 1)).getbbox() is not None


def _split_parts(mask: Image.Image) -> int:
    rows = [y for y in range(mask.height) if _row_filled(mask, y)]
    best_start, best_length = -1, 0
    start = None
    for y in range(rows[0], rows[-1] + 1):
        filled = _row_filled(mask, y)
        if not filled and start is None:
            start = y
        if filled and start is not None:
            if y - start > best_length:
                best_start, best_length = start, y - start
            start = None
    if best_start < 0:
        raise RuntimeError("Turret layers must have a visible gap between head and base")
    return best_start + best_length // 2


def _body_center(mask: Image.Image) -> float:
    """炮塔机身的中心行：取最宽的那几行，忽略细长炮管。"""
    rows: list[tuple[int, int]] = []
    widest = 0
    for y in range(mask.height):
        box = mask.crop((0, y, mask.width, y + 1)).getbbox()
        width = 0 if box is None else box[2] - box[0]
        if width > 0:
            rows.append((y, width))
            widest = max(widest, width)
    body = [y for y, width in rows if width > widest * 0.6]
    return (body[0] + body[-1]) * 0.5


def _composite(canvas: Image.Image, part: Image.Image, scale: float, left: float, top: float) -> None:
    scaled = part.resize(
        (max(1, round(part.width * scale)), max(1, round(part.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas.alpha_composite(scaled, (round(left), round(top)))


def _tint_base(image: Image.Image) -> Image.Image:
    """压暗偏灰，避免纯白基座在浅色战场上失去对比。"""
    alpha = image.getchannel("A")
    rgb = ImageEnhance.Brightness(image.convert("RGB")).enhance(0.78)
    rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (115, 120, 124)), 0.22)
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def _symmetrize(image: Image.Image, folds: int) -> Image.Image:
    """绕画布中心旋转叠加，抹掉烘焙的光照方向，保证旋转时基座不"翻面"。"""
    center = (image.width * 0.5, image.height * 0.5)
    result = image
    for i in range(1, folds):
        rotated = image.rotate(360.0 * i / folds, center=center, resample=Image.Resampling.BICUBIC)
        result = Image.blend(result, rotated, 1.0 / (i + 1))
    alpha = result.getchannel("A").point(lambda value: 0 if value < 20 else value)
    result.putalpha(alpha)
    return result


def process_turret_bases() -> None:
    for name, spec in LAYER_TARGETS.items():
        image = Image.open(SOURCE / spec["base_source"])
        rgba, strong = _cut_foreground(image)
        bounds = strong.getbbox()
        if bounds is None:
            raise RuntimeError(f"No base plate found in {spec['base_source']}")

        canvas = Image.new("RGBA", (LAYER_SIZE, LAYER_SIZE), (0, 0, 0, 0))
        scale = spec["base_width"] / (bounds[2] - bounds[0])
        _composite(
            canvas,
            rgba,
            scale,
            LAYER_SIZE * 0.5 - (bounds[0] + bounds[2]) * 0.5 * scale,
            LAYER_SIZE * 0.5 - (bounds[1] + bounds[3]) * 0.5 * scale,
        )
        canvas = _tint_base(_symmetrize(canvas, spec["folds"]))
        canvas.save(TARGET / f"{name}_base_field.png", optimize=True)


def process_turret_layers() -> None:
    for name, spec in LAYER_TARGETS.items():
        source = Image.open(SOURCE / spec["source"])
        rgba, strong = _cut_foreground(source)
        split = _split_parts(strong)

        head = rgba.crop((0, 0, rgba.width, split))
        head_box = strong.crop((0, 0, strong.width, split)).getbbox()
        # 分层图里的基盘只用来给炮塔头定尺寸，场上基盘来自单独的扁平贴图
        base_box = strong.crop((0, split, strong.width, strong.height)).getbbox()
        if head_box is None or base_box is None:
            raise RuntimeError(f"Missing turret layer in {spec['source']}")
        scale = spec["base_width"] / (base_box[2] - base_box[0])

        base_path = TARGET / f"{name}_base_field.png"
        if not base_path.exists():
            raise RuntimeError("Run `process_ui_assets.py bases` before `layers`")
        base_canvas = Image.open(base_path).convert("RGBA")

        # 炮塔机身中心对准基盘圆心，炮管向前伸出，避免炮身整体偏出基座
        body_center = _body_center(strong.crop((0, 0, strong.width, split)))
        head_canvas = Image.new("RGBA", HEAD_CANVAS, (0, 0, 0, 0))
        head_center_x = (head_box[0] + head_box[2]) * 0.5
        _composite(
            head_canvas,
            head,
            scale,
            LAYER_SIZE * 0.5 - head_center_x * scale,
            HEAD_PIVOT_Y - body_center * scale,
        )
        head_canvas.save(TARGET / f"{name}_head_field.png", optimize=True)

        # 商店图标用同一套分层素材拼装，保证图标和场上造型一致
        icon = Image.new("RGBA", (LAYER_SIZE, HEAD_CANVAS[1] + LAYER_SIZE), (0, 0, 0, 0))
        icon.alpha_composite(base_canvas, (0, HEAD_PIVOT_Y - LAYER_SIZE // 2))
        icon.alpha_composite(head_canvas)
        bounds = icon.split()[3].getbbox()
        pad = 12
        icon = icon.crop(
            (
                max(0, bounds[0] - pad),
                max(0, bounds[1] - pad),
                min(icon.width, bounds[2] + pad),
                min(icon.height, bounds[3] + pad),
            )
        )
        icon = icon.resize((256, 256), Image.Resampling.LANCZOS)
        icon.save(TARGET / f"{name}.png", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "preset",
        nargs="?",
        default="all",
        choices=["all", "ui", "arena", "menu", "units", "bases", "layers", "animations"],
    )
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
    if args.preset in ("all", "bases"):
        process_turret_bases()
    if args.preset in ("all", "layers"):
        process_turret_layers()
    if args.preset in ("all", "animations"):
        process_animations()
    print(f"Processed {args.preset} assets into assets/ui/")


if __name__ == "__main__":
    main()
