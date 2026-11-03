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


def make_materials() -> dict:
    return {
        "plate": material("MAT-plate", (0.74, 0.74, 0.72), roughness=0.55, metallic=0.1),
        "plate_alt": material("MAT-plate-alt", (0.70, 0.70, 0.68), roughness=0.6, metallic=0.1),
        "seam": material("MAT-seam", (0.52, 0.54, 0.55), roughness=0.6, metallic=0.2),
        "road": material("MAT-road", (0.17, 0.19, 0.21), roughness=0.5, metallic=0.25),
        "road_inner": material("MAT-road-inner", (0.30, 0.33, 0.35), roughness=0.45, metallic=0.2),
        "high": material("MAT-high", (0.46, 0.47, 0.47), roughness=0.6, metallic=0.15),
        "high_top": material("MAT-high-top", (0.72, 0.72, 0.70), roughness=0.55, metallic=0.1),
        "rim": material("MAT-rim", (0.40, 0.42, 0.44), roughness=0.5, metallic=0.2),
        "rim_top": material("MAT-rim-top", (0.30, 0.32, 0.34), roughness=0.45, metallic=0.3),
        "metal": material("MAT-metal", (0.55, 0.57, 0.59), roughness=0.35, metallic=0.7),
        "accent": material("MAT-accent", (0.95, 0.64, 0.23), roughness=0.4, emission=(0.95, 0.64, 0.23), strength=0.2),
        "socket": material("MAT-socket", (0.06, 0.07, 0.08), roughness=0.8),
        "gate_glow": material("MAT-gate-glow", (0.5, 0.06, 0.05), roughness=0.5, emission=(1.0, 0.20, 0.14), strength=2.2),
        "core_base": material("MAT-core-base", (0.74, 0.75, 0.72), roughness=0.45, metallic=0.15),
        "core_ring": material("MAT-core-ring", (0.3, 0.6, 0.62), roughness=0.35, emission=(0.41, 0.74, 0.76), strength=0.6),
        "core_core": material("MAT-core-core", (0.7, 0.95, 0.98), roughness=0.2, emission=(0.5, 0.95, 1.0), strength=0.7),
    }


# ---------------------------------------------------------------- 地块

def build_floor(mats, variant: int):
    mat = mats["plate"] if variant == 0 else mats["plate_alt"]
    box("GEO-deck", (0.0, 0.0, DECK_Z * 0.5), (PLATE, PLATE, DECK_Z), mat, bevel=1.4)
    # 统一的内缩细节：一块凹槽 + 两条细缝，保证所有地板看起来是同一套模块
    box("GEO-inset", (0.0, 0.0, DECK_Z + 0.05), (PLATE - 12.0, PLATE - 12.0, 0.4), mats["seam"], bevel=0.6)
    box("GEO-inset-top", (0.0, 0.0, DECK_Z + 0.25), (PLATE - 16.0, PLATE - 16.0, 0.4), mat, bevel=0.5)
    if variant == 1:
        box("GEO-vent", (6.0, -6.0, DECK_Z + 0.35), (12.0, 9.0, 0.6), mats["metal"], bevel=0.4)
        for i in range(3):
            box("GEO-vent-slit", (3.0 + i * 3.0, -6.0, DECK_Z + 0.55), (1.0, 6.0, 0.3), mats["seam"])


def build_road(mats, mask: int):
    """mask 的位：1=北(+Y)、2=东(+X)、4=南(-Y)、8=西(-X)，按连接方向铺地块内的路面。"""
    # 路面贴片只画路面本身，地板由游戏统一铺在下面，这样相邻地块的路面不会互相盖住
    top = DECK_Z + 1.2
    # 中心方块 + 各方向延伸，拼出连续的十字形路面
    box("GEO-road-center", (0.0, 0.0, top), (ROAD_W, ROAD_W, 2.4), mats["road"], bevel=0.2)
    directions = {
        1: (0.0, 1.0),
        2: (1.0, 0.0),
        4: (0.0, -1.0),
        8: (-1.0, 0.0),
    }
    for bit, (dx, dy) in directions.items():
        if mask & bit:
            length = TILE_GROUND * 0.5 + 2.0
            size = (length, ROAD_W, 2.4) if dx else (ROAD_W, length, 2.4)
            center = (dx * length * 0.5, dy * length * 0.5, top)
            box("GEO-road-arm", center, size, mats["road"], bevel=0.2)


def build_high(mats):
    box("GEO-high", (0.0, 0.0, HIGH_Z * 0.5), (PLATE, PLATE, HIGH_Z), mats["high"], bevel=1.6)
    box("GEO-high-top", (0.0, 0.0, HIGH_Z + 0.3), (PLATE - 6.0, PLATE - 6.0, 0.8), mats["high_top"], bevel=1.0)
    # 顶面一圈细边，让高台和低地的分界更清楚
    for dx, dy, sx, sy in ((0, -PLATE * 0.36, PLATE - 10, 2.5), (0, PLATE * 0.36, PLATE - 10, 2.5),
                           (-PLATE * 0.36, 0, 2.5, PLATE - 10), (PLATE * 0.36, 0, 2.5, PLATE - 10)):
        box("GEO-high-trim", (dx, dy, HIGH_Z + 0.9), (sx, sy, 0.6), mats["accent"])


def build_rim(mats):
    box("GEO-rim", (0.0, 0.0, 12.0), (PLATE, PLATE, 24.0), mats["rim"], bevel=3.0)
    box("GEO-rim-top", (0.0, 0.0, 24.4), (PLATE - 10.0, PLATE - 10.0, 1.2), mats["rim_top"], bevel=1.0)
    box("GEO-rim-light", (0.0, -PLATE * 0.4, 16.0), (PLATE - 14.0, 3.0, 1.0), mats["accent"])


def build_gate(mats, direction: int):
    """direction: 0 北、1 东、2 南、3 西 —— 门朝向通路离开缺口的方向。"""
    box("GEO-deck", (0.0, 0.0, DECK_Z * 0.5), (PLATE, PLATE, DECK_Z), mats["plate"], bevel=1.4)
    box("GEO-gate-socket", (0.0, 0.0, DECK_Z + 0.8), (40.0, 40.0, 1.6), mats["socket"], bevel=2.0)
    box("GEO-gate-glow", (0.0, 0.0, DECK_Z + 1.8), (32.0, 32.0, 1.2), mats["gate_glow"], bevel=1.0)
    frame = 44.0
    for dx, dy, sx, sy in ((0.0, -frame * 0.5, frame, 5.0), (0.0, frame * 0.5, frame, 5.0),
                           (-frame * 0.5, 0.0, 5.0, frame), (frame * 0.5, 0.0, 5.0, frame)):
        box("GEO-gate-frame", (dx, dy, DECK_Z + 2.6), (sx, sy, 4.0), mats["metal"], bevel=1.0)
    angle = -math.tau * direction / 4.0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.rotation_euler.z += angle


def build_core(mats):
    cylinder("GEO-core-base", (0.0, 0.0, 5.0), 34.0, 4.0, mats["core_base"], vertices=56)
    cylinder("GEO-core-ring", (0.0, 0.0, 7.2), 24.0, 2.0, mats["core_ring"], vertices=56)
    cylinder("GEO-core-inner", (0.0, 0.0, 8.2), 14.0, 2.0, mats["core_core"], vertices=48)
    for i in range(6):
        angle = math.tau * i / 6.0
        box("GEO-core-clamp", (math.cos(angle) * 31.0, math.sin(angle) * 31.0, 6.0),
            (11.0, 8.0, 5.0), mats["metal"], bevel=1.5).rotation_euler = (0.0, 0.0, angle)


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
    sun_data.energy = 3.0
    sun_data.angle = math.radians(3.0)
    sun = bpy.data.objects.new("LGT-sun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-38.0))
    fill_data = bpy.data.lights.new("LGT-fill", "AREA")
    fill_data.energy = 9000.0
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

    render("floor_a", lambda m: build_floor(m, 0), outdir)
    render("floor_b", lambda m: build_floor(m, 1), outdir)

    render("high", build_high, outdir)
    render("rim", build_rim, outdir)
    for direction in range(4):
        render(f"gate_{direction}", lambda m, d=direction: build_gate(m, d), outdir)
    render("core", build_core, outdir, size=128)


if __name__ == "__main__":
    main()
