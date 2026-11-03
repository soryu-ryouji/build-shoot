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
        "gap": material("MAT-gap", (0.045, 0.05, 0.055), roughness=0.7, metallic=0.2),
        "deck": material("MAT-deck", (0.16, 0.175, 0.19), roughness=0.45, metallic=0.5),
        "plate": material("MAT-plate", (0.30, 0.32, 0.34), roughness=0.38, metallic=0.45),
        "plate_alt": material("MAT-plate-alt", (0.26, 0.28, 0.30), roughness=0.42, metallic=0.5),
        "steel": material("MAT-steel", (0.55, 0.57, 0.58), roughness=0.24, metallic=0.9),
        "dark": material("MAT-dark", (0.085, 0.095, 0.105), roughness=0.35, metallic=0.65),
        "orange": material("MAT-orange", (0.92, 0.52, 0.09), roughness=0.35, metallic=0.2,
                           emission=(0.92, 0.52, 0.09), strength=0.25),
        "yellow": material("MAT-yellow", (0.95, 0.76, 0.18), roughness=0.4, metallic=0.2),
        "green": material("MAT-green", (0.32, 0.88, 0.45), roughness=0.3,
                          emission=(0.32, 0.88, 0.45), strength=1.6),
        "cyan": material("MAT-cyan", (0.35, 0.9, 0.95), roughness=0.25,
                         emission=(0.35, 0.9, 0.95), strength=1.3),
        "red": material("MAT-red", (0.7, 0.09, 0.06), roughness=0.4,
                        emission=(1.0, 0.16, 0.10), strength=1.8),
    }


def screw(name: str, x: float, y: float, z: float, mats: dict) -> None:
    cylinder(name, (x, y, z), 1.6, 0.9, mats["steel"], vertices=12)


def hazard(name: str, y: float, z: float, width: float, mats: dict, count: int = 5) -> None:
    """沿 X 方向交替的橙色警示条，贴在侧面。"""
    step = width / (count * 2 - 1)
    for i in range(count):
        box(f"{name}-{i}", (-width * 0.5 + step * (2 * i + 0.5), y, z),
            (step * 1.15, 2.2, 3.2), mats["orange"])


def build_floor(mats: dict, variant: int):
    # 整格深色底座：相邻地块之间只留一条细缝
    box("GEO-gap", (0.0, 0.0, 1.0), (TILE_GROUND, TILE_GROUND, 2.0), mats["gap"])
    plate = mats["plate"] if variant == 0 else mats["plate_alt"]
    box("GEO-deck", (0.0, 0.0, 4.0), (PLATE, PLATE, 5.0), plate, bevel=1.6)
    # 面板线：内缩一圈的浅槽
    box("GEO-panel", (0.0, 0.0, 6.7), (PLATE - 14.0, PLATE - 14.0, 0.5), mats["gap"], bevel=0.4)
    box("GEO-panel-inner", (0.0, 0.0, 6.9), (PLATE - 17.0, PLATE - 17.0, 0.5), plate, bevel=0.4)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            screw("GEO-screw", sx * 19.0, sy * 19.0, 6.8, mats)
    if variant == 1:
        # 带绿色指示灯的通风模块
        box("GEO-vent", (7.0, -7.0, 7.1), (13.0, 9.0, 0.8), mats["dark"], bevel=0.5)
        for i in range(3):
            box("GEO-vent-slit", (3.5 + i * 3.5, -7.0, 7.6), (1.2, 6.0, 0.4), mats["gap"])
        box("GEO-light", (-13.0, 13.0, 7.2), (7.0, 2.2, 0.6), mats["green"])
    else:
        box("GEO-light", (-13.0, 13.0, 7.2), (7.0, 2.2, 0.6), mats["green"])
        box("GEO-rail", (0.0, 16.0, 7.0), (26.0, 2.0, 0.6), mats["steel"])


def build_high(mats: dict):
    # 高台：深色侧壁 + 浅色顶板，正面一条橙色警示带
    box("GEO-high", (0.0, 0.0, 7.5), (PLATE, PLATE, 15.0), mats["dark"], bevel=1.2)
    box("GEO-high-top", (0.0, 0.0, 16.4), (PLATE, PLATE, 3.0), mats["plate"], bevel=1.6)
    box("GEO-high-panel", (0.0, 0.0, 18.1), (PLATE - 14.0, PLATE - 14.0, 0.5), mats["gap"], bevel=0.4)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            screw("GEO-screw", sx * 19.0, sy * 19.0, 18.0, mats)
    hazard("GEO-hazard", -PLATE * 0.5 - 0.2, 6.0, PLATE - 8.0, mats, count=5)
    box("GEO-high-light", (0.0, 19.0, 18.2), (18.0, 2.0, 0.6), mats["green"])


def build_rim(mats: dict):
    # 边界矮墙：深色墙体 + 顶部钢板 + 正面铆钉与警示条
    box("GEO-rim", (0.0, 0.0, 13.0), (TILE_GROUND, TILE_GROUND, 26.0), mats["dark"], bevel=2.0)
    box("GEO-rim-top", (0.0, 0.0, 27.2), (PLATE, PLATE, 2.4), mats["plate"], bevel=1.6)
    box("GEO-rim-spine", (0.0, 0.0, 28.8), (PLATE - 16.0, PLATE - 16.0, 1.0), mats["steel"], bevel=0.8)
    hazard("GEO-rim-hazard", -TILE_GROUND * 0.5 - 0.2, 16.0, TILE_GROUND - 6.0, mats, count=6)
    for i in range(4):
        cylinder("GEO-rivet", (-15.0 + i * 10.0, -TILE_GROUND * 0.5 - 0.4, 23.0), 1.4, 1.0, mats["steel"], vertices=10)


def build_gate(mats: dict, direction: int):
    box("GEO-gap", (0.0, 0.0, 1.0), (TILE_GROUND, TILE_GROUND, 2.0), mats["gap"])
    box("GEO-deck", (0.0, 0.0, 4.0), (PLATE, PLATE, 5.0), mats["plate"], bevel=1.6)
    box("GEO-socket", (0.0, 0.0, 7.0), (40.0, 40.0, 1.4), mats["gap"], bevel=1.5)
    box("GEO-glow", (0.0, 0.0, 7.8), (32.0, 32.0, 1.2), mats["red"], bevel=1.0)
    frame = 43.0
    for dx, dy, sx, sy in ((0.0, -frame * 0.5, frame, 4.5), (0.0, frame * 0.5, frame, 4.5),
                           (-frame * 0.5, 0.0, 4.5, frame), (frame * 0.5, 0.0, 4.5, frame)):
        box("GEO-gate-frame", (dx, dy, 8.8), (sx, sy, 4.0), mats["steel"], bevel=1.0)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            box("GEO-gate-mark", (sx * 17.0, sy * 17.0, 8.2), (6.0, 6.0, 0.8), mats["orange"])
    angle = -math.tau * direction / 4.0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.rotation_euler.z += angle


def build_core(mats: dict):
    cylinder("GEO-core-gap", (0.0, 0.0, 1.0), 38.0, 2.0, mats["gap"], vertices=56)
    cylinder("GEO-core-base", (0.0, 0.0, 5.0), 34.0, 6.0, mats["dark"], vertices=56)
    cylinder("GEO-core-ring", (0.0, 0.0, 8.4), 26.0, 1.6, mats["steel"], vertices=56)
    cylinder("GEO-core-amber", (0.0, 0.0, 9.4), 20.0, 1.0, mats["orange"], vertices=48)
    cylinder("GEO-core-inner", (0.0, 0.0, 9.8), 14.0, 2.2, mats["cyan"], vertices=48)
    for i in range(6):
        angle = math.tau * i / 6.0
        box("GEO-core-clamp", (math.cos(angle) * 31.0, math.sin(angle) * 31.0, 6.0),
            (11.0, 8.0, 5.0), mats["steel"], bevel=1.2).rotation_euler = (0.0, 0.0, angle)

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
