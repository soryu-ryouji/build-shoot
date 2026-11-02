#!/usr/bin/env python3
"""Generate the game's art through the local ComfyUI qwen_workflow."""

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
    "menu": {
        "landscape": False,
        "width": 768,
        "height": 1024,
        "seed": 41051,
        "prompt": (
            "Portrait key visual for an original anime tactical tower defense game. A beautiful "
            "adult anime woman tactical operator, full body standing on the right half, ash "
            "silver short hair, amber eyes, calm confident expression, practical opaque black "
            "and warm ivory tactical uniform with signal orange accents, angular coat and "
            "utility equipment, no existing copyrighted character. Bright cool light-gray "
            "industrial interior with metal beams and subtle warning stripes, high-end Japanese "
            "anime game illustration, crisp cel shading, detailed clean face, elegant dynamic "
            "silhouette, quiet light lower-left area for menu UI, no other people, no text, "
            "no letters, no numbers, no logo, no border, no UI, no interface panels, no icons"
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
    "turrets": {
        "landscape": True,
        "seed": 58163,
        "prompt": (
            "Two separate original anime tactical defense turret sprites for a 2D tower "
            "defense game, strict orthographic top-down view, side by side on a perfectly "
            "uniform solid very dark charcoal background. Both barrels point straight toward "
            "the top edge, bases centered below the barrels. Japanese anime game illustration, "
            "crisp cel shading, angular graphite mechanisms, warm ivory armor plates and "
            "signal orange energy cores. Left: compact rapid-fire turret with a large circular "
            "base and one short sturdy barrel. Right: heavy siege turret with a broad hexagonal "
            "armored base and two parallel reinforced barrels. No humans, readable at small "
            "size, generous empty margins, no perspective tilt, no text, no letters, no numbers, "
            "no border, no UI, no extra objects"
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


def generate(name: str) -> None:
    preset = PRESETS[name]
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
    parser.add_argument("preset", choices=[*PRESETS, "base", "units", "animations", "all"])
    args = parser.parse_args()
    if args.preset == "all":
        names = PRESETS
    elif args.preset == "base":
        names = ["arena", "menu", "monsters", "turrets"]
    elif args.preset == "units":
        names = ["monsters", "turrets"]
    elif args.preset == "animations":
        names = [f"anim_{kind}" for kind in ANIMATION_PRESETS]
    else:
        names = [args.preset]
    for name in names:
        generate(name)


if __name__ == "__main__":
    main()
