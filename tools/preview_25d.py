"""合成 2.5D 素材预览：把建筑贴图按瓦片坐标贴到地图上，检查比例与对位。

用法：python tools/preview_25d.py
产物：tools/_25d_preview.png（地图合成）与 tools/_25d_sheet.png（素材一览）
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "ui" / "25d"

TILE_X = 48
TILE_Y = 34
FRAME_MARGIN = 24


def tile_pos(col: int, row: int) -> tuple[float, float]:
    return (
        FRAME_MARGIN + col * TILE_X + TILE_X * 0.5,
        FRAME_MARGIN + row * TILE_Y + TILE_Y * 0.5,
    )


def compose_map() -> None:
    base = Image.open(ART / "map_junction.png").convert("RGBA")
    canvas = Image.new("RGBA", base.size, (12, 14, 17, 255))
    canvas.alpha_composite(base)

    placements = [
        ("turret_d0", 2, 10),
        ("turret_d2", 5, 10),
        ("heavy_turret_d1", 7, 11),
        ("laser_tower_d3", 10, 9),
        ("sandbag", 8, 10),
        ("solar", 5, 12),
        ("compression_tower", 4, 10),
        ("fusion_tower", 1, 12),
    ]
    for name, col, row in placements:
        sprite = Image.open(ART / f"{name}.png").convert("RGBA")
        cx, cy = tile_pos(col, row)
        canvas.alpha_composite(sprite, (round(cx - sprite.width / 2), round(cy - sprite.height / 2)))
    canvas.convert("RGB").save(ROOT / "tools" / "_25d_preview.png")
    print("saved tools/_25d_preview.png")


def sprite_sheet() -> None:
    names = [
        "turret_d0", "turret_d2", "turret_d4", "turret_d6",
        "heavy_turret_d0", "heavy_turret_d2", "laser_tower_d0", "laser_tower_d2",
        "sandbag", "solar", "compression_tower", "fusion_tower",
    ]
    cell = 168
    cols = 4
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (38, 40, 44, 255))
    for index, name in enumerate(names):
        sprite = Image.open(ART / f"{name}.png").convert("RGBA")
        x = (index % cols) * cell + (cell - sprite.width) // 2
        y = (index // cols) * cell + (cell - sprite.height) // 2
        sheet.alpha_composite(sprite, (x, y))
    sheet.convert("RGB").save(ROOT / "tools" / "_25d_sheet.png")
    print("saved tools/_25d_sheet.png")


if __name__ == "__main__":
    compose_map()
    sprite_sheet()
