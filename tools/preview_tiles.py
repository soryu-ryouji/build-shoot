"""用 tiles 贴片拼一张地图预览，验证拼缝、路面连接与高台边界。

用法：python tools/preview_tiles.py [map_id]
产物：tools/_tiles_preview.png
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TILES = ROOT / "assets" / "ui" / "tiles"
DATA = json.loads((ROOT / "assets" / "maps" / "maps.json").read_text(encoding="utf-8"))

TILE_W = 48
TILE_H = 34
CANVAS = 64
MARGIN = 24


def load(name: str) -> Image.Image:
    return Image.open(TILES / f"{name}.png").convert("RGBA")


def tile_anchor(col: int, row: int) -> tuple[int, int]:
    """贴片左上角在拼图里的位置：格子地面中心 = (MARGIN + col*48 + 24, MARGIN + row*34 + 17)。"""
    return (MARGIN + col * TILE_W, MARGIN + row * TILE_H)


def build(map_data: dict) -> Image.Image:
    cols = DATA["cols"]
    rows = DATA["rows"]
    width = cols * TILE_W + MARGIN * 2
    height = rows * TILE_H + MARGIN * 2
    canvas = Image.new("RGBA", (width, height), (12, 14, 17, 255))

    path = set()
    for route in map_data["routes"]:
        for col, row in route:
            path.add((col, row))
    high = set()
    for rect in map_data.get("high", []):
        for col in range(rect[0], rect[2] + 1):
            for row in range(rect[1], rect[3] + 1):
                high.add((col, row))
    core = {tuple(t) for t in map_data["core"]}
    gates = {tuple(t) for t in map_data["gates"]}

    floor_a = load("floor_a")
    floor_b = load("floor_b")
    high_tile = load("high")
    rim = load("rim")

    # 外圈边框
    for col in range(-1, cols + 1):
        for row in range(-1, rows + 1):
            if 0 <= col < cols and 0 <= row < rows:
                continue
            canvas.alpha_composite(rim, tile_anchor(col, row))

    # 先铺所有地板
    for row in range(rows):
        for col in range(cols):
            x, y = tile_anchor(col, row)
            canvas.alpha_composite(floor_a if (col + row) % 2 == 0 else floor_b, (x, y))

    # 路面：在地板上画连续的带子
    draw = ImageDraw.Draw(canvas)
    road_color = (16, 18, 20, 235)
    for route in map_data["routes"]:
        points = [
            (MARGIN + col * TILE_W + TILE_W // 2, MARGIN + row * TILE_H + TILE_H // 2)
            for col, row in route
        ]
        draw.line(points, fill=road_color, width=28, joint="curve")

    # 再按行从北往南铺高台/缺口，南侧高的地块自然压住北侧
    for row in range(rows):
        for col in range(cols):
            x, y = tile_anchor(col, row)
            tile = (col, row)
            if tile in gates:
                canvas.alpha_composite(load("gate_0"), (x, y))
                continue
            if tile in high:
                canvas.alpha_composite(high_tile, (x, y))


    core_sprite = load("core")
    core_tiles = [t for t in core]
    cx = MARGIN + (sum(t[0] for t in core_tiles) / len(core_tiles) + 0.5) * TILE_W
    cy = MARGIN + (sum(t[1] for t in core_tiles) / len(core_tiles) + 0.5) * TILE_H
    canvas.alpha_composite(core_sprite, (round(cx - core_sprite.width / 2), round(cy - core_sprite.height / 2)))
    return canvas


def main() -> None:
    wanted = sys.argv[1] if len(sys.argv) > 1 else "junction"
    map_data = next(m for m in DATA["maps"] if m["id"] == wanted)
    image = build(map_data)
    out = ROOT / "tools" / "_tiles_preview.png"
    image.convert("RGB").save(out)
    print(f"saved {out} {image.width}x{image.height}")


if __name__ == "__main__":
    main()
