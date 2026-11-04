"""构成主义风格场景装饰物：铆接货箱、斜置碑块、管束。用 ComfyUI 出的钢板贴图做基色。

用法：
  blender -b --factory-startup -P tools/build_props_glb.py -- --outdir assets/models
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


def box(name, center, size, mat, bevel=0.5, rotation=(0.0, 0.0, 0.0)):
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


def cylinder(name, center, radius, depth, mat, vertices=16, rotation=(0.0, 0.0, 0.0)):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=vertices,
                          radius1=radius, radius2=radius, depth=depth)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(center)
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    return obj


def textured_material(name, tint, rough=0.5, metal=0.55, use_texture=True):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if use_texture and TEXTURE.exists():
        image = bpy.data.images.load(str(TEXTURE), check_existing=True)
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.location = (-400, 200)
        mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = 1.0
        mix.inputs["Color2"].default_value = (*tint, 1.0)
        mix.location = (-180, 200)
        mat.node_tree.links.new(tex.outputs["Color"], mix.inputs["Color1"])
        mat.node_tree.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
    return mat


def materials() -> dict:
    return {
        "plate": textured_material("MAT-plate", (0.62, 0.62, 0.60)),
        "dark": textured_material("MAT-dark", (0.42, 0.44, 0.46)),
        "cream": textured_material("MAT-cream", (0.92, 0.90, 0.82), use_texture=False),
        "amber": textured_material("MAT-amber", (0.88, 0.55, 0.14), rough=0.4, metal=0.2, use_texture=False),
        "steel": textured_material("MAT-steel", (0.55, 0.57, 0.58), rough=0.3, metal=0.9),
    }


def build_crate(mats):
    box("GEO-crate", (0.0, 0.0, 13.0), (30.0, 26.0, 26.0), mats["plate"], bevel=1.6)
    box("GEO-crate-band", (0.0, 0.0, 13.0), (31.0, 6.0, 27.0), mats["cream"], bevel=0.6)
    box("GEO-crate-top", (0.0, 0.0, 26.6), (24.0, 20.0, 1.6), mats["dark"], bevel=0.6)
    box("GEO-crate-mark", (0.0, -13.4, 13.0), (10.0, 1.0, 10.0), mats["amber"], bevel=0.2)


def build_monolith(mats):
    box("GEO-base", (0.0, 0.0, 3.0), (30.0, 24.0, 6.0), mats["dark"], bevel=1.0)
    slab = box("GEO-slab", (0.0, 0.0, 17.0), (34.0, 7.0, 24.0), mats["plate"], bevel=1.2)
    slab.rotation_euler = (0.0, math.radians(18.0), 0.0)
    box("GEO-slab-stripe", (0.0, -3.8, 20.0), (26.0, 1.2, 4.0), mats["amber"], bevel=0.2,
        rotation=(0.0, math.radians(18.0), 0.0))


def build_pipes(mats):
    box("GEO-pipe-base", (0.0, 0.0, 3.0), (34.0, 22.0, 6.0), mats["dark"], bevel=1.0)
    for i in range(3):
        cylinder("GEO-pipe", (0.0, -7.0 + i * 7.0, 11.0), 3.4, 32.0, mats["steel"], vertices=14,
                 rotation=(0.0, math.pi / 2.0, 0.0))
    for sx in (-12.0, 12.0):
        box("GEO-clamp", (sx, 0.0, 11.0), (3.0, 22.0, 12.0), mats["plate"], bevel=0.6)


PROPS = {
    "prop_crate": build_crate,
    "prop_monolith": build_monolith,
    "prop_pipes": build_pipes,
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
    outdir = ROOT / "assets" / "models"
    if "--outdir" in argv:
        outdir = Path(argv[argv.index("--outdir") + 1])
        if not outdir.is_absolute():
            outdir = ROOT / outdir

    for name, builder in PROPS.items():
        reset_scene()
        mats = materials()
        builder(mats)
        add_uvs()
        export_glb(outdir / f"{name}.glb")
        print(f"EXPORTED {name}", flush=True)


if __name__ == "__main__":
    main()
