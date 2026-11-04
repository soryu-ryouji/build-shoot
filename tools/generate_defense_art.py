#!/usr/bin/env python3
"""Generate base and nest sprites through the local ComfyUI API."""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
import uuid
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = Path.home() / ".agents" / "skills" / "comfyui" / "workflows" / "qwen_image_2_1_t2i_gguf.json"
OUTPUT = ROOT / "assets" / "ui" / "source"
BASE_URL = "http://127.0.0.1:8188"
PRESETS = {
    "base_core": (
        91307,
        "Single isolated 2D game sprite of a central defense base for an anime tactical tower "
        "defense game, strict orthographic top-down view. A broad hexagonal industrial command "
        "fortress with layered warm ivory armor, graphite metal mechanisms, a protected glowing "
        "cyan energy core in the center, small signal orange warning marks, radial structural "
        "supports, readable symmetrical silhouette, no long shadows. Crisp restrained cel shading, "
        "detailed clean game asset, centered with generous empty margins on a perfectly uniform "
        "vivid chroma key green background. No terrain, no text, no letters, no numbers, no logo, "
        "no UI, no people, no turrets, no extra objects."
    ),
    "nest": (
        91319,
        "Single isolated 2D game sprite of a hostile biomechanical monster nest for an anime "
        "tactical tower defense game, strict orthographic top-down view. A round organic armored "
        "burrow with layered graphite black and dark violet plates, ivory bone-like outer spikes, "
        "a deep open central cavity glowing with restrained signal orange energy, wet organic "
        "details confined to the nest, readable radial silhouette, no long shadows. Crisp cel "
        "shading, detailed clean game asset, centered with generous empty margins on a perfectly "
        "uniform vivid chroma key green background. No terrain, no creatures outside the nest, "
        "no text, no letters, no numbers, no logo, no UI, no extra objects."
    ),
}


def request_json(path: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(BASE_URL + path, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def generate(name: str, seed: int, prompt: str) -> None:
    workflow = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    workflow["471"]["inputs"]["prompt"] = prompt
    workflow["474"]["inputs"]["width"] = 1024
    workflow["474"]["inputs"]["height"] = 1024
    workflow["476"]["inputs"]["seed"] = seed
    result = request_json("/prompt", {"prompt": workflow, "client_id": str(uuid.uuid4())})
    prompt_id = result["prompt_id"]
    print(f"{name} queued: {prompt_id}", flush=True)
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        history = request_json(f"/history/{prompt_id}")
        if prompt_id not in history:
            time.sleep(2)
            continue
        entry = history[prompt_id]
        if entry.get("status", {}).get("status_str") == "error":
            raise RuntimeError(json.dumps(entry, ensure_ascii=False))
        images = entry.get("outputs", {}).get("461", {}).get("images", [])
        if not images:
            raise RuntimeError(f"ComfyUI completed without images: {entry}")
        image = images[0]
        query = urllib.parse.urlencode({"filename": image["filename"], "subfolder": image.get("subfolder", ""), "type": image.get("type", "output")})
        with urllib.request.urlopen(f"{BASE_URL}/view?{query}", timeout=60) as response:
            content = response.read()
        OUTPUT.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        target = OUTPUT / f"{name}_{stamp}.png"
        target.write_bytes(content)
        print(f"saved: {target.relative_to(ROOT)}", flush=True)
        return
    raise TimeoutError(f"{name} generation exceeded five minutes")


def main() -> None:
    for name, (seed, prompt) in PRESETS.items():
        generate(name, seed, prompt)


if __name__ == "__main__":
    main()
