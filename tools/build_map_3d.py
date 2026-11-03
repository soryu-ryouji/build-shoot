"""用 Blender 生成 2.5D 地图贴图：按 assets/maps/maps.json 的瓦片/路线/缺口/核心建地形并渲染。

坐标约定（和游戏一一对应）：
  * 一格地面 = 48×48 世界单位，瓦片在屏幕上的投影高度 = 34px；
  * 相机为正交、俯角 asin(34/48)≈45.1°、方位角 0（从南侧俯视），1 世界单位 = 1 像素；
  * 渲染尺寸 624×524（frame），地图瓦片区 576×476 居中。

用法（Blender 无头）：
  blender -b --factory-startup -P tools/build_map_3d.py -- --outdir assets/ui/25d [--map junction]
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "maps" / "maps.json"

TILE_GROUND = 48.0
TILE_SCREEN_Y = 34.0
ELEV_SIN = TILE_SCREEN_Y / TILE_GROUND
CAM_X_ROT = math.pi / 2.0 - math.asin(ELEV_SIN)
## 由 maps.json 的格子数推出的画布尺寸：瓦片区左右各留 24 像素外框
FRAME_W = 432
FRAME_H = 490


# ---------------------------------------------------------------- 场景工具

def reset_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            block.remove(item)


def material(name, color, roughness=0.55, metallic=0.0, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def box(name, center, size, mat, bevel=0.0, segments=2, collection=None):
    """建一个以自身中心为原点的方块，位置写到 object.location，方便之后单独旋转。"""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    (collection or bpy.context.scene.collection).objects.link(obj)
    obj.location = Vector(center)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40.0)
    return obj


def cylinder(name, center, radius, depth, mat, vertices=48, collection=None):
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
    (collection or bpy.context.scene.collection).objects.link(obj)
    obj.location = Vector(center)
    obj.data.materials.append(mat)
    return obj


def tile_center_ground(col: float, row: float) -> Vector:
    """瓦片中心的 Blender 地面坐标（地图居中于原点，行号 0 在最北侧，屏幕上方）。"""
    cols = DATA_JSON["cols"]
    rows = DATA_JSON["rows"]
    return Vector(
        (
            (col + 0.5 - cols * 0.5) * TILE_GROUND,
            (rows * 0.5 - row - 0.5) * TILE_GROUND,
        )
    )


# ---------------------------------------------------------------- 地形

def build_map(map_data: dict, mats: dict) -> None:
    cols = DATA_JSON["cols"]
    rows = DATA_JSON["rows"]
    field_w = cols * TILE_GROUND
    field_d = rows * TILE_GROUND
    margin = 24.0
    wall_depth = margin / ELEV_SIN

    # 地基：比瓦片区大一圈，边缘就是地图外框
    box(
        "GEO-slab",
        (0.0, 0.0, -8.0),
        (field_w + margin * 2.0, field_d + wall_depth * 2.0, 16.0),
        mats["base"],
        bevel=2.0,
    )

    core_tiles = {tuple(t) for t in map_data["core"]}
    gate_tiles = {tuple(t) for t in map_data["gates"]}

    # 高台：整块抬起来，四周露出侧壁，形成明日方舟式的高低错落
    high_tiles = set()
    high_rects = []
    for rect in map_data.get("high", []):
        c0, r0, c1, r1 = [int(v) for v in rect]
        high_rects.append((c0, r0, c1, r1))
        for c in range(c0, c1 + 1):
            for r in range(r0, r1 + 1):
                high_tiles.add((c, r))

    tile_top = 4.0
    plate = 46.0
    for c in range(cols):
        for r in range(rows):
            center = tile_center_ground(c, r)
            tile = (c, r)
            if tile in high_tiles:
                continue
            if tile in core_tiles:
                mat = mats["corepad"]
                height = tile_top + 1.5
            elif tile in gate_tiles:
                mat = mats["gatepad"]
                height = tile_top + 1.0
            else:
                mat = mats["plate_a"] if (c + r) % 2 == 0 else mats["plate_b"]
                height = tile_top
            box(
                f"GEO-tile-{c}-{r}",
                (center.x, center.y, height * 0.5),
                (plate, plate, height),
                mat,
                bevel=1.6,
            )

    high_top = tile_top + DATA_JSON.get("high_lift", 12.0)
    for index, (c0, r0, c1, r1) in enumerate(high_rects):
        x0 = (c0 - cols * 0.5) * TILE_GROUND
        x1 = (c1 + 1 - cols * 0.5) * TILE_GROUND
        y0 = (rows * 0.5 - (r1 + 1)) * TILE_GROUND
        y1 = (rows * 0.5 - r0) * TILE_GROUND
        width = x1 - x0
        depth = y1 - y0
        center = ((x0 + x1) * 0.5, (y0 + y1) * 0.5)
        box(
            f"GEO-plateau-{index}",
            (center[0], center[1], high_top * 0.5),
            (width - 2.0, depth - 2.0, high_top),
            mats["plateau"],
            bevel=2.4,
        )
        box(
            f"GEO-plateau-top-{index}",
            (center[0], center[1], high_top + 0.4),
            (width - 8.0, depth - 8.0, 1.2),
            mats["plate_a"],
            bevel=1.4,
        )
        # 高台边缘的橙色压条，让高低差更清楚
        box(
            f"GEO-plateau-trim-{index}",
            (center[0], y0 + 2.5, high_top + 0.8),
            (width - 8.0, 3.0, 1.0),
            mats["accent"],
            bevel=0.0,
        )

    _build_road(map_data["routes"], tile_top, mats)
    _build_walls(field_w, field_d, margin, wall_depth, mats)
    _build_props(field_w, field_d, margin, wall_depth, mats)
    for index, (col, row) in enumerate(map_data["gates"]):
        _build_gate(index, col, row, mats)
    _build_core(core_tiles, mats)

def _build_road(routes: list, tile_top: float, mats: dict) -> None:
    """连续路面：整段铺一条深色带 + 中央亮线 + 方向箭头，转角用方块补齐。"""
    width = 34.0
    laid = set()
    arrow_index = 0
    for route in routes:
        for i in range(len(route) - 1):
            a = tuple(route[i])
            b = tuple(route[i + 1])
            key = tuple(sorted([a, b]))
            if key in laid:
                continue
            laid.add(key)
            pa = tile_center_ground(a[0], a[1])
            pb = tile_center_ground(b[0], b[1])
            mid = (pa + pb) * 0.5
            along_x = abs(pb.x - pa.x) > abs(pb.y - pa.y)
            length = (pb - pa).length + 6.0
            size = (length, width, 2.2) if along_x else (width, length, 2.2)
            box("GEO-road", (mid.x, mid.y, tile_top + 1.1), size, mats["road"], bevel=0.8)
            inner = (length, width - 12.0, 0.8) if along_x else (width - 12.0, length, 0.8)
            box("GEO-road-inner", (mid.x, mid.y, tile_top + 2.6), inner, mats["road_inner"], bevel=0.0)

            # 指向核心的白色箭头（两块斜板拼成 V）
            dirv = (pb - pa).normalized()
            base_angle = math.atan2(dirv.y, dirv.x)
            tip = pa + (pb - pa) * (0.45 if arrow_index % 2 == 0 else 0.62)
            for sign in (-1.0, 1.0):
                wing_center = tip - dirv * 5.0 + Vector((-dirv.y, dirv.x)) * (5.0 * sign)
                wing = box(
                    "GEO-road-arrow",
                    (wing_center.x, wing_center.y, tile_top + 3.2),
                    (11.0, 3.0, 0.7),
                    mats["mark"],
                    bevel=0.0,
                )
                wing.rotation_euler = (0.0, 0.0, base_angle + math.radians(38.0) * sign)
            arrow_index += 1

    # 转角补齐：每个路点铺一块方形路面
    for route in routes:
        for col, row in route:
            p = tile_center_ground(col, row)
            box("GEO-road-joint", (p.x, p.y, tile_top + 1.1), (width, width, 2.0), mats["road"], bevel=0.8)


def _build_props(field_w: float, field_d: float, margin: float, wall_depth: float, mats: dict) -> None:
    """沿外框摆一些箱体、管线和警示条，让 2.5D 的体块与投影读得出来。"""
    half_w = field_w * 0.5
    half_d = field_d * 0.5
    wall_h = 26.0
    crate_positions = [
        (-half_w + 24.0, half_d - 60.0),
        (-half_w + 24.0, half_d - 20.0),
        (half_w - 24.0, half_d - 30.0),
        (half_w - 24.0, -half_d + 40.0),
        (-half_w + 24.0, -half_d + 40.0),
    ]
    for index, (x, y) in enumerate(crate_positions):
        width = 22.0 + 6.0 * (index % 2)
        box(f"GEO-crate-{index}", (x, y, wall_h + width * 0.5), (width, width, width), mats["crate"], bevel=2.0)

    # 管线：沿南北两侧各一根，抬高一点避免和墙面共面
    for sign in (-1.0, 1.0):
        cylinder(
            "GEO-pipe",
            (0.0, sign * (half_d + wall_depth * 0.5), wall_h + 6.0),
            3.5,
            field_w * 0.9,
            mats["pipe"],
            vertices=20,
        ).rotation_euler = (0.0, math.pi / 2.0, 0.0)

    # 警示条：外框内侧的橙色短条
    for sign in (-1.0, 1.0):
        for step in range(4):
            x = -field_w * 0.3 + step * field_w * 0.2
            box(
                "GEO-hazard",
                (x, sign * (half_d + wall_depth * 0.5), wall_h + 1.0),
                (26.0, 6.0, 1.2),
                mats["accent"],
                bevel=0.0,
            )


def _build_walls(field_w: float, field_d: float, margin: float, wall_depth: float, mats: dict) -> None:
    half_w = field_w * 0.5
    half_d = field_d * 0.5
    wall_h = 26.0
    # 东西两侧
    for sign in (-1.0, 1.0):
        box(
            "GEO-wall-side",
            (sign * (half_w + margin * 0.5), 0.0, wall_h * 0.5),
            (margin, field_d + wall_depth * 2.0, wall_h),
            mats["wall"],
            bevel=4.0,
        )
    # 南北两侧
    for sign in (-1.0, 1.0):
        box(
            "GEO-wall-edge",
            (0.0, sign * (half_d + wall_depth * 0.5), wall_h * 0.5),
            (field_w, wall_depth, wall_h),
            mats["wall"],
            bevel=4.0,
        )
    # 四角柱 + 压条，给外框一点体块感
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            box(
                "GEO-pillar",
                (sx * (half_w + margin * 0.5), sy * (half_d + wall_depth * 0.5), 30.0),
                (margin * 1.3, wall_depth * 0.6, 60.0),
                mats["metal"],
                bevel=5.0,
            )
    box(
        "GEO-rail",
        (0.0, -half_d - wall_depth * 0.55, wall_h + 4.0),
        (field_w + margin * 2.0, 6.0, 5.0),
        mats["accent"],
        bevel=1.5,
    )


def _build_gate(index: int, col: int, row: int, mats: dict) -> None:
    center = tile_center_ground(col, row)
    top = 5.0
    # 缺口：门框压在瓦片上方，内芯发光
    box(f"GEO-gate-{index}-base", (center.x, center.y, top + 0.6), (42.0, 42.0, 1.2), mats["socket"], bevel=2.0)
    box(f"GEO-gate-{index}-glow", (center.x, center.y, top + 1.4), (34.0, 34.0, 1.0), mats["gate_glow"], bevel=1.0)
    frame = 44.0
    for dx, dy, sx, sy in (
        (0.0, -frame * 0.5, frame, 5.0),
        (0.0, frame * 0.5, frame, 5.0),
        (-frame * 0.5, 0.0, 5.0, frame),
        (frame * 0.5, 0.0, 5.0, frame),
    ):
        box(
            f"GEO-gate-{index}-frame",
            (center.x + dx, center.y + dy, top + 2.6),
            (sx, sy, 4.0),
            mats["gate_frame"],
            bevel=1.0,
        )


def _build_core(core_tiles: set, mats: dict) -> None:
    if not core_tiles:
        return
    points = [tile_center_ground(c, r) for c, r in core_tiles]
    center = sum(points, Vector((0.0, 0.0))) / float(len(points))
    # 核心贴着南墙，整体往场内挪一点，避免平台压到外框
    center.y += 8.0
    platform = 34.0
    cylinder("GEO-core-base", (center.x, center.y, 5.0), platform, 4.0, mats["core_base"], vertices=56)
    cylinder("GEO-core-ring", (center.x, center.y, 7.4), platform * 0.72, 2.0, mats["core_ring"], vertices=56)
    cylinder("GEO-core-inner", (center.x, center.y, 8.4), platform * 0.40, 2.0, mats["core_core"], vertices=48)
    for i in range(6):
        angle = math.tau * i / 6.0
        box(
            f"GEO-core-clamp-{i}",
            (center.x + math.cos(angle) * platform * 0.92, center.y + math.sin(angle) * platform * 0.92, 6.0),
            (11.0, 8.0, 5.0),
            mats["metal"],
            bevel=1.5,
        ).rotation_euler = (0.0, 0.0, angle)


# ---------------------------------------------------------------- 相机与渲染

def setup_camera() -> bpy.types.Object:
    cam_data = bpy.data.cameras.new("CAM-map")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = FRAME_W
    # 场景单位是像素级（几百），默认裁剪距离会把整个场景裁掉
    cam_data.clip_start = 100.0
    cam_data.clip_end = 20000.0
    cam = bpy.data.objects.new("CAM-map", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    distance = 4000.0
    cam.location = (
        0.0,
        -math.sin(CAM_X_ROT) * distance,
        math.cos(CAM_X_ROT) * distance,
    )
    cam.rotation_euler = (CAM_X_ROT, 0.0, 0.0)
    bpy.context.scene.camera = cam
    return cam


def setup_lights() -> None:
    sun_data = bpy.data.lights.new("LGT-sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(2.5)
    sun = bpy.data.objects.new("LGT-sun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-38.0))

    fill_data = bpy.data.lights.new("LGT-fill", "AREA")
    fill_data.energy = 90000.0
    fill_data.size = 600.0
    fill = bpy.data.objects.new("LGT-fill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (0.0, -500.0, 900.0)
    fill.rotation_euler = (math.radians(30.0), 0.0, 0.0)


def setup_render(out_path: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "GPU"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x = FRAME_W
    scene.render.resolution_y = FRAME_H
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filepath = str(out_path)
    world = bpy.data.worlds.new("WORLD-map")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.03, 0.035, 0.04, 1.0)
    background.inputs["Strength"].default_value = 0.6
    scene.world = world


def render_map(map_data: dict, outdir: Path) -> None:
    reset_scene()
    mats = make_materials()
    build_map(map_data, mats)
    setup_camera()
    setup_lights()
    outdir.mkdir(parents=True, exist_ok=True)
    out_path = outdir / f"map_{map_data['id']}.png"
    setup_render(out_path)
    bpy.ops.render.render(write_still=True)
    print(f"RENDERED {out_path}", flush=True)


def make_materials() -> dict:
    return {
        "base": material("MAT-base", (0.16, 0.17, 0.18), roughness=0.7),
        "plate_a": material("MAT-plate-a", (0.72, 0.72, 0.70), roughness=0.55, metallic=0.1),
        "plate_b": material("MAT-plate-b", (0.68, 0.68, 0.66), roughness=0.6, metallic=0.1),
        "lane": material("MAT-lane", (0.20, 0.23, 0.25), roughness=0.45, metallic=0.3),
        "lane_top": material("MAT-lane-top", (0.52, 0.56, 0.58), roughness=0.4, metallic=0.2),
        "road": material("MAT-road", (0.16, 0.18, 0.20), roughness=0.5, metallic=0.25),
        "road_inner": material("MAT-road-inner", (0.27, 0.30, 0.32), roughness=0.45, metallic=0.2),
        "crate": material("MAT-crate", (0.62, 0.58, 0.50), roughness=0.65),
        "pipe": material("MAT-pipe", (0.55, 0.58, 0.60), roughness=0.3, metallic=0.8),
        "mark": material("MAT-mark", (0.86, 0.88, 0.9), roughness=0.4, emission=(0.9, 0.93, 0.95), strength=0.15),
        "wall": material("MAT-wall", (0.40, 0.42, 0.44), roughness=0.5, metallic=0.2),
        "plateau": material("MAT-plateau", (0.46, 0.47, 0.47), roughness=0.6, metallic=0.15),
        "metal": material("MAT-metal", (0.55, 0.57, 0.59), roughness=0.35, metallic=0.7),
        "accent": material("MAT-accent", (0.95, 0.64, 0.23), roughness=0.4, emission=(0.95, 0.64, 0.23), strength=0.3),
        "socket": material("MAT-socket", (0.06, 0.07, 0.08), roughness=0.8),
        "gate_frame": material("MAT-gate-frame", (0.36, 0.38, 0.4), roughness=0.35, metallic=0.6),
        "gate_glow": material("MAT-gate-glow", (0.5, 0.06, 0.05), roughness=0.5, emission=(1.0, 0.20, 0.14), strength=2.2),
        "gatepad": material("MAT-gatepad", (0.30, 0.29, 0.29), roughness=0.6),
        "corepad": material("MAT-corepad", (0.76, 0.78, 0.79), roughness=0.5, metallic=0.1),
        "core_base": material("MAT-core-base", (0.74, 0.75, 0.72), roughness=0.45, metallic=0.15),
        "core_ring": material("MAT-core-ring", (0.3, 0.6, 0.62), roughness=0.35, emission=(0.41, 0.74, 0.76), strength=0.5),
        "core_core": material("MAT-core-core", (0.7, 0.95, 0.98), roughness=0.2, emission=(0.5, 0.95, 1.0), strength=0.6),
    }


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    outdir = ROOT / "assets" / "ui" / "25d"
    only = None
    if "--outdir" in argv:
        outdir = Path(argv[argv.index("--outdir") + 1])
        if not outdir.is_absolute():
            outdir = ROOT / outdir
    if "--map" in argv:
        only = argv[argv.index("--map") + 1]

    global DATA_JSON, FRAME_W, FRAME_H
    DATA_JSON = json.loads(DATA.read_text(encoding="utf-8"))
    FRAME_W = int(DATA_JSON["cols"] * TILE_GROUND + 48)
    FRAME_H = int(DATA_JSON["rows"] * TILE_SCREEN_Y + 48)
    for map_data in DATA_JSON["maps"]:
        if only and map_data["id"] != only:
            continue
        render_map(map_data, outdir)


DATA_JSON = {}


if __name__ == "__main__":
    main()
