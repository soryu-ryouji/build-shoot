"""用 Blender 生成 2.5D 建筑贴图：和地图同一台正交相机（俯角 asin(34/48)），
1 世界单位 = 1 像素，地面接触点落在图片中心，游戏里按瓦片中心直接贴。

三座火力塔额外渲染 8 个朝向（北起顺时针 45° 一格），其余建筑各 1 张。

用法：
  blender -b --factory-startup -P tools/build_buildings_3d.py -- --outdir assets/ui/25d
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SPRITE = 160
ORTHO = 160.0
ELEV_SIN = 34.0 / 48.0
CAM_X_ROT = math.pi / 2.0 - math.asin(ELEV_SIN)


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


def cylinder(name, center, radius, depth, mat, vertices=32, rotation=(0.0, 0.0, 0.0)):
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
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    return obj


# ---------------------------------------------------------------- 建筑

def build_turret(mats, heavy=False, laser=False):
    radius = 27.0 if heavy else 22.0
    cylinder("GEO-base", (0.0, 0.0, 4.0), radius, 8.0, mats["base"], vertices=40)
    cylinder("GEO-base-ring", (0.0, 0.0, 8.6), radius * 0.82, 1.6, mats["trim"], vertices=40)
    if laser:
        box("GEO-housing", (0.0, 0.0, 18.0), (22.0, 24.0, 20.0), mats["shell"], bevel=3.0)
        cylinder("GEO-emitter", (0.0, 8.0, 32.0), 6.0, 34.0, mats["glow"], vertices=24)
        cylinder("GEO-lens", (0.0, 24.0, 44.0), 7.0, 3.0, mats["lens"], vertices=24)
        box("GEO-band", (0.0, 0.0, 24.0), (23.0, 25.0, 2.0), mats["accent"], bevel=0.5)
    elif heavy:
        box("GEO-housing", (0.0, 0.0, 21.0), (32.0, 28.0, 22.0), mats["shell"], bevel=3.5)
        for offset in (-7.0, 7.0):
            cylinder("GEO-barrel", (offset, 20.0, 24.0), 5.0, 44.0, mats["metal"], vertices=18,
                     rotation=(math.pi / 2.0, 0.0, 0.0))
        box("GEO-muzzle", (0.0, 40.0, 24.0), (22.0, 5.0, 10.0), mats["trim"], bevel=1.0)
        box("GEO-band", (0.0, 0.0, 16.0), (33.0, 29.0, 2.0), mats["accent"], bevel=0.5)
    else:
        box("GEO-housing", (0.0, 0.0, 18.0), (25.0, 23.0, 18.0), mats["shell"], bevel=3.0)
        cylinder("GEO-barrel", (0.0, 16.0, 21.0), 4.6, 42.0, mats["metal"], vertices=18,
                 rotation=(math.pi / 2.0, 0.0, 0.0))
        box("GEO-muzzle", (0.0, 36.0, 21.0), (12.0, 5.0, 7.0), mats["trim"], bevel=1.0)
        box("GEO-band", (0.0, 0.0, 12.0), (26.0, 24.0, 2.0), mats["accent"], bevel=0.5)
    box("GEO-antenna", (radius * 0.62, -radius * 0.45, 17.0), (2.2, 2.2, 14.0), mats["metal"])


def build_sandbag(mats):
    for row in range(2):
        for col in range(5):
            x = -18.0 + col * 9.0
            y = -5.0 + row * 9.0
            z = 5.0 + row * 4.0
            box("GEO-sack", (x, y, z), (10.0, 11.0, 9.0), mats["sack"], bevel=3.0)
    cylinder("GEO-post", (-22.0, 0.0, 9.0), 2.0, 18.0, mats["metal"], vertices=12)
    cylinder("GEO-post", (22.0, 0.0, 9.0), 2.0, 18.0, mats["metal"], vertices=12)


def build_solar(mats):
    for sx in (-15.0, 15.0):
        for sy in (-11.0, 11.0):
            box("GEO-leg", (sx, sy, 5.0), (3.0, 3.0, 10.0), mats["metal"], bevel=0.6)
    panel = box("GEO-panel", (0.0, 0.0, 14.0), (40.0, 30.0, 2.2), mats["panel"], bevel=1.2)
    panel.rotation_euler = (math.radians(-18.0), 0.0, 0.0)
    box("GEO-frame", (0.0, 0.0, 12.6), (42.0, 32.0, 1.6), mats["trim"], bevel=1.0).rotation_euler = (
        math.radians(-18.0), 0.0, 0.0)


def build_compression(mats):
    cylinder("GEO-base", (0.0, 0.0, 4.0), 20.0, 8.0, mats["base"], vertices=36)
    cylinder("GEO-column", (0.0, 0.0, 20.0), 6.0, 26.0, mats["metal"], vertices=20)
    box("GEO-head", (0.0, 0.0, 34.0), (16.0, 16.0, 14.0), mats["shell"], bevel=3.0)
    cylinder("GEO-core", (0.0, 0.0, 34.0), 7.0, 16.0, mats["glow"], vertices=24)
    for i in range(3):
        angle = math.tau * i / 3.0
        box(
            "GEO-fin",
            (math.cos(angle) * 12.0, math.sin(angle) * 12.0, 30.0),
            (4.0, 4.0, 12.0),
            mats["trim"],
        ).rotation_euler = (0.0, 0.0, angle)


def build_fusion(mats):
    cylinder("GEO-base", (0.0, 0.0, 4.0), 21.0, 8.0, mats["base"], vertices=36)
    cylinder("GEO-body", (0.0, 0.0, 18.0), 13.0, 22.0, mats["shell"], vertices=28)
    cylinder("GEO-ring", (0.0, 0.0, 24.0), 15.0, 3.0, mats["glow"], vertices=28)
    cylinder("GEO-cap", (0.0, 0.0, 32.0), 9.0, 6.0, mats["trim"], vertices=24)
    for i in range(4):
        angle = math.tau * i / 4.0
        box(
            "GEO-vane",
            (math.cos(angle) * 16.0, math.sin(angle) * 16.0, 16.0),
            (3.0, 9.0, 16.0),
            mats["metal"],
        ).rotation_euler = (0.0, 0.0, angle)


BUILDINGS = {
    "turret": lambda m: build_turret(m),
    "heavy_turret": lambda m: build_turret(m, heavy=True),
    "laser_tower": lambda m: build_turret(m, laser=True),
    "sandbag": build_sandbag,
    "solar": build_solar,
    "compression_tower": build_compression,
    "fusion_tower": build_fusion,
}

DIRECTIONAL = {"turret", "heavy_turret", "laser_tower"}


def make_materials() -> dict:
    return {
        "base": material("MAT-base", (0.18, 0.20, 0.22), roughness=0.45, metallic=0.55),
        "shell": material("MAT-shell", (0.30, 0.32, 0.34), roughness=0.38, metallic=0.5),
        "trim": material("MAT-trim", (0.55, 0.57, 0.58), roughness=0.24, metallic=0.9),
        "metal": material("MAT-metal", (0.10, 0.11, 0.12), roughness=0.35, metallic=0.7),
        "accent": material("MAT-accent", (0.92, 0.52, 0.09), roughness=0.35, emission=(0.92, 0.52, 0.09), strength=0.35),
        "glow": material("MAT-glow", (0.32, 0.88, 0.45), roughness=0.3, emission=(0.32, 0.88, 0.45), strength=1.4),
        "lens": material("MAT-lens", (0.35, 0.9, 0.95), roughness=0.15, emission=(0.35, 0.9, 0.95), strength=1.8),
        "sack": material("MAT-sack", (0.55, 0.46, 0.32), roughness=0.8),
        "panel": material("MAT-panel", (0.06, 0.12, 0.20), roughness=0.25, metallic=0.45),
    }


def setup_camera() -> None:
    cam_data = bpy.data.cameras.new("CAM-prop")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO
    cam_data.clip_start = 10.0
    cam_data.clip_end = 20000.0
    cam = bpy.data.objects.new("CAM-prop", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    distance = 3000.0
    cam.location = (0.0, -math.sin(CAM_X_ROT) * distance, math.cos(CAM_X_ROT) * distance)
    cam.rotation_euler = (CAM_X_ROT, 0.0, 0.0)
    bpy.context.scene.camera = cam


def setup_lights() -> None:
    sun_data = bpy.data.lights.new("LGT-sun", "SUN")
    sun_data.energy = 3.3
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


def setup_render(out_path: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x = SPRITE
    scene.render.resolution_y = SPRITE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filepath = str(out_path)
    world = bpy.data.worlds.new("WORLD-prop")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.35, 0.37, 0.4, 1.0)
    background.inputs["Strength"].default_value = 0.45
    scene.world = world


def render_building(name: str, outdir: Path) -> None:
    mats = make_materials()
    outdir.mkdir(parents=True, exist_ok=True)
    directions = 8 if name in DIRECTIONAL else 1
    for index in range(directions):
        reset_scene()
        mats = make_materials()
        BUILDINGS[name](mats)
        for obj in bpy.data.objects:
            if obj.type == "MESH":
                obj.rotation_euler.z += -math.tau * index / 8.0
        setup_camera()
        setup_lights()
        suffix = f"_d{index}" if directions > 1 else ""
        setup_render(outdir / f"{name}{suffix}.png")
        bpy.ops.render.render(write_still=True)
        print(f"RENDERED {name}{suffix}", flush=True)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = ROOT / "assets" / "ui" / "25d"
    only = None
    if "--outdir" in argv:
        outdir = Path(argv[argv.index("--outdir") + 1])
        if not outdir.is_absolute():
            outdir = ROOT / outdir
    if "--only" in argv:
        only = argv[argv.index("--only") + 1]
    for name in BUILDINGS:
        if only and name != only:
            continue
        render_building(name, outdir)


if __name__ == "__main__":
    main()
