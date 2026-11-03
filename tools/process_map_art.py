"""把 generate_map_art.py 生成的原图裁成游戏用的地图贴图。

用法：
    python tools/process_map_art.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "ui" / "source"
TARGET = ROOT / "assets" / "ui"

sys.path.insert(0, str(ROOT / "tools"))

import process_ui_assets as proc  # noqa: E402

## 地图瓦片区尺寸，见 scripts/battle_map.gd
FIELD = (576, 672)
## 生成图四周画了机械外框，只取中间这块干净的甲板，避免外框落进战场内部
CROP_RATIO = 0.74

MAP_FILES = {
    "map_alpha": "map_junction.png",
    "map_beta": "map_chicane.png",
    "map_gamma": "map_zigzag.png",
}

## 缺口是竖长形门洞，核心是圆形装置，各自按原比例放进画布
PROPS = {
    "gate": (128, 192),
    "core": (256, 256),
}


def process_floors() -> None:
    for source, target in MAP_FILES.items():
        path = SOURCE / f"{source}.png"
        if not path.exists():
            raise SystemExit(f"missing source: {path}")
        image = Image.open(path).convert("RGB")
        width, height = image.size
        ratio = FIELD[0] / FIELD[1]
        crop_width = min(width, round(width * CROP_RATIO))
        crop_height = round(crop_width / ratio)
        if crop_height > height:
            crop_height = height
            crop_width = round(crop_height * ratio)
        left = (width - crop_width) // 2
        top = (height - crop_height) // 2
        image.crop((left, top, left + crop_width, top + crop_height)).resize(
            FIELD, Image.Resampling.LANCZOS
        ).save(TARGET / target, optimize=True)
        print(f"[floor] {target} {FIELD[0]}x{FIELD[1]}", flush=True)


def process_props() -> None:
    for name, (box_width, box_height) in PROPS.items():
        path = SOURCE / f"{name}.png"
        if not path.exists():
            raise SystemExit(f"missing source: {path}")
        rgba, mask = proc._cut_foreground_static(Image.open(path))
        bounds = mask.getbbox()
        if bounds is None:
            raise SystemExit(f"no subject found in {path}")
        cut = rgba.crop(bounds)
        cut.thumbnail((box_width, box_height), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (box_width, box_height), (0, 0, 0, 0))
        canvas.alpha_composite(
            cut,
            ((box_width - cut.width) // 2, (box_height - cut.height) // 2),
        )
        canvas.save(TARGET / f"{name}.png", optimize=True)
        print(f"[prop] {name} {box_width}x{box_height}", flush=True)


def main() -> None:
    process_floors()
    process_props()


if __name__ == "__main__":
    main()
