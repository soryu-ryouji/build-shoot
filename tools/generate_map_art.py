"""用 ComfyUI 生成路线地图的地板、出怪缺口与核心素材。

沿用 generate_ui_assets.py 的 Qwen Image 2.1 工作流与提交/下载逻辑，只换提示词。
产物先落在 assets/ui/source/，再由 process_map_art.py 裁切成游戏素材。

用法：
    python tools/generate_map_art.py all
    python tools/generate_map_art.py map_alpha gate core
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_ui_assets as gen  # noqa: E402

FLOOR_COMMON = (
    "Full-frame orthographic top-down view of a flat tactical battlefield deck for an original "
    "anime tower defense game: one completely empty walkable floor that fills the entire image "
    "edge to edge, with nothing standing on it and no raised structures. Surface detail only: "
    "panel seams, riveted plates, small vents, drainage grates and a few painted hazard marking "
    "strips. Even cool studio lighting, ambient occlusion only inside the seams, crisp "
    "restrained cel shading, clean hard-edged linework, painted industrial materials, keep the "
    "middle open and uncluttered so game units read clearly on top. "
    "No characters, no people, no soldiers, no vehicles, no crates, no props, no text, no "
    "letters, no numbers, no UI, no frame, no border. "
)

MAP_NEGATIVE = (
    "people, human, soldier, character, figure, mech, robot, vehicle, crate, box, barrel, prop, "
    "equipment, stacked objects, text, letters, numbers, watermark, logo, ui, frame, border, "
    "vignette, dark corner"
)

GATE_PROMPT = (
    "Top-down game asset of a rectangular enemy spawn gate for an original anime tower defense "
    "game: a rectangular hatch recessed into a metal floor, the opening filled with a glowing "
    "deep red-orange void, heavy riveted steel frame with warning chevrons and two short metal "
    "clamps, viewed from directly above, centered, filling most of the frame, on a perfectly "
    "uniform solid dark charcoal background with generous margins, no cast shadow on the "
    "background, crisp restrained cel shading, clean hard-edged linework, no text, no letters, "
    "no numbers, no UI, no extra objects"
)

CORE_PROMPT = (
    "Top-down game asset of a compact defense core generator for an original anime tower defense "
    "game: an armored circular housing with a glowing cyan energy ring and a small bright core in "
    "the middle, ivory-white plating, graphite metal, tiny orange signal lights, viewed from "
    "directly above, centered, filling most of the frame, on a perfectly uniform solid dark "
    "charcoal background with generous margins, no cast shadow on the background, crisp "
    "restrained cel shading, clean hard-edged linework, no text, no letters, no numbers, no UI, "
    "no extra objects"
)

PRESETS = {
    "map_alpha": {
        "landscape": True,
        "width": 1024,
        "height": 1024,
        "seed": 51201,
        "prompt": FLOOR_COMMON
        + "Palette: pale ivory-white composite plating over cool grey steel, signal orange accents.",
    },
    "map_beta": {
        "landscape": True,
        "width": 1024,
        "height": 1024,
        "seed": 51217,
        "prompt": FLOOR_COMMON
        + "Palette: warm light sand and bone-white ceramic plating with brushed steel bands and "
        "amber signal accents, faint desert dust in the seams.",
    },
    "map_gamma": {
        "landscape": True,
        "width": 1024,
        "height": 1024,
        "seed": 51233,
        "prompt": FLOOR_COMMON
        + "Palette: cool pale blue-grey plating with glassy cyan inlays and pale steel trim, "
        "subtle condensation highlights.",
    },
    "gate": {
        "landscape": True,
        "width": 1024,
        "height": 1024,
        "seed": 51249,
        "prompt": GATE_PROMPT,
    },
    "core": {
        "landscape": True,
        "width": 1024,
        "height": 1024,
        "seed": 51265,
        "prompt": CORE_PROMPT,
    },
}

gen.PRESETS.update(PRESETS)


def main() -> None:
    names = sys.argv[1:]
    if not names or names == ["all"]:
        names = list(PRESETS)
    gen.NEGATIVE = MAP_NEGATIVE
    for name in names:
        if name not in PRESETS:
            raise SystemExit(f"unknown preset: {name}")
        gen.generate(name)


if __name__ == "__main__":
    main()
