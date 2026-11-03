"""用 Blender 生成 2.5D 敌人贴片：和地图/建筑同一台正交相机，1 单位 = 1 像素，
地面中心落在 64×64 画布中心，游戏里按敌人位置直接贴。

用法：
  blender -b --factory-startup -P tools/build_enemies_3d.py -- --outdir assets/ui/enemies
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
CANVAS = 64
## 敌人比地块小，用更小的正交视野把它放大到画面里
ORTHO = 42.0
ELEV_SIN = 34.0 / 48.0
CAM_X_ROT = math.pi / 2.0 - math.asin(ELEV_SIN)


def reset_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            block.remove(item)


def material(name, color, roughness=0.45, metallic=0.4, emission=None, strength=0.0):
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


def cylinder(name, center, radius, depth, mat, vertices=20):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=vertices,
                          radius1=radius, radius2=radius, depth=depth)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(center)
    obj.data.materials.append(mat)
    return obj


def make_materials() -> dict:
    return {
        "shell": material("MAT-shell", (0.27, 0.29, 0.31), roughness=0.38, metallic=0.55),
        "dark": material("MAT-dark", (0.08, 0.09, 0.10), roughness=0.4, metallic=0.6),
        "steel": material("MAT-steel", (0.5, 0.52, 0.53), roughness=0.28, metallic=0.9),
        "orange": material("MAT-orange", (0.92, 0.52, 0.09), roughness=0.35,
                           emission=(0.92, 0.52, 0.09), strength=0.5),
        "red": material("MAT-red", (0.8, 0.1, 0.07), roughness=0.35,
                        emission=(1.0, 0.16, 0.10), strength=1.8),
        "cyan": material("MAT-cyan", (0.35, 0.88, 0.95), roughness=0.3,
                         emission=(0.35, 0.88, 0.95), strength=1.6),
        "green": material("MAT-green", (0.3, 0.85, 0.45), roughness=0.3,
                          emission=(0.3, 0.85, 0.45), strength=1.4),
    }


def legs(mats, count, radius, length, thickness, mat, z=4.0):
    for i in range(count):
        angle = math.tau * i / count
        x = math.cos(angle) * radius
        y = math.sin(angle) * radius
        obj = box("GEO-leg", (x, y, z), (thickness, length, thickness * 0.8), mat, bevel=0.6)
        obj.rotation_euler = (0.0, 0.0, angle)


def build_normal(mats):
    box("GEO-body", (0.0, 0.0, 7.0), (15.0, 17.0, 9.0), mats["shell"], bevel=2.2)
    box("GEO-head", (0.0, -8.0, 8.0), (11.0, 8.0, 7.0), mats["dark"], bevel=1.6)
    box("GEO-eye", (0.0, -11.5, 8.5), (7.0, 1.8, 2.4), mats["red"])
    legs(mats, 6, 9.0, 12.0, 2.4, mats["dark"], z=4.5)
    box("GEO-back", (0.0, 4.0, 11.0), (9.0, 6.0, 2.0), mats["steel"], bevel=0.8)


def build_swift(mats):
    box("GEO-body", (0.0, 0.0, 6.5), (11.0, 20.0, 7.0), mats["shell"], bevel=2.0)
    box("GEO-nose", (0.0, -11.0, 6.5), (7.0, 7.0, 5.0), mats["dark"], bevel=1.4)
    box("GEO-eye", (0.0, -14.0, 7.0), (4.5, 1.6, 2.0), mats["cyan"])
    legs(mats, 4, 8.0, 16.0, 1.8, mats["dark"], z=4.0)
    box("GEO-fin", (0.0, 6.0, 10.0), (2.0, 8.0, 5.0), mats["orange"], bevel=0.5)


def build_armored(mats):
    box("GEO-hull", (0.0, 0.0, 7.0), (21.0, 21.0, 9.0), mats["dark"], bevel=2.4)
    box("GEO-plate-a", (0.0, -6.0, 12.0), (19.0, 9.0, 3.0), mats["steel"], bevel=1.0)
    box("GEO-plate-b", (0.0, 5.0, 12.0), (17.0, 8.0, 3.0), mats["shell"], bevel=1.0)
    box("GEO-eye", (0.0, -10.0, 8.5), (9.0, 1.8, 2.6), mats["orange"])
    for i in range(4):
        angle = math.tau * (i + 0.5) / 4.0
        box("GEO-knee", (math.cos(angle) * 11.0, math.sin(angle) * 11.0, 3.0),
            (5.0, 5.0, 6.0), mats["steel"], bevel=1.0)
    legs(mats, 4, 13.0, 12.0, 3.0, mats["dark"], z=4.5)


def build_elite(mats):
    cylinder("GEO-core", (0.0, 0.0, 6.0), 11.0, 8.0, mats["dark"], vertices=28)
    cylinder("GEO-core-ring", (0.0, 0.0, 10.6), 9.0, 2.0, mats["cyan"], vertices=28)
    box("GEO-torso", (0.0, 0.0, 14.0), (13.0, 13.0, 8.0), mats["shell"], bevel=2.0)
    box("GEO-head", (0.0, -4.0, 19.5), (8.0, 9.0, 5.0), mats["dark"], bevel=1.4)
    box("GEO-eye", (0.0, -8.6, 19.5), (5.0, 1.6, 2.0), mats["red"])
    for i in range(4):
        angle = math.tau * i / 4.0
        obj = box("GEO-arm", (math.cos(angle) * 10.0, math.sin(angle) * 10.0, 13.0),
                  (3.0, 9.0, 12.0), mats["dark"], bevel=0.8)
        obj.rotation_euler = (0.0, 0.0, angle)
    legs(mats, 6, 10.0, 13.0, 2.2, mats["dark"], z=4.5)
    box("GEO-crest", (0.0, 3.0, 22.5), (2.0, 6.0, 4.0), mats["orange"], bevel=0.4)


BUILDINGS = {
    "normal": build_normal,
    "swift": build_swift,
    "armored": build_armored,
    "elite": build_elite,
}


def setup_camera() -> None:
    cam_data = bpy.data.cameras.new("CAM-enemy")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO
    cam_data.clip_start = 10.0
    cam_data.clip_end = 20000.0
    cam = bpy.data.objects.new("CAM-enemy", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    distance = 3000.0
    cam.location = (0.0, -math.sin(CAM_X_ROT) * distance, math.cos(CAM_X_ROT) * distance)
    cam.rotation_euler = (CAM_X_ROT, 0.0, 0.0)
    bpy.context.scene.camera = cam


def setup_lights() -> None:
    sun_data = bpy.data.lights.new("LGT-sun", "SUN")
    sun_data.energy = 3.4
    sun_data.angle = math.radians(3.0)
    sun = bpy.data.objects.new("LGT-sun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-38.0))
    fill_data = bpy.data.lights.new("LGT-fill", "AREA")
    fill_data.energy = 8000.0
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
    scene.render.resolution_x = CANVAS
    scene.render.resolution_y = CANVAS
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filepath = str(out_path)
    world = bpy.data.worlds.new("WORLD-enemy")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.3, 0.32, 0.34, 1.0)
    background.inputs["Strength"].default_value = 0.45
    scene.world = world


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = ROOT / "assets" / "ui" / "enemies"
    if "--outdir" in argv:
        outdir = Path(argv[argv.index("--outdir") + 1])
        if not outdir.is_absolute():
            outdir = ROOT / outdir
    outdir.mkdir(parents=True, exist_ok=True)
    for name, builder in BUILDINGS.items():
        reset_scene()
        mats = make_materials()
        builder(mats)
        setup_camera()
        setup_lights()
        setup_render(outdir / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print(f"RENDERED {name}", flush=True)


if __name__ == "__main__":
    main()
