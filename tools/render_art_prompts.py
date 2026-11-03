#!/usr/bin/env python3
"""Render ART_PROMPTS.md from generate_ui_assets.PRESETS so the catalog cannot drift."""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("generate_ui_assets", ROOT / "tools" / "generate_ui_assets.py")
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

OUTPUTS = {
    "arena": "`assets/ui/arena.png`",
    "menu_bg": "`assets/ui/menu_background.png`",
    "menu_character": "`assets/ui/menu_char_*.png`（拆成五层）",
    "monsters": "`assets/ui/monster_<kind>.png`（四类各一张）",
    "turret_base": "`assets/ui/turret_base_field.png`",
    "heavy_turret_base": "`assets/ui/heavy_turret_base_field.png`",
    "laser_base": "`assets/ui/laser_tower_base_field.png`",
    "turret_layers": "`assets/ui/turret_head_field.png`、`assets/ui/turret.png`",
    "heavy_turret_layers": "`assets/ui/heavy_turret_head_field.png`、`assets/ui/heavy_turret.png`",
    "laser_layers": "`assets/ui/laser_tower_head_field.png`、`assets/ui/laser_tower.png`",
    "sandbag": "`assets/ui/sandbag_field.png`、`assets/ui/sandbag.png`",
    "compression_tower": "`assets/ui/compression_tower_field.png`、`assets/ui/compression_tower.png`",
    "solar": "`assets/ui/solar_field.png`、`assets/ui/solar.png`",
    "fusion_tower": "`assets/ui/fusion_tower_field.png`、`assets/ui/fusion_tower.png`",
    "anim_normal": "`assets/ui/monster_normal_anim.png`",
    "anim_swift": "`assets/ui/monster_swift_anim.png`",
    "anim_armored": "`assets/ui/monster_armored_anim.png`",
    "anim_elite": "`assets/ui/monster_elite_anim.png`",
}
GROUPS = [
    ("环境与界面", ["arena", "menu_bg", "menu_character"]),
    ("怪物", ["monsters"]),
    ("炮塔分层素材", ["turret_base", "heavy_turret_base", "laser_base", "turret_layers", "heavy_turret_layers", "laser_layers"]),
    ("三类建筑", ["sandbag", "compression_tower", "solar", "fusion_tower"]),
    ("怪物四帧动画", ["anim_normal", "anim_swift", "anim_armored", "anim_elite"]),
]

HEADER = """# 美术提示词与出图规范

本文件是《构筑枪械 Build Shoot》的美术生成入口。其他 AI 或工具先读本文件，不要只根据游戏截图猜风格。每个资产都给出可直接复制的 Prompt、参考图、seed、尺寸与后处理命令。

本文件由 `tools/render_art_prompts.py` 从 `tools/generate_ui_assets.py` 的 `PRESETS` 生成。改 Prompt 时先改生成脚本，再重跑：

```bash
python tools/render_art_prompts.py
```

- 生成脚本：`tools/generate_ui_assets.py`
- ComfyUI 工作流：`tools/qwen_workflow.source.json`
- 后处理脚本：`tools/process_ui_assets.py`
- 原始生成图：`assets/ui/source/`
- 成品透明素材：`assets/ui/`

## 生成环境

- ComfyUI 端点：`http://127.0.0.1:8188`
- 模型：`qwen_image_2.1-Q4_K.gguf`，25 steps，cfg 1，`euler` / `simple`
- 文本编码器：`qwen3vl_8b_w4a8.safetensors`；VAE：`qwen_image_2.1_vae_bf16.safetensors`
- 默认朝向：横版预设实测约 1024×576；竖版预设 768×1024；方形预设 1024×1024
- 新建筑统一用 `assets/ui/turret.png` 作为风格参考；动画用对应的 `assets/ui/monster_<kind>.png`
- 统一负向提示词：
```text
{NEGATIVE}
```
- 对新建筑和激光塔，`tools/generate_ui_assets.py` 会自动在 Prompt 前加统一风格前缀：
```text
{STYLE_PREFIX}
```

## 风格硬约束

- 明日方舟式战术动画质感：清晰的硬边线稿、两段式赛璐璐上色、克制的明暗层次。
- 材质语言：暖象牙白陶瓷装甲、石墨金属、信号橙点缀、青蓝能量件。
- 视角：严格俯视，但必须画出物理厚度、侧壁、面板接缝和自然透视缩短；不要扁平图标，也不要等距视角。
- 场景背景：完全均匀的深炭灰背景，主体居中，四周留白，背景上不要投影。
- 可读性：缩到 64px 网格仍能看出轮廓；主体不要被细小零件切碎。
- 禁止：文字、字母、数字、logo、UI、边框、人物、无关道具、过曝白边、杂乱背景。
- 透视要求：炮塔/激光塔的炮管朝画面上方；基盘和头部共用垂直中心轴；静态建筑不旋转，允许画一点正面厚度。
- 不要复制参考图里的炮塔、枪管或基盘造型，只借用画风、线条和材质。

## Prompt 模板

```text
[风格前缀] + [单个主体是什么] + [严格俯视/厚度/透视] + [材质与配色] + [背景与留白] + [禁止项]
```

短提示词容易退化成柔光 3D 渲染，必须保留 `crisp cel shading`、`bold clean outlines`、`two-tone shading`、`no photorealism` 这类约束。

## 资产清单与 Prompt

下面是 `tools/generate_ui_assets.py` 中所有预设的完整 Prompt。`style_reference` 为“是”的预设，实际提交给 ComfyUI 时会在 Prompt 前自动拼接上面的风格前缀。

"""

FOOTER = """
## 后处理与接入

### 常用命令

```bash
# 只重做新建筑（沙袋、压缩塔、太阳能、聚能塔）
python tools/generate_ui_assets.py buildings
python tools/process_ui_assets.py buildings

# 只重做激光塔（基盘 + 发射头）
python tools/generate_ui_assets.py laser_base
python tools/generate_ui_assets.py laser_layers
python tools/process_ui_assets.py laser

# 炮塔/重型炮塔/激光塔全部重做
python tools/process_ui_assets.py bases
python tools/process_ui_assets.py layers
```

替换 PNG 后必须重新导入：

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```

### 输出规格

- 场上静态建筑：320×320 透明 PNG，主体占画面约 89%
- 商店图标：256×256 透明 PNG，主体居中留 8% 边距
- 炮塔基盘：320×320，基盘圆心就是旋转轴
- 炮塔头部：320×384，枢轴在 `(160, 320)`，炮管朝上
- 激光塔沿用炮塔的基盘/头部两层结构，基盘不随瞄准旋转
- 静态建筑不旋转，单张图直接居中绘制

### 代码接入

- `scripts/item_defs.gd`：建筑的 `icon`、`sprite_scale`、数值
- `scripts/placed_building.gd`：静态建筑贴图、炮塔/激光塔分层绘制、血量与离线标记
- `scripts/turret_visuals.gd`：炮塔、重型炮塔、激光塔的旋转与后坐
- `scripts/item_card.gd`：商店卡片图标
- `scripts/placement_ghost.gd`：拖拽预览

### 验收清单

- [ ] 背景已完全透明，没有白色或深色碎屑
- [ ] 深蓝太阳能电池片、深色石墨件没有被抠掉
- [ ] 主体没有文字、边框、UI、人物或多余物体
- [ ] 俯视透视一致，炮管朝上，基盘/头部中心轴对齐
- [ ] 场上 64px 网格下轮廓清楚，商店图标不糊
- [ ] 颜色与现有炮塔一致：象牙白、石墨灰、信号橙、青蓝
- [ ] 重新导入后 `smoke_test` 与 `responsive_test` 通过
"""


def format_size(preset: dict) -> str:
    if "width" in preset and "height" in preset:
        size = f"{preset['width']}×{preset['height']}"
        if preset["width"] == preset["height"]:
            orientation = "方形"
        else:
            orientation = "横版" if preset.get("landscape") else "竖版"
    else:
        size = "1024×576" if preset.get("landscape") else "768×1024"
        orientation = "横版" if preset.get("landscape") else "竖版"
    return f"{size} / {orientation}"


def render_preset(name: str, preset: dict) -> str:
    reference = preset.get("reference", "无")
    style_ref = "是" if preset.get("style_reference") else "否"
    lines = [
        f"### `{name}`",
        "",
        f"- seed：`{preset['seed']}`",
        f"- 尺寸：{format_size(preset)}",
        f"- 参考图：`{reference}`" if reference != "无" else "- 参考图：无",
        f"- 自动拼接风格前缀：{style_ref}",
        f"- 生成源：`assets/ui/source/{name}.png`",
        f"- 处理后：{OUTPUTS.get(name, '见 process_ui_assets.py')}",
        "",
        "Prompt：",
        "",
        "```text",
        str(preset["prompt"]).strip(),
        "```",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parts = [HEADER.format(NEGATIVE=MODULE.NEGATIVE, STYLE_PREFIX=MODULE.STYLE_REFERENCE_PREFIX.strip())]
    for title, names in GROUPS:
        parts.append(f"## {title}\n")
        for name in names:
            parts.append(render_preset(name, MODULE.PRESETS[name]))
    parts.append(FOOTER)
    (ROOT / "ART_PROMPTS.md").write_text("\n".join(parts), encoding="utf-8")
    print("wrote ART_PROMPTS.md")


if __name__ == "__main__":
    main()
