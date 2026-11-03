"""用 Blender 生成 2.5D 地块贴片：地板、路面（按四向连接拼）、高台、边框、缺口与核心。

每块贴片渲染成 64×64，1 世界单位 = 1 像素，格子地面中心落在图片中心 (32, 32)：
游戏里把贴片画在 (tile_center - 32, tile_center - 32) 就能无缝铺开。

用法：
  blender -b --factory-startup -P tools/build_tiles_3d.py -- --outdir assets/ui/tiles
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
CANVAS = 64
TILE_GROUND = 48.0
TILE_SCREEN_Y = 34.0
ELEV_SIN = TILE_SCREEN_Y / TILE_GROUND
CAM_X_ROT = math.pi / 2.0 - math.asin(ELEV_SIN)

PLATE = 46.0
DECK_Z = 4.0
HIGH_Z = 16.0
ROAD_W = 34.0


# ---------------------------------------------------------------- 场景工具

def reset_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            block.remove(item)


def material(name, color, roughness=0.5, metallic=0.1, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def box(name, center, size, mat, bevel=0.0, segments=2):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(center)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40.0)
    return obj


def cylinder(name, center, radius, depth, mat, vertices=48):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=vertices,
        radius1=radius,
        radius2=radius,
        depth=depth,
    )
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(center)
    obj.data.materials.append(mat)
    return obj


PALETTE = {
    # 明日方舟式压色：蓝灰底 + 中灰钢板 + 米白面板 + 琥珀色警示，猩红只给缺口
    "base": (0.080, 0.090, 0.100),
    "deck": (0.300, 0.315, 0.330),
    "plate": (0.400, 0.415, 0.430),
    "cream": (0.780, 0.775, 0.735),
    "amber": (0.860, 0.560, 0.150),
    "steel": (0.500, 0.520, 0.530),
    "red": (0.560, 0.090, 0.060),
    "cyan": (0.360, 0.820, 0.860),
}


def make_materials() -> dict:
    base = PALETTE["base"]
    return {
        "base": material("MAT-base", base, roughness=0.65, metallic=0.25),
        "deck": material("MAT-deck", PALETTE["deck"], roughness=0.5, metallic=0.45),
        "plate": material("MAT-plate", PALETTE["plate"], roughness=0.42, metallic=0.5),
        "cream": material("MAT-cream", PALETTE["cream"], roughness=0.45, metallic=0.2),
        "steel": material("MAT-steel", PALETTE["steel"], roughness=0.28, metallic=0.85),
        "dark": material("MAT-dark", (0.115, 0.125, 0.135), roughness=0.4, metallic=0.55),
        "amber": material("MAT-amber", PALETTE["amber"], roughness=0.35,
                          emission=PALETTE["amber"], strength=0.5),
        "red": material("MAT-red", PALETTE["red"], roughness=0.4,
                        emission=PALETTE["red"], strength=1.6),
        "cyan": material("MAT-cyan", PALETTE["cyan"], roughness=0.25,
                         emission=PALETTE["cyan"], strength=1.1),
    }


def screw(name: str, x: float, y: float, z: float, mats: dict) -> None:
    cylinder(name, (x, y, z), 1.4, 0.8, mats["steel"], vertices=12)


def hazard(name: str, y: float, z: float, width: float, mats: dict, count: int = 5) -> None:
    step = width / (count * 2 - 1)
    for i in range(count):
        box(f"{name}-{i}", (-width * 0.5 + step * (2 * i + 0.5), y, z),
            (step * 1.15, 2.0, 2.6), mats["amber"])


def build_floor(mats: dict, variant: int):
    # 整格蓝黑底座，相邻地块之间只留细缝
    box("GEO-gap", (0.0, 0.0, 1.0), (TILE_GROUND, TILE_GROUND, 2.0), mats["base"])
    box("GEO-deck", (0.0, 0.0, 4.0), (PLATE, PLATE, 5.0), mats["deck"], bevel=1.6)
    box("GEO-plate", (0.0, 0.0, 6.6), (PLATE - 8.0, PLATE - 8.0, 1.2), mats["plate"], bevel=1.0)
    if variant == 0:
        # 素板：只有面板缝和四角螺钉
        box("GEO-seam", (0.0, -2.0, 7.25), (PLATE - 18.0, 1.2, 0.4), mats["base"])
    elif variant == 1:
        # 米白面板
        box("GEO-cream", (0.0, 0.0, 7.35), (PLATE - 18.0, PLATE - 18.0, 1.0), mats["cream"], bevel=0.8)
        box("GEO-cream-line", (0.0, 0.0, 7.9), (PLATE - 22.0, PLATE - 22.0, 0.4), mats["deck"])
    elif variant == 2:
        # 琥珀色细边
        box("GEO-amber", (0.0, PLATE * 0.5 - 4.0, 7.2), (PLATE - 8.0, 1.6, 0.7), mats["amber"])
        box("GEO-seam", (-6.0, 0.0, 7.25), (1.2, PLATE - 18.0, 0.4), mats["base"])
    else:
        # 检修口 + 通风件
        box("GEO-hatch", (4.0, -4.0, 7.1), (18.0, 14.0, 0.9), mats["dark"], bevel=0.6)
        for i in range(3):
            box("GEO-slit", (0.5 + i * 4.0, -4.0, 7.6), (1.4, 10.0, 0.4), mats["base"])
        box("GEO-mark", (-14.0, 12.0, 7.3), (7.0, 1.8, 0.5), mats["amber"])
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            screw("GEO-screw", sx * 18.0, sy * 18.0, 7.3, mats)


def build_high(mats: dict):
    # 高台：深色侧壁 + 灰顶板 + 米白面板 + 正面琥珀警示条
    box("GEO-high", (0.0, 0.0, 7.5), (PLATE, PLATE, 15.0), mats["dark"], bevel=1.2)
    box("GEO-high-top", (0.0, 0.0, 16.2), (PLATE, PLATE, 3.0), mats["deck"], bevel=1.6)
    box("GEO-high-plate", (0.0, 0.0, 17.9), (PLATE - 8.0, PLATE - 8.0, 1.0), mats["plate"], bevel=1.0)
    box("GEO-high-cream", (0.0, 0.0, 18.5), (PLATE - 20.0, PLATE - 20.0, 0.9), mats["cream"], bevel=0.7)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            screw("GEO-screw", sx * 18.0, sy * 18.0, 18.4, mats)
    hazard("GEO-hazard", -PLATE * 0.5 - 0.2, 6.0, PLATE - 10.0, mats, count=4)


def build_rim(mats: dict):
    # 边界矮墙：深色墙体 + 灰顶 + 琥珀警示条
    box("GEO-rim", (0.0, 0.0, 13.0), (TILE_GROUND, TILE_GROUND, 26.0), mats["dark"], bevel=2.0)
    box("GEO-rim-top", (0.0, 0.0, 27.0), (PLATE, PLATE, 2.2), mats["deck"], bevel=1.6)
    box("GEO-rim-spine", (0.0, 0.0, 28.4), (PLATE - 18.0, PLATE - 18.0, 0.9), mats["steel"], bevel=0.7)
    hazard("GEO-rim-hazard", -TILE_GROUND * 0.5 - 0.2, 15.0, TILE_GROUND - 8.0, mats, count=5)
    for i in range(4):
        cylinder("GEO-rivet", (-15.0 + i * 10.0, -TILE_GROUND * 0.5 - 0.4, 22.5), 1.3, 1.0, mats["steel"], vertices=10)


def build_gate(mats: dict, direction: int):
    box("GEO-gap", (0.0, 0.0, 1.0), (TILE_GROUND, TILE_GROUND, 2.0), mats["base"])
    box("GEO-deck", (0.0, 0.0, 4.0), (PLATE, PLATE, 5.0), mats["deck"], bevel=1.6)
    box("GEO-socket", (0.0, 0.0, 7.0), (40.0, 40.0, 1.4), mats["base"], bevel=1.5)
    box("GEO-glow", (0.0, 0.0, 7.8), (32.0, 32.0, 1.2), mats["red"], bevel=1.0)
    frame = 43.0
    for dx, dy, sx, sy in ((0.0, -frame * 0.5, frame, 4.5), (0.0, frame * 0.5, frame, 4.5),
                           (-frame * 0.5, 0.0, 4.5, frame), (frame * 0.5, 0.0, 4.5, frame)):
        box("GEO-gate-frame", (dx, dy, 8.8), (sx, sy, 4.0), mats["steel"], bevel=1.0)
    angle = -math.tau * direction / 4.0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.rotation_euler.z += angle


def build_core(mats: dict):
    cylinder("GEO-core-base", (0.0, 0.0, 1.0), 38.0, 2.0, mats["base"], vertices=56)
    cylinder("GEO-core-body", (0.0, 0.0, 5.0), 34.0, 6.0, mats["dark"], vertices=56)
    cylinder("GEO-core-ring", (0.0, 0.0, 8.2), 26.0, 1.6, mats["steel"], vertices=56)
    cylinder("GEO-core-amber", (0.0, 0.0, 9.2), 21.0, 0.8, mats["amber"], vertices=48)
    cylinder("GEO-core-inner", (0.0, 0.0, 9.6), 14.0, 2.2, mats["cyan"], vertices=48)
    for i in range(6):
        angle = math.tau * i / 6.0
        box("GEO-core-clamp", (math.cos(angle) * 31.0, math.sin(angle) * 31.0, 6.0),
            (11.0, 8.0, 5.0), mats["steel"], bevel=1.2).rotation_euler = (0.0, 0.0, angle)


# ---------------------------------------------------------------- 装饰物

def build_prop_crates(mats):
    for i, (x, y, s, z) in enumerate(((-6.0, -4.0, 13.0, 6.5), (7.0, 2.0, 15.0, 7.5), (-2.0, 9.0, 10.0, 5.0))):
        box(f"GEO-crate-{i}", (x, y, z), (s, s, s), mats["deck"], bevel=1.2)
        box(f"GEO-crate-top-{i}", (x, y, z + s * 0.5 + 0.1), (s - 4.0, s - 4.0, 0.8), mats["cream"], bevel=0.4)
        box(f"GEO-crate-band-{i}", (x, y, z), (s + 0.4, 2.0, s * 0.6), mats["steel"], bevel=0.3)


def build_prop_pipes(mats):
    for offset in (-4.0, 4.0):
        cylinder("GEO-pipe", (0.0, offset, 7.0), 4.2, 30.0, mats["steel"], vertices=20).rotation_euler = (
            0.0, math.pi / 2.0, 0.0)
        box("GEO-pipe-band", (offset * 2.0, offset, 7.0), (2.5, 9.0, 9.0), mats["dark"], bevel=0.4)
    box("GEO-pipe-base", (0.0, 0.0, 3.0), (34.0, 18.0, 3.0), mats["deck"], bevel=1.0)


def build_prop_barrier(mats):
    box("GEO-barrier-foot-a", (-12.0, 0.0, 2.5), (6.0, 22.0, 5.0), mats["dark"], bevel=0.8)
    box("GEO-barrier-foot-b", (12.0, 0.0, 2.5), (6.0, 22.0, 5.0), mats["dark"], bevel=0.8)
    box("GEO-barrier-panel", (0.0, 0.0, 11.0), (30.0, 4.0, 12.0), mats["cream"], bevel=1.0)
    for i in range(3):
        box("GEO-barrier-stripe", (-8.0 + i * 8.0, 0.0, 11.0), (5.0, 4.4, 5.0), mats["amber"], bevel=0.3)


def build_prop_coil(mats):
    cylinder("GEO-coil", (0.0, 0.0, 4.0), 12.0, 8.0, mats["dark"], vertices=28)
    cylinder("GEO-coil-inner", (0.0, 0.0, 4.2), 6.0, 8.4, mats["steel"], vertices=24)
    box("GEO-coil-base", (0.0, 0.0, 1.2), (30.0, 24.0, 2.4), mats["deck"], bevel=0.8)
    box("GEO-coil-tag", (-10.0, 6.0, 8.6), (5.0, 3.0, 0.6), mats["amber"])


def build_prop_vent(mats):
    box("GEO-vent-body", (0.0, 0.0, 6.0), (26.0, 20.0, 12.0), mats["deck"], bevel=1.4)
    for i in range(4):
        box("GEO-vent-fin", (-9.0 + i * 6.0, 0.0, 12.4), (3.0, 14.0, 1.0), mats["steel"], bevel=0.3)
    box("GEO-vent-cream", (0.0, -9.0, 8.0), (20.0, 3.0, 6.0), mats["cream"], bevel=0.5)


PROPS = {
    "prop_crates": build_prop_crates,
    "prop_pipes": build_prop_pipes,
    "prop_barrier": build_prop_barrier,
    "prop_coil": build_prop_coil,
    "prop_vent": build_prop_vent,
}

# ---------------------------------------------------------------- 相机与渲染

def setup_camera() -> None:
    cam_data = bpy.data.cameras.new("CAM-tile")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = CANVAS
    cam_data.clip_start = 10.0
    cam_data.clip_end = 20000.0
    cam = bpy.data.objects.new("CAM-tile", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    distance = 3000.0
    cam.location = (0.0, -math.sin(CAM_X_ROT) * distance, math.cos(CAM_X_ROT) * distance)
    cam.rotation_euler = (CAM_X_ROT, 0.0, 0.0)
    bpy.context.scene.camera = cam


def setup_lights() -> None:
    sun_data = bpy.data.lights.new("LGT-sun", "SUN")
    sun_data.energy = 3.6
    sun_data.angle = math.radians(3.0)
    sun = bpy.data.objects.new("LGT-sun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-38.0))
    fill_data = bpy.data.lights.new("LGT-fill", "AREA")
    fill_data.energy = 11000.0
    fill_data.size = 300.0
    fill = bpy.data.objects.new("LGT-fill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (0.0, -260.0, 400.0)
    fill.rotation_euler = (math.radians(35.0), 0.0, 0.0)


def setup_render(out_path: Path, size: int = CANVAS) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filepath = str(out_path)
    world = bpy.data.worlds.new("WORLD-tile")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.32, 0.34, 0.36, 1.0)
    background.inputs["Strength"].default_value = 0.4
    scene.world = world


def render(name: str, builder, outdir: Path, size: int = CANVAS) -> None:
    reset_scene()
    mats = make_materials()
    builder(mats)
    setup_camera()
    setup_lights()
    outdir.mkdir(parents=True, exist_ok=True)
    setup_render(outdir / f"{name}.png", size)
    bpy.ops.render.render(write_still=True)
    print(f"RENDERED {name}", flush=True)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = ROOT / "assets" / "ui" / "tiles"
    if "--outdir" in argv:
        outdir = Path(argv[argv.index("--outdir") + 1])
        if not outdir.is_absolute():
            outdir = ROOT / outdir

    for variant in range(4):
        render(f"floor_{'abcd'[variant]}", lambda m, v=variant: build_floor(m, v), outdir)
    render("high", build_high, outdir)
    render("rim", build_rim, outdir)
    for direction in range(4):
        render(f"gate_{direction}", lambda m, d=direction: build_gate(m, d), outdir)
    render("core", build_core, outdir, size=128)
    for name, builder in PROPS.items():
        render(name, builder, outdir)


if __name__ == "__main__":
    main()
