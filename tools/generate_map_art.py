#!/usr/bin/env python3
"""Generate the industrial floor source texture through the local ComfyUI API."""

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

PROMPT = (
    "Seamless tileable 2D game environment texture, strict orthographic top-down view of a "
    "bright industrial metal plaza floor. Large warm ivory and cool light-gray metal panels, "
    "subtle recessed panel seams, small screws, sparse vents, faint scratches and restrained "
    "signal orange maintenance marks. Flat even lighting, crisp restrained anime cel shading, "
    "low contrast, clean playable surface, consistent detail scale across the whole image. "
    "The pattern continues naturally across all four edges. No perspective, no horizon, no "
    "raised machines, no large objects, no central composition, no border, no grid overlay, "
    "no people, no enemies, no turrets, no text, no letters, no numbers, no logo, no UI."
)


def request_json(path: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        BASE_URL + path,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    workflow = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    workflow["471"]["inputs"]["prompt"] = PROMPT
    workflow["474"]["inputs"]["width"] = 1024
    workflow["474"]["inputs"]["height"] = 1024
    workflow["476"]["inputs"]["seed"] = 82417
    result = request_json("/prompt", {"prompt": workflow, "client_id": str(uuid.uuid4())})
    prompt_id = result["prompt_id"]
    print(f"queued: {prompt_id}", flush=True)

    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        history = request_json(f"/history/{prompt_id}")
        if prompt_id not in history:
            time.sleep(2)
            continue
        entry = history[prompt_id]
        status = entry.get("status", {})
        if status.get("status_str") == "error":
            raise RuntimeError(json.dumps(entry, ensure_ascii=False))
        images = entry.get("outputs", {}).get("461", {}).get("images", [])
        if not images:
            raise RuntimeError(f"ComfyUI completed without images: {entry}")
        OUTPUT.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        for index, image in enumerate(images):
            query = urllib.parse.urlencode({
                "filename": image["filename"],
                "subfolder": image.get("subfolder", ""),
                "type": image.get("type", "output"),
            })
            with urllib.request.urlopen(f"{BASE_URL}/view?{query}", timeout=60) as response:
                content = response.read()
            suffix = "" if index == 0 else f"_{index + 1}"
            target = OUTPUT / f"industrial_tiles_{stamp}{suffix}.png"
            target.write_bytes(content)
            print(f"saved: {target.relative_to(ROOT)}", flush=True)
        return
    raise TimeoutError("ComfyUI generation exceeded five minutes")


if __name__ == "__main__":
    main()
