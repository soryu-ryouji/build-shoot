"""按 ComfyUI 参考图建构成主义炮塔，导出 GLB（含炮管后坐动画）给 Godot 3D 用。

尺寸按 1 单位 = 1 世界单位（地块 48×48）。炮塔朝向 +Y，地面在 z=0。

用法：
  blender -b --factory-startup -P tools/build_turret_glb.py -- --outdir assets/models
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


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


def box(name, center, size, mat, bevel=0.6, rotation=(0.0, 0.0, 0.0)):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(center)
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40.0)
    return obj


def cone(name, center, r1, r2, depth, mat, vertices=8, rotation=(0.0, 0.0, 0.0)):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=vertices,
                          radius1=r1, radius2=r2, depth=depth)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(center)
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    return obj


def cylinder(name, center, radius, depth, mat, vertices=24, rotation=(0.0, 0.0, 0.0)):
    return cone(name, center, radius, radius, depth, mat, vertices, rotation)


def make_materials() -> dict:
    return {
        "dark": material("MAT-dark", (0.10, 0.11, 0.12), roughness=0.4, metallic=0.6),
        "steel": material("MAT-steel", (0.42, 0.44, 0.45), roughness=0.3, metallic=0.9),
        "grey": material("MAT-grey", (0.26, 0.28, 0.30), roughness=0.42, metallic=0.5),
        "cream": material("MAT-cream", (0.78, 0.77, 0.72), roughness=0.42, metallic=0.2),
        "amber": material("MAT-amber", (0.88, 0.55, 0.14), roughness=0.35,
                          emission=(0.88, 0.55, 0.14), strength=0.5),
    }


def build_turret(mats: dict):
    root = bpy.data.objects.new("TurretRoot", None)
    bpy.context.scene.collection.objects.link(root)

    parts = []
    # 宽裙边：八边形台座 + 八块米白裙板 + 三条琥珀条
    parts.append(cone("GEO-skirt", (0.0, 0.0, 6.0), 30.0, 24.0, 12.0, mats["dark"], vertices=8))
    parts.append(cone("GEO-skirt-top", (0.0, 0.0, 14.0), 24.0, 20.0, 4.0, mats["grey"], vertices=8))
    for i in range(8):
        angle = math.tau * i / 8.0
        x = math.cos(angle) * 23.0
        y = math.sin(angle) * 23.0
        plate = box("GEO-skirt-plate", (x, y, 9.0), (13.0, 3.0, 14.0), mats["cream"], bevel=0.8)
        plate.rotation_euler = (math.radians(-12.0), 0.0, angle + math.pi / 2.0)
        parts.append(plate)
        if i % 3 == 0:
            stripe = box("GEO-skirt-stripe", (x * 1.02, y * 1.02, 4.6), (7.0, 1.2, 3.0), mats["amber"], bevel=0.2)
            stripe.rotation_euler = (0.0, 0.0, angle + math.pi / 2.0)
            parts.append(stripe)

    # 腰部转盘
    parts.append(cylinder("GEO-waist", (0.0, 0.0, 18.0), 12.0, 8.0, mats["dark"], vertices=24))
    parts.append(cylinder("GEO-waist-ring", (0.0, 0.0, 22.0), 13.5, 2.0, mats["amber"], vertices=24))

    # 炮塔头：斜切的主装甲 + 两侧肩甲
    head = bpy.data.objects.new("Head", None)
    bpy.context.scene.collection.objects.link(head)
    head.parent = root

    head_parts = []
    head_parts.append(box("GEO-head", (0.0, 0.0, 32.0), (24.0, 22.0, 16.0), mats["grey"], bevel=2.0))
    for side in (-1.0, 1.0):
        shoulder = box("GEO-shoulder", (side * 13.0, -2.0, 32.0), (8.0, 18.0, 14.0), mats["dark"],
                       bevel=1.6, rotation=(0.0, math.radians(18.0 * side), 0.0))
        head_parts.append(shoulder)
    head_parts.append(box("GEO-head-cream", (0.0, -6.0, 38.0), (20.0, 12.0, 6.0), mats["cream"], bevel=0.8))
    head_parts.append(box("GEO-head-stripe", (0.0, -11.0, 30.0), (16.0, 2.0, 3.0), mats["amber"], bevel=0.2))

    # 炮管：绕 +Y 指向，带后坐动画
    barrel = bpy.data.objects.new("Barrel", None)
    bpy.context.scene.collection.objects.link(barrel)
    barrel.parent = head
    barrel_parts = [
        cylinder("GEO-barrel", (0.0, 14.0, 32.0), 3.4, 38.0, mats["steel"], vertices=20,
                 rotation=(math.pi / 2.0, 0.0, 0.0)),
        cylinder("GEO-muzzle", (0.0, 33.0, 32.0), 4.6, 6.0, mats["dark"], vertices=20,
                 rotation=(math.pi / 2.0, 0.0, 0.0)),
        box("GEO-brace", (0.0, 6.0, 32.0), (8.0, 6.0, 6.0), mats["grey"], bevel=0.8),
    ]
    for part in barrel_parts:
        part.parent = barrel

    for part in parts:
        part.parent = root
    for part in head_parts:
        part.parent = head

    return root, head, barrel


def animate(barrel) -> None:
    """炮管后坐：0.12 秒退 5 个单位，0.25 秒回位，循环。"""
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 40
    base_y = 0.0
    barrel.location.y = base_y
    barrel.keyframe_insert("location", frame=1)
    barrel.location.y = base_y - 5.0
    barrel.keyframe_insert("location", frame=4)
    barrel.location.y = base_y
    barrel.keyframe_insert("location", frame=16)
    barrel.keyframe_insert("location", frame=40)


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_yup=True,
    )


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = ROOT / "assets" / "models"
    if "--outdir" in argv:
        outdir = Path(argv[argv.index("--outdir") + 1])
        if not outdir.is_absolute():
            outdir = ROOT / outdir

    reset_scene()
    mats = make_materials()
    root, head, barrel = build_turret(mats)
    animate(barrel)
    export_glb(outdir / "turret_construct.glb")
    print("EXPORTED", outdir / "turret_construct.glb", flush=True)


if __name__ == "__main__":
    main()
