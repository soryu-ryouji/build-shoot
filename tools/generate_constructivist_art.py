#!/usr/bin/env python3
"""Generate constructivist-pattern turret samples through local ComfyUI."""

from generate_defense_art import generate

PRESETS = {
    "construct_turret_base": (
        104729,
        "Single isolated 2D game sprite of a circular turret mounting plate, strict orthographic "
        "top-down view, flat even lighting. Russian constructivist geometric pattern language: "
        "eccentric concentric rings, interrupted circular arcs, diagonal partitions, rectangular "
        "cut-ins, intersecting straight axes and deliberate negative space. The pattern is "
        "integrated into the armor panels, not a printed logo. Warm ivory armor, graphite gray "
        "metal and the same restrained signal orange accents as the reference game, crisp hard-edged "
        "cel shading, clean large shapes, asymmetrical balance, no realistic clutter, no tiny bolts. "
        "Perfectly centered on a uniform vivid chroma key green background with generous margins. "
        "No turret body, no gun barrel, no text, no letters, no numbers, no logo, no UI, no extra objects."
    ),
    "construct_turret_head": (
        104741,
        "Single isolated 2D game sprite of a turret upper body without any mounting plate, strict "
        "orthographic top-down view, one narrow straight gun barrel pointing directly upward along "
        "the vertical center axis. Russian constructivist geometric pattern language: rectangular "
        "receiver blocks organized along the barrel axis, diagonal armor divisions, offset trapezoid "
        "panels, intersecting straight lines, stepped negative space and asymmetrical balance. "
        "Patterns are actual armor panel divisions, not decals. Warm ivory armor, graphite gray "
        "mechanisms and restrained signal orange accents, crisp hard-edged cel shading, clean large "
        "shapes, no realistic clutter, no tiny bolts. Centered on a uniform vivid chroma key green "
        "background with the entire barrel and body visible. No base, no text, no letters, no numbers, "
        "no logo, no UI, no extra objects."
    ),
}


def main() -> None:
    for name, (seed, prompt) in PRESETS.items():
        generate(name, seed, prompt)


if __name__ == "__main__":
    main()
