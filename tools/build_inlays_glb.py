"""构成主义地砖浮雕：深色嵌板 + 红/米白/琥珀色块，作为地块上的装饰贴片导出 GLB。

每个贴片 46×46、厚度 ≤2，原点在格子中心、底面在 z=0。

用法：
  blender -b --factory-startup -P tools/build_inlays_glb.py -- --outdir assets/models/inlays
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
TEXTURE = ROOT / "assets" / "ui" / "tiles" / "panel_texture_bright.png"


def reset_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights, bpy.data.images):
        for item in list(block):
            block.remove(item)


def box(name, center, size, mat, bevel=0.3, rotation=(0.0, 0.0, 0.0)):
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


def prism(name, points, height, mat, base_z=0.0):
    """points: 俯视平面的多边形顶点 [(x, y), ...]，沿 Z 挤出 height。"""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, base_z)) for x, y in points]
    bm.faces.new(verts)
    bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    extruded = [v for v in bm.verts if abs(v.co.z - base_z) < 1e-6 and len(v.link_faces) > 0]
    for v in bm.verts:
        if v not in verts:
            v.co.z = base_z + height
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def textured_material(name, tint, rough=0.5, metal=0.5, use_texture=True):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if use_texture and TEXTURE.exists():
        image = bpy.data.images.load(str(TEXTURE), check_existing=True)
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = 1.0
        mix.inputs["Color2"].default_value = (*tint, 1.0)
        mat.node_tree.links.new(tex.outputs["Color"], mix.inputs["Color1"])
        mat.node_tree.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
    return mat


def materials() -> dict:
    return {
        "dark": textured_material("MAT-dark", (0.42, 0.44, 0.46)),
        "cream": textured_material("MAT-cream", (0.78, 0.76, 0.70), use_texture=False),
        "amber": textured_material("MAT-amber", (0.80, 0.50, 0.14), use_texture=False),
        "red": textured_material("MAT-red", (0.55, 0.17, 0.14), use_texture=False),
    }


def base_plate(mats):
    box("GEO-inlay-base", (0.0, 0.0, 0.4), (40.0, 40.0, 0.8), mats["dark"], bevel=0.4)


def inlay_diag(mats):
    base_plate(mats)
    box("GEO-diag", (0.0, 0.0, 1.2), (40.0, 8.0, 1.2), mats["cream"], bevel=0.4,
        rotation=(0.0, 0.0, math.radians(36.0)))


def inlay_step(mats):
    base_plate(mats)
    for i in range(3):
        box("GEO-step", (-10.0 + i * 9.0, -8.0 + i * 5.0, 1.1 + i * 0.1),
            (12.0, 14.0 - i * 4.0, 1.2), mats["amber"], bevel=0.3)


def inlay_l(mats):
    base_plate(mats)
    box("GEO-l-a", (-4.0, 10.0, 1.2), (32.0, 9.0, 1.2), mats["cream"], bevel=0.3)
    box("GEO-l-b", (-15.0, -3.0, 1.2), (9.0, 20.0, 1.2), mats["cream"], bevel=0.3)
    box("GEO-l-edge", (-19.0, -3.0, 1.2), (2.0, 20.0, 1.3), mats["red"], bevel=0.2)


def inlay_split(mats):
    base_plate(mats)
    prism("GEO-split-a", [(-18.0, -18.0), (18.0, -18.0), (18.0, 18.0)], 1.4, mats["red"], base_z=0.8)
    prism("GEO-split-b", [(-18.0, -18.0), (18.0, 18.0), (-18.0, 18.0)], 1.4, mats["cream"], base_z=0.8)


def inlay_corner(mats):
    base_plate(mats)
    prism("GEO-corner", [(14.0, 14.0), (14.0, -14.0), (-14.0, 14.0)], 1.4, mats["amber"], base_z=0.8)
    box("GEO-corner-mark", (-10.0, -10.0, 1.3), (8.0, 8.0, 1.2), mats["cream"], bevel=0.3)


INLAYS = {
    "inlay_diag": inlay_diag,
    "inlay_step": inlay_step,
    "inlay_l": inlay_l,
    "inlay_split": inlay_split,
    "inlay_corner": inlay_corner,
}


def add_uvs() -> None:
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if not obj.data.uv_layers:
            obj.data.uv_layers.new(name="UVMap")
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_animations=False,
        export_yup=True,
    )


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = ROOT / "assets" / "models" / "inlays"
    if "--outdir" in argv:
        outdir = Path(argv[argv.index("--outdir") + 1])
        if not outdir.is_absolute():
            outdir = ROOT / outdir

    for name, builder in INLAYS.items():
        reset_scene()
        mats = materials()
        builder(mats)
        add_uvs()
        export_glb(outdir / f"{name}.glb")
        print(f"EXPORTED {name}", flush=True)


if __name__ == "__main__":
    main()
