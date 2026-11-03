#!/usr/bin/env python3
"""Generate the game's art through the local ComfyUI qwen_workflow.

The human/AI-readable prompt catalog is generated into ART_PROMPTS.md by
tools/render_art_prompts.py. Keep the presets here as the source of truth.
"""

from __future__ import annotations

import argparse
import json
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / "tools" / "qwen_workflow.source.json"
OUTPUT = ROOT / "assets" / "ui" / "source"
BASE_URL = "http://127.0.0.1:8188"

PRESETS = {
    "arena": {
        "landscape": False,
        "width": 768,
        "height": 1024,
        "seed": 41027,
        "prompt": (
            "Full-screen vertical environment for an original anime tactical tower defense "
            "game, strict orthographic top-down view, bright cool light-gray concrete and "
            "off-white metal. The flat combat plaza spans 88 percent of the image width, "
            "from 6 percent to 94 percent, with no raised structures inside this wide area; "
            "the surrounding left, right, top and bottom edges continue the same map with "
            "industrial platforms, recessed machinery, vents, rails, panel seams and sparse "
            "signal orange warning stripes. Dark mechanical entrance structures along the "
            "top, side details confined to narrow outer maintenance strips, integrated lower "
            "industrial platform. "
            "High-end Japanese anime game environment art, crisp restrained cel shading, "
            "low contrast and no obstacles in the central play area. No humans, no enemies, "
            "no turrets, no text, no letters, no numbers, no logo, no UI, no border"
        ),
    },
    "menu_bg": {
        "landscape": False,
        "width": 768,
        "height": 1024,
        "seed": 52273,
        "prompt": (
            "Portrait background plate for an original anime tactical tower defense game set "
            "in a world of colossal mobile industrial cities. An immense nomadic city "
            "megastructure stands on the horizon: a colossal armored crawler fortress carried "
            "on gigantic treaded legs and hydraulic struts, stacked arcology towers, cranes, "
            "gantries, hanging modules, pipes, antenna masts and thousands of tiny warm lights, "
            "its silhouette dissolving into pale atmospheric haze and low clouds. In the "
            "foreground a wide steel observation deck with a safety railing spans the entire "
            "bottom edge of the frame, empty and walkable, with industrial panels and pipes. "
            "Tiny transport vehicles and walkways "
            "give mile-deep scale to the megastructure. Cool light-gray and off-white "
            "industrial palette with restrained signal orange accents, bright overcast light, "
            "high-end Japanese anime game key visual, crisp cel shading, detailed clean "
            "rendering, cinematic vertical composition, open bright sky in the upper left for "
            "a game logo, quiet bright lower-left area for menu UI. No humans, no characters, "
            "no people, no text, no letters, no numbers, no logo, no border, no UI, no "
            "interface panels, no icons"
        ),
    },
    "menu_character": {
        "landscape": False,
        "width": 768,
        "height": 1024,
        "seed": 52273,
        "prompt": (
            "Full body character art of an original anime tactical operator woman for a game "
            "key visual, standing upright, seen from behind at a three-quarter angle, facing "
            "away toward the upper left, ash silver short hair, long graphite and warm ivory "
            "tactical coat with signal orange trim, dark trousers and black boots, hands "
            "relaxed at her sides, calm relaxed posture. High-end Japanese anime game "
            "illustration, crisp cel shading, detailed clean rendering, soft overcast rim "
            "light from above and behind, the whole figure from the top of the head down to "
            "the boot soles fully visible with generous empty margins, isolated on a perfectly "
            "uniform solid chroma key green background, vivid pure green backdrop, clean edge "
            "separation between the figure and the green. No scenery, no platform, no railing, "
            "no other people, no text, no letters, no numbers, no logo, no border, no UI"
        ),
    },
    "monsters": {
        "landscape": True,
        "width": 1024,
        "height": 1024,
        "seed": 73019,
        "prompt": (
            "A 2D game sprite sheet with exactly four separate original anime tactical "
            "bio-mechanical enemy creatures in an exact two by two grid, orthographic "
            "top-down view, each centered in its quadrant on a perfectly uniform solid "
            "very dark charcoal background. Japanese anime game illustration with crisp "
            "cel shading, graphite black armor, warm ivory plates and signal orange cores. "
            "Top left: normal compact four-legged mechanical hound with a dark body and "
            "ivory head plate. Top right: swift lean winged predator with swept fins and "
            "a narrow agile silhouette. Bottom left: armored bulky crab beast with very "
            "thick layered ivory plating and heavy legs. Bottom right: elite tall spiked "
            "bio-mechanical beast with black violet armor and a bright orange core. No humans. "
            "Readable silhouettes at small size, similar visual scale, generous empty margins, "
            "no text, no letters, no numbers, no dividers, no border, no UI, no extra objects"
        ),
    },
    "turret_base": {
        "landscape": True,
        "seed": 65201,
        "prompt": (
            "Single isolated 2D game sprite of a circular turret mounting plate seen in a "
            "strict orthographic top-down view with the camera pointing straight down. "
            "Perfectly circular and radially symmetric like a flat technical diagram: "
            "concentric metal rings, a recessed dark circular socket in the center, evenly "
            "spaced bolts and vent slits around the rim, warm ivory and graphite gray metal "
            "with a few small amber indicator lights. Completely flat even lighting, no "
            "shadows, no highlights, no glossy reflections, no perspective, no tilt, no "
            "visible inner wall, no three dimensional bevel, thin crisp cel-shaded lines, "
            "Japanese anime game asset, centered on a perfectly uniform solid very dark "
            "charcoal background, generous empty margins, no turret body, no barrel, no gun, "
            "no text, no letters, no numbers, no border, no UI, no extra objects"
        ),
    },
    "heavy_turret_base": {
        "landscape": True,
        "seed": 65213,
        "prompt": (
            "Single isolated 2D game sprite of a broad regular octagonal turret mounting "
            "plate seen in a strict orthographic top-down view with the camera pointing "
            "straight down. Eight sided plate with exact eight fold rotational symmetry, "
            "like a flat technical diagram: concentric metal rings, a recessed dark circular "
            "socket in the center, evenly spaced bolts and vent slits, layered warm ivory and "
            "graphite gray plates with a few small amber indicator lights. Completely flat "
            "even lighting, no shadows, no highlights, no glossy reflections, no perspective, "
            "no tilt, no visible inner wall, no three dimensional bevel, thin crisp cel-shaded "
            "lines, Japanese anime game asset, centered on a perfectly uniform solid very dark "
            "charcoal background, generous empty margins, no turret body, no barrel, no gun, "
            "no text, no letters, no numbers, no border, no UI, no extra objects"
        ),
    },
    "turret_layers": {
        "landscape": True,
        "seed": 64103,
        "prompt": (
            "Two separate original anime defense turret parts for a 2D tower defense game, "
            "arranged vertically on a perfectly uniform solid very dark charcoal background, "
            "both drawn in the same strict orthographic top-down view as if seen from directly "
            "above. Bottom: a compact circular armored base plate with a recessed empty "
            "circular bowl in the middle, panel seams, bolts, vents and small amber lights, "
            "with no turret body and no barrel on it. Top: the turret head that fits into that "
            "bowl, a graphite and warm ivory gun housing with one short sturdy barrel pointing "
            "straight up toward the top edge and a glowing signal orange energy core, with no "
            "base plate beneath it. A clear empty gap of plain background separates the two "
            "parts. Japanese anime game illustration, crisp cel shading, angular graphite "
            "mechanisms, warm ivory armor plates, signal orange accents. Both parts share the "
            "same vertical center axis, readable silhouettes, generous empty margins, no "
            "humans, no perspective tilt, no text, no letters, no numbers, no dividers, no "
            "border, no UI, no extra objects"
        ),
    },
    "heavy_turret_layers": {
        "landscape": True,
        "seed": 64117,
        "prompt": (
            "Two separate original anime defense turret parts for a 2D tower defense game, "
            "arranged vertically on a perfectly uniform solid very dark charcoal background, "
            "both drawn in the same strict orthographic top-down view as if seen from directly "
            "above. Bottom: a broad hexagonal armored base plate with a recessed empty "
            "circular bowl in the middle, layered ivory and graphite plates, panel seams and "
            "orange warning lights, with no turret body and no barrel on it. Top: the heavy "
            "turret head that fits into that bowl, a massive graphite and warm ivory gun "
            "housing with two parallel reinforced barrels pointing straight up toward the top "
            "edge and glowing signal orange energy cores, with no base plate beneath it. A "
            "clear empty gap of plain background separates the two parts. Japanese anime game "
            "illustration, crisp cel shading, angular graphite mechanisms, warm ivory armor "
            "plates, signal orange accents. Both parts share the same vertical center axis, "
            "readable silhouettes, generous empty margins, no humans, no perspective tilt, no "
            "text, no letters, no numbers, no dividers, no border, no UI, no extra objects"
        ),
    },
    "laser_base": {
        "landscape": True,
        "seed": 65231,
        "reference": "turret.png",
        "style_reference": True,
        "prompt": (
            "Single isolated 2D game sprite of a compact circular laser turret mounting plate, "
            "strict orthographic top-down view from directly above, rendered as a physical "
            "three-dimensional object with visible plate thickness, side walls and natural "
            "foreshortening rather than a flat icon. Concentric layered metal rings with a "
            "recessed dark circular socket in the center, evenly spaced bolts, thin vent slits "
            "and a ring of small pale cyan power indicators, warm ivory ceramic armor and "
            "graphite gunmetal plates with a few signal orange accent lights. No turret body, "
            "no emitter, no barrel, no gun. High-end Japanese anime tactical game asset in the "
            "style of Arknights, crisp restrained cel shading, clean hard-edged linework, soft "
            "ambient occlusion, centered on a perfectly uniform solid very dark charcoal "
            "background, generous empty margins, no cast shadow on the background, no text, no "
            "letters, no numbers, no border, no UI, no extra objects"
        ),
    },
    "laser_layers": {
        "landscape": True,
        "seed": 64129,
        "reference": "turret.png",
        "style_reference": True,
        "prompt": (
            "Two separate original anime laser defense turret parts for a 2D tower defense "
            "game, arranged vertically on a perfectly uniform solid very dark charcoal "
            "background, both drawn in the same strict orthographic top-down view as if seen "
            "from directly above, with visible physical thickness and natural foreshortening "
            "rather than flat icons. Bottom: a compact circular armored mounting plate with a "
            "recessed empty circular socket, concentric rings, bolts and cyan power indicators, "
            "no turret body and no barrel on it. Top: the laser emitter head that fits into "
            "that socket, a narrow graphite and warm ivory housing with one long slender "
            "emitter barrel pointing straight up toward the top edge, a glowing pale cyan lens "
            "at the muzzle, copper coil rings and small signal orange capacitor lights, with no "
            "base plate beneath it. A clear empty gap of plain background separates the two "
            "parts. High-end Japanese anime tactical game asset in the style of Arknights, "
            "crisp restrained cel shading, angular graphite mechanisms, warm ivory armor "
            "plates, signal orange accents, pale cyan energy details. Both parts share the same "
            "vertical center axis, readable silhouettes, generous empty margins, no humans, no "
            "text, no letters, no numbers, no dividers, no border, no UI, no extra objects"
        ),
    },
    "sandbag": {
        "landscape": True,
        "seed": 65301,
        "reference": "turret.png",
        "prompt": (
            "Using the supplied reference image only for rendering style, linework, cel shading "
            "and material language, do not copy its turret shape or any mechanical gun parts. "
            "Create a single isolated 2D game sprite of a low sandbag barricade for a top-down "
            "anime tactical tower defense game. Camera pointing straight down from directly "
            "above, the top surfaces of the bags dominate the image and only a thin front edge "
            "is visible, with correct foreshortening and visible physical thickness rather than "
            "a flat icon. A compact square low wall segment built from three rows and three "
            "columns of tan canvas sandbags with visible seams, creases and slightly varied bag "
            "shapes, held by two small graphite metal stakes. No base plate, no wheels, no "
            "people, no turret, no gun, no barrel. Hand-painted 2D anime tactical game asset in "
            "the style of Arknights, bold clean outlines, two-tone crisp cel shading, flat "
            "restrained colors, warm sand canvas and graphite accents, soft ambient occlusion, "
            "centered on a perfectly uniform solid very dark charcoal background, generous empty "
            "margins, no cast shadow on the background, no text, no letters, no numbers, no "
            "border, no UI, no extra objects, no photorealism, no soft 3D render"
        ),
    },
    "compression_tower": {
        "landscape": True,
        "seed": 65317,
        "reference": "turret.png",
        "style_reference": True,
        "prompt": (
            "Single isolated 2D game sprite of a compact compression energy tower for a top-down "
            "anime tactical tower defense game. Strict orthographic top-down view from directly "
            "above, rendered as a physical three-dimensional object with visible thickness, side "
            "walls, panel seams and natural foreshortening rather than a flat icon. A broad "
            "octagonal graphite base with layered warm ivory armor plates, two short vertical "
            "tuning prongs, a glowing pale cyan compression core in the center, copper coil "
            "rings, thin vents and small signal orange warning lights. No gun barrel, no "
            "sandbags, no people. High-end Japanese anime tactical game asset in the style of "
            "Arknights, crisp restrained cel shading, clean hard-edged linework, soft ambient "
            "occlusion, centered on a perfectly uniform solid very dark charcoal background, "
            "generous empty margins, no cast shadow on the background, no text, no letters, no "
            "numbers, no border, no UI, no extra objects"
        ),
    },
    "solar": {
        "landscape": True,
        "seed": 65333,
        "reference": "turret.png",
        "style_reference": True,
        "prompt": (
            "Single isolated 2D game sprite of a small ground-mounted solar panel array for a "
            "top-down anime tactical tower defense game. Strict orthographic top-down view from "
            "directly above, with the four dark blue photovoltaic panels tilted a few degrees "
            "so their physical thickness, pale metal grid lines, ivory frame and low graphite "
            "mounting legs are visible with correct foreshortening rather than a flat icon. "
            "Two by two cells with thin pale separation lines, a small signal orange status "
            "lamp, industrial bolts and a compact base. No people, no text on the panels. "
            "High-end Japanese anime tactical game asset in the style of Arknights, crisp "
            "restrained cel shading, clean hard-edged linework, soft ambient occlusion, "
            "centered on a perfectly uniform solid very dark charcoal background, generous "
            "empty margins, no cast shadow on the background, no letters, no numbers, no "
            "border, no UI, no extra objects"
        ),
    },
    "fusion_tower": {
        "landscape": True,
        "seed": 65349,
        "reference": "turret.png",
        "style_reference": True,
        "prompt": (
            "Single isolated 2D game sprite of a compact fusion power tower for a top-down anime "
            "tactical tower defense game. Strict orthographic top-down view from directly above, "
            "rendered as a physical three-dimensional object with visible thickness, side walls "
            "and natural foreshortening rather than a flat icon. A cylindrical reactor core "
            "with a glowing warm golden plasma center, heavy graphite ring frame, layered warm "
            "ivory armor segments, copper coil rings, thin industrial vents and small signal "
            "orange energy arcs. No gun barrel, no people. High-end Japanese anime tactical "
            "game asset in the style of Arknights, crisp restrained cel shading, clean "
            "hard-edged linework, soft ambient occlusion, centered on a perfectly uniform solid "
            "very dark charcoal background, generous empty margins, no cast shadow on the "
            "background, no text, no letters, no numbers, no border, no UI, no extra objects"
        ),
    },
}

ANIMATION_PRESETS = {
    "normal": {"seed": 83101, "motion": "alternating beetle leg steps and a subtle body bob"},
    "swift": {"seed": 83117, "motion": "small wing flaps and a gentle hovering bob"},
    "armored": {"seed": 83133, "motion": "slow alternating crab leg steps and heavy body sway"},
    "elite": {"seed": 83149, "motion": "deliberate leg steps, slight spike motion and a pulsing core"},
}
for _kind, _config in ANIMATION_PRESETS.items():
    PRESETS[f"anim_{_kind}"] = {
        "landscape": True,
        "width": 1024,
        "height": 1024,
        "seed": _config["seed"],
        "reference": f"monster_{_kind}.png",
        "prompt": (
            f"Using the supplied reference creature, create a four-frame 2D game animation "
            f"sprite sheet in an exact two by two grid. All four frames show the SAME "
            f"character with identical colors, proportions, armor details, orthographic "
            f"top-down camera and facing direction. Animate only {_config['motion']}. "
            "Frame one top left, frame two top right, frame three bottom left, frame four "
            "bottom right. Each full body is centered at the same position and scale within "
            "its quadrant, on a perfectly uniform solid very dark navy background. Make "
            "the motion subtle and loopable, with no redesign between frames. Crisp clean "
            "silhouettes, no text, no letters, no numbers, no dividers, no border, no UI, "
            "no extra objects"
        ),
    }

NEGATIVE = "text, letters, words, numbers, watermark, logo, bright white background, cluttered center"

# 以现有炮塔贴图作为风格参考；提示词只借用画风，不复制它的炮塔造型。
STYLE_REFERENCE_PREFIX = (
    "Using the supplied reference image only for rendering style, linework, cel shading and "
    "material language, do not copy its turret shape, gun, barrel or base plate. "
)


def request_json(path: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        BASE_URL + path,
        data=data,
        headers={"Content-Type": "application/json"} if data else {},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def upload_reference(path: Path) -> str:
    boundary = f"----build-shoot-{uuid.uuid4().hex}"
    body = bytearray()
    for name, value in (("type", "input"), ("overwrite", "true")):
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        body.extend(f"{value}\r\n".encode())
    body.extend(f"--{boundary}\r\n".encode())
    body.extend(
        f'Content-Disposition: form-data; name="image"; filename="{path.name}"\r\n'.encode()
    )
    body.extend(b"Content-Type: image/png\r\n\r\n")
    body.extend(path.read_bytes())
    body.extend(f"\r\n--{boundary}--\r\n".encode())
    request = urllib.request.Request(
        BASE_URL + "/upload/image",
        data=bytes(body),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        result = json.load(response)
    return result["name"]


def api_workflow(preset: dict, prefix: str, reference_name: str = "") -> dict:
    source = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    links = {link[0]: link for link in source["links"]}
    graph = {}
    for node in source["nodes"]:
        node_id = str(node["id"])
        if node["type"] == "SaveImageAdvanced":
            # Standard SaveImage has the same PNG output with a simpler API schema.
            graph[node_id] = {
                "class_type": "SaveImage",
                "inputs": {"images": ["475", 0], "filename_prefix": prefix},
            }
            continue

        inputs = {}
        for socket in node.get("inputs", []):
            name = socket["name"]
            if socket.get("link") is not None:
                link = links[socket["link"]]
                inputs[name] = [str(link[1]), link[2]]
            elif name in node.get("widgets_values_named", {}):
                inputs[name] = node["widgets_values_named"][name]
        graph[node_id] = {"class_type": node["type"], "inputs": inputs}

    graph["471"]["inputs"]["prompt"] = preset["prompt"]
    graph["471"]["inputs"]["negative_prompt"] = NEGATIVE
    graph["476"]["inputs"]["seed"] = preset["seed"]
    graph["479"]["inputs"]["switch"] = preset["landscape"]
    if "width" in preset:
        for latent_id in ("474", "480"):
            graph[latent_id]["inputs"]["width"] = preset["width"]
            graph[latent_id]["inputs"]["height"] = preset["height"]
    if reference_name:
        graph["900"] = {"class_type": "LoadImage", "inputs": {"image": reference_name}}
        graph["471"]["inputs"]["images.image_1"] = ["900", 0]
        graph["471"]["inputs"]["vae"] = ["473", 0]
    return graph


def generate(name: str, seed: int | None = None) -> None:
    preset = PRESETS[name]
    if seed is not None:
        preset = {**preset, "seed": seed}
    if preset.get("style_reference"):
        preset = {**preset, "prompt": STYLE_REFERENCE_PREFIX + preset["prompt"]}
    prefix = f"build_shoot/{name}"
    reference_name = ""
    if "reference" in preset:
        reference_name = upload_reference(ROOT / "assets" / "ui" / preset["reference"])
        print(f"[{name}] reference uploaded: {reference_name}", flush=True)
    result = request_json(
        "/prompt",
        {"prompt": api_workflow(preset, prefix, reference_name), "client_id": str(uuid.uuid4())},
    )
    prompt_id = result["prompt_id"]
    print(f"[{name}] queued: {prompt_id}", flush=True)

    while True:
        history = request_json(f"/history/{prompt_id}")
        if prompt_id in history:
            entry = history[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(json.dumps(entry, ensure_ascii=False))
            images = []
            for output in entry.get("outputs", {}).values():
                images.extend(output.get("images", []))
            if not images:
                raise RuntimeError(f"ComfyUI completed without images: {entry}")
            OUTPUT.mkdir(parents=True, exist_ok=True)
            for index, image in enumerate(images):
                query = urllib.parse.urlencode(
                    {
                        "filename": image["filename"],
                        "subfolder": image.get("subfolder", ""),
                        "type": image.get("type", "output"),
                    }
                )
                with urllib.request.urlopen(f"{BASE_URL}/view?{query}", timeout=60) as response:
                    content = response.read()
                suffix = "" if index == 0 else f"_{index + 1}"
                target = OUTPUT / f"{name}{suffix}.png"
                target.write_bytes(content)
                print(f"[{name}] saved: {target.relative_to(ROOT)}", flush=True)
            return
        time.sleep(2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "preset",
        choices=[*PRESETS, "base", "units", "buildings", "animations", "all"],
    )
    parser.add_argument("--seed", type=int, help="覆盖预设种子，用于挑选画面")
    args = parser.parse_args()
    if args.preset == "all":
        names = PRESETS
    elif args.preset == "menu":
        names = ["menu_bg", "menu_character"]
    elif args.preset == "base":
        names = [
            "arena",
            "menu_bg",
            "menu_character",
            "monsters",
            "turret_base",
            "heavy_turret_base",
            "laser_base",
            "turret_layers",
            "heavy_turret_layers",
            "laser_layers",
            "sandbag",
            "compression_tower",
            "solar",
            "fusion_tower",
        ]
    elif args.preset == "units":
        names = [
            "monsters",
            "turret_base",
            "heavy_turret_base",
            "laser_base",
            "turret_layers",
            "heavy_turret_layers",
            "laser_layers",
        ]
    elif args.preset == "buildings":
        names = ["sandbag", "compression_tower", "solar", "fusion_tower"]
    elif args.preset == "animations":
        names = [f"anim_{kind}" for kind in ANIMATION_PRESETS]
    else:
        names = [args.preset]
    for name in names:
        generate(name, args.seed)


if __name__ == "__main__":
    main()
