# 美术提示词与出图规范

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
text, letters, words, numbers, watermark, logo, bright white background, cluttered center
```
- 对新建筑和激光塔，`tools/generate_ui_assets.py` 会自动在 Prompt 前加统一风格前缀：
```text
Using the supplied reference image only for rendering style, linework, cel shading and material language, do not copy its turret shape, gun, barrel or base plate.
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


## 环境与界面

### `arena`

- seed：`41027`
- 尺寸：768×1024 / 竖版
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/arena.png`
- 处理后：`assets/ui/arena.png`

Prompt：

```text
Full-screen vertical environment for an original anime tactical tower defense game, strict orthographic top-down view, bright cool light-gray concrete and off-white metal. The flat combat plaza spans 88 percent of the image width, from 6 percent to 94 percent, with no raised structures inside this wide area; the surrounding left, right, top and bottom edges continue the same map with industrial platforms, recessed machinery, vents, rails, panel seams and sparse signal orange warning stripes. Dark mechanical entrance structures along the top, side details confined to narrow outer maintenance strips, integrated lower industrial platform. High-end Japanese anime game environment art, crisp restrained cel shading, low contrast and no obstacles in the central play area. No humans, no enemies, no turrets, no text, no letters, no numbers, no logo, no UI, no border
```

### `menu_bg`

- seed：`52273`
- 尺寸：768×1024 / 竖版
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/menu_bg.png`
- 处理后：`assets/ui/menu_background.png`

Prompt：

```text
Portrait background plate for an original anime tactical tower defense game set in a world of colossal mobile industrial cities. An immense nomadic city megastructure stands on the horizon: a colossal armored crawler fortress carried on gigantic treaded legs and hydraulic struts, stacked arcology towers, cranes, gantries, hanging modules, pipes, antenna masts and thousands of tiny warm lights, its silhouette dissolving into pale atmospheric haze and low clouds. In the foreground a wide steel observation deck with a safety railing spans the entire bottom edge of the frame, empty and walkable, with industrial panels and pipes. Tiny transport vehicles and walkways give mile-deep scale to the megastructure. Cool light-gray and off-white industrial palette with restrained signal orange accents, bright overcast light, high-end Japanese anime game key visual, crisp cel shading, detailed clean rendering, cinematic vertical composition, open bright sky in the upper left for a game logo, quiet bright lower-left area for menu UI. No humans, no characters, no people, no text, no letters, no numbers, no logo, no border, no UI, no interface panels, no icons
```

### `menu_character`

- seed：`52273`
- 尺寸：768×1024 / 竖版
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/menu_character.png`
- 处理后：`assets/ui/menu_char_*.png`（拆成五层）

Prompt：

```text
Full body character art of an original anime tactical operator woman for a game key visual, standing upright, seen from behind at a three-quarter angle, facing away toward the upper left, ash silver short hair, long graphite and warm ivory tactical coat with signal orange trim, dark trousers and black boots, hands relaxed at her sides, calm relaxed posture. High-end Japanese anime game illustration, crisp cel shading, detailed clean rendering, soft overcast rim light from above and behind, the whole figure from the top of the head down to the boot soles fully visible with generous empty margins, isolated on a perfectly uniform solid chroma key green background, vivid pure green backdrop, clean edge separation between the figure and the green. No scenery, no platform, no railing, no other people, no text, no letters, no numbers, no logo, no border, no UI
```

## 怪物

### `monsters`

- seed：`73019`
- 尺寸：1024×1024 / 方形
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/monsters.png`
- 处理后：`assets/ui/monster_<kind>.png`（四类各一张）

Prompt：

```text
A 2D game sprite sheet with exactly four separate original anime tactical bio-mechanical enemy creatures in an exact two by two grid, orthographic top-down view, each centered in its quadrant on a perfectly uniform solid very dark charcoal background. Japanese anime game illustration with crisp cel shading, graphite black armor, warm ivory plates and signal orange cores. Top left: normal compact four-legged mechanical hound with a dark body and ivory head plate. Top right: swift lean winged predator with swept fins and a narrow agile silhouette. Bottom left: armored bulky crab beast with very thick layered ivory plating and heavy legs. Bottom right: elite tall spiked bio-mechanical beast with black violet armor and a bright orange core. No humans. Readable silhouettes at small size, similar visual scale, generous empty margins, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```

## 炮塔分层素材

### `turret_base`

- seed：`65201`
- 尺寸：1024×576 / 横版
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/turret_base.png`
- 处理后：`assets/ui/turret_base_field.png`

Prompt：

```text
Single isolated 2D game sprite of a circular turret mounting plate seen in a strict orthographic top-down view with the camera pointing straight down. Perfectly circular and radially symmetric like a flat technical diagram: concentric metal rings, a recessed dark circular socket in the center, evenly spaced bolts and vent slits around the rim, warm ivory and graphite gray metal with a few small amber indicator lights. Completely flat even lighting, no shadows, no highlights, no glossy reflections, no perspective, no tilt, no visible inner wall, no three dimensional bevel, thin crisp cel-shaded lines, Japanese anime game asset, centered on a perfectly uniform solid very dark charcoal background, generous empty margins, no turret body, no barrel, no gun, no text, no letters, no numbers, no border, no UI, no extra objects
```

### `heavy_turret_base`

- seed：`65213`
- 尺寸：1024×576 / 横版
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/heavy_turret_base.png`
- 处理后：`assets/ui/heavy_turret_base_field.png`

Prompt：

```text
Single isolated 2D game sprite of a broad regular octagonal turret mounting plate seen in a strict orthographic top-down view with the camera pointing straight down. Eight sided plate with exact eight fold rotational symmetry, like a flat technical diagram: concentric metal rings, a recessed dark circular socket in the center, evenly spaced bolts and vent slits, layered warm ivory and graphite gray plates with a few small amber indicator lights. Completely flat even lighting, no shadows, no highlights, no glossy reflections, no perspective, no tilt, no visible inner wall, no three dimensional bevel, thin crisp cel-shaded lines, Japanese anime game asset, centered on a perfectly uniform solid very dark charcoal background, generous empty margins, no turret body, no barrel, no gun, no text, no letters, no numbers, no border, no UI, no extra objects
```

### `laser_base`

- seed：`65231`
- 尺寸：1024×576 / 横版
- 参考图：`turret.png`
- 自动拼接风格前缀：是
- 生成源：`assets/ui/source/laser_base.png`
- 处理后：`assets/ui/laser_tower_base_field.png`

Prompt：

```text
Single isolated 2D game sprite of a compact circular laser turret mounting plate, strict orthographic top-down view from directly above, rendered as a physical three-dimensional object with visible plate thickness, side walls and natural foreshortening rather than a flat icon. Concentric layered metal rings with a recessed dark circular socket in the center, evenly spaced bolts, thin vent slits and a ring of small pale cyan power indicators, warm ivory ceramic armor and graphite gunmetal plates with a few signal orange accent lights. No turret body, no emitter, no barrel, no gun. High-end Japanese anime tactical game asset in the style of Arknights, crisp restrained cel shading, clean hard-edged linework, soft ambient occlusion, centered on a perfectly uniform solid very dark charcoal background, generous empty margins, no cast shadow on the background, no text, no letters, no numbers, no border, no UI, no extra objects
```

### `turret_layers`

- seed：`64103`
- 尺寸：1024×576 / 横版
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/turret_layers.png`
- 处理后：`assets/ui/turret_head_field.png`、`assets/ui/turret.png`

Prompt：

```text
Two separate original anime defense turret parts for a 2D tower defense game, arranged vertically on a perfectly uniform solid very dark charcoal background, both drawn in the same strict orthographic top-down view as if seen from directly above. Bottom: a compact circular armored base plate with a recessed empty circular bowl in the middle, panel seams, bolts, vents and small amber lights, with no turret body and no barrel on it. Top: the turret head that fits into that bowl, a graphite and warm ivory gun housing with one short sturdy barrel pointing straight up toward the top edge and a glowing signal orange energy core, with no base plate beneath it. A clear empty gap of plain background separates the two parts. Japanese anime game illustration, crisp cel shading, angular graphite mechanisms, warm ivory armor plates, signal orange accents. Both parts share the same vertical center axis, readable silhouettes, generous empty margins, no humans, no perspective tilt, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```

### `heavy_turret_layers`

- seed：`64117`
- 尺寸：1024×576 / 横版
- 参考图：无
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/heavy_turret_layers.png`
- 处理后：`assets/ui/heavy_turret_head_field.png`、`assets/ui/heavy_turret.png`

Prompt：

```text
Two separate original anime defense turret parts for a 2D tower defense game, arranged vertically on a perfectly uniform solid very dark charcoal background, both drawn in the same strict orthographic top-down view as if seen from directly above. Bottom: a broad hexagonal armored base plate with a recessed empty circular bowl in the middle, layered ivory and graphite plates, panel seams and orange warning lights, with no turret body and no barrel on it. Top: the heavy turret head that fits into that bowl, a massive graphite and warm ivory gun housing with two parallel reinforced barrels pointing straight up toward the top edge and glowing signal orange energy cores, with no base plate beneath it. A clear empty gap of plain background separates the two parts. Japanese anime game illustration, crisp cel shading, angular graphite mechanisms, warm ivory armor plates, signal orange accents. Both parts share the same vertical center axis, readable silhouettes, generous empty margins, no humans, no perspective tilt, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```

### `laser_layers`

- seed：`64129`
- 尺寸：1024×576 / 横版
- 参考图：`turret.png`
- 自动拼接风格前缀：是
- 生成源：`assets/ui/source/laser_layers.png`
- 处理后：`assets/ui/laser_tower_head_field.png`、`assets/ui/laser_tower.png`

Prompt：

```text
Two separate original anime laser defense turret parts for a 2D tower defense game, arranged vertically on a perfectly uniform solid very dark charcoal background, both drawn in the same strict orthographic top-down view as if seen from directly above, with visible physical thickness and natural foreshortening rather than flat icons. Bottom: a compact circular armored mounting plate with a recessed empty circular socket, concentric rings, bolts and cyan power indicators, no turret body and no barrel on it. Top: the laser emitter head that fits into that socket, a narrow graphite and warm ivory housing with one long slender emitter barrel pointing straight up toward the top edge, a glowing pale cyan lens at the muzzle, copper coil rings and small signal orange capacitor lights, with no base plate beneath it. A clear empty gap of plain background separates the two parts. High-end Japanese anime tactical game asset in the style of Arknights, crisp restrained cel shading, angular graphite mechanisms, warm ivory armor plates, signal orange accents, pale cyan energy details. Both parts share the same vertical center axis, readable silhouettes, generous empty margins, no humans, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```

## 三类建筑

### `sandbag`

- seed：`65301`
- 尺寸：1024×576 / 横版
- 参考图：`turret.png`
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/sandbag.png`
- 处理后：`assets/ui/sandbag_field.png`、`assets/ui/sandbag.png`

Prompt：

```text
Using the supplied reference image only for rendering style, linework, cel shading and material language, do not copy its turret shape or any mechanical gun parts. Create a single isolated 2D game sprite of a low sandbag barricade for a top-down anime tactical tower defense game. Camera pointing straight down from directly above, the top surfaces of the bags dominate the image and only a thin front edge is visible, with correct foreshortening and visible physical thickness rather than a flat icon. A compact square low wall segment built from three rows and three columns of tan canvas sandbags with visible seams, creases and slightly varied bag shapes, held by two small graphite metal stakes. No base plate, no wheels, no people, no turret, no gun, no barrel. Hand-painted 2D anime tactical game asset in the style of Arknights, bold clean outlines, two-tone crisp cel shading, flat restrained colors, warm sand canvas and graphite accents, soft ambient occlusion, centered on a perfectly uniform solid very dark charcoal background, generous empty margins, no cast shadow on the background, no text, no letters, no numbers, no border, no UI, no extra objects, no photorealism, no soft 3D render
```

### `compression_tower`

- seed：`65317`
- 尺寸：1024×576 / 横版
- 参考图：`turret.png`
- 自动拼接风格前缀：是
- 生成源：`assets/ui/source/compression_tower.png`
- 处理后：`assets/ui/compression_tower_field.png`、`assets/ui/compression_tower.png`

Prompt：

```text
Single isolated 2D game sprite of a compact compression energy tower for a top-down anime tactical tower defense game. Strict orthographic top-down view from directly above, rendered as a physical three-dimensional object with visible thickness, side walls, panel seams and natural foreshortening rather than a flat icon. A broad octagonal graphite base with layered warm ivory armor plates, two short vertical tuning prongs, a glowing pale cyan compression core in the center, copper coil rings, thin vents and small signal orange warning lights. No gun barrel, no sandbags, no people. High-end Japanese anime tactical game asset in the style of Arknights, crisp restrained cel shading, clean hard-edged linework, soft ambient occlusion, centered on a perfectly uniform solid very dark charcoal background, generous empty margins, no cast shadow on the background, no text, no letters, no numbers, no border, no UI, no extra objects
```

### `solar`

- seed：`65333`
- 尺寸：1024×576 / 横版
- 参考图：`turret.png`
- 自动拼接风格前缀：是
- 生成源：`assets/ui/source/solar.png`
- 处理后：`assets/ui/solar_field.png`、`assets/ui/solar.png`

Prompt：

```text
Single isolated 2D game sprite of a small ground-mounted solar panel array for a top-down anime tactical tower defense game. Strict orthographic top-down view from directly above, with the four dark blue photovoltaic panels tilted a few degrees so their physical thickness, pale metal grid lines, ivory frame and low graphite mounting legs are visible with correct foreshortening rather than a flat icon. Two by two cells with thin pale separation lines, a small signal orange status lamp, industrial bolts and a compact base. No people, no text on the panels. High-end Japanese anime tactical game asset in the style of Arknights, crisp restrained cel shading, clean hard-edged linework, soft ambient occlusion, centered on a perfectly uniform solid very dark charcoal background, generous empty margins, no cast shadow on the background, no letters, no numbers, no border, no UI, no extra objects
```

### `fusion_tower`

- seed：`65349`
- 尺寸：1024×576 / 横版
- 参考图：`turret.png`
- 自动拼接风格前缀：是
- 生成源：`assets/ui/source/fusion_tower.png`
- 处理后：`assets/ui/fusion_tower_field.png`、`assets/ui/fusion_tower.png`

Prompt：

```text
Single isolated 2D game sprite of a compact fusion power tower for a top-down anime tactical tower defense game. Strict orthographic top-down view from directly above, rendered as a physical three-dimensional object with visible thickness, side walls and natural foreshortening rather than a flat icon. A cylindrical reactor core with a glowing warm golden plasma center, heavy graphite ring frame, layered warm ivory armor segments, copper coil rings, thin industrial vents and small signal orange energy arcs. No gun barrel, no people. High-end Japanese anime tactical game asset in the style of Arknights, crisp restrained cel shading, clean hard-edged linework, soft ambient occlusion, centered on a perfectly uniform solid very dark charcoal background, generous empty margins, no cast shadow on the background, no text, no letters, no numbers, no border, no UI, no extra objects
```

## 怪物四帧动画

### `anim_normal`

- seed：`83101`
- 尺寸：1024×1024 / 方形
- 参考图：`monster_normal.png`
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/anim_normal.png`
- 处理后：`assets/ui/monster_normal_anim.png`

Prompt：

```text
Using the supplied reference creature, create a four-frame 2D game animation sprite sheet in an exact two by two grid. All four frames show the SAME character with identical colors, proportions, armor details, orthographic top-down camera and facing direction. Animate only alternating beetle leg steps and a subtle body bob. Frame one top left, frame two top right, frame three bottom left, frame four bottom right. Each full body is centered at the same position and scale within its quadrant, on a perfectly uniform solid very dark navy background. Make the motion subtle and loopable, with no redesign between frames. Crisp clean silhouettes, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```

### `anim_swift`

- seed：`83117`
- 尺寸：1024×1024 / 方形
- 参考图：`monster_swift.png`
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/anim_swift.png`
- 处理后：`assets/ui/monster_swift_anim.png`

Prompt：

```text
Using the supplied reference creature, create a four-frame 2D game animation sprite sheet in an exact two by two grid. All four frames show the SAME character with identical colors, proportions, armor details, orthographic top-down camera and facing direction. Animate only small wing flaps and a gentle hovering bob. Frame one top left, frame two top right, frame three bottom left, frame four bottom right. Each full body is centered at the same position and scale within its quadrant, on a perfectly uniform solid very dark navy background. Make the motion subtle and loopable, with no redesign between frames. Crisp clean silhouettes, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```

### `anim_armored`

- seed：`83133`
- 尺寸：1024×1024 / 方形
- 参考图：`monster_armored.png`
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/anim_armored.png`
- 处理后：`assets/ui/monster_armored_anim.png`

Prompt：

```text
Using the supplied reference creature, create a four-frame 2D game animation sprite sheet in an exact two by two grid. All four frames show the SAME character with identical colors, proportions, armor details, orthographic top-down camera and facing direction. Animate only slow alternating crab leg steps and heavy body sway. Frame one top left, frame two top right, frame three bottom left, frame four bottom right. Each full body is centered at the same position and scale within its quadrant, on a perfectly uniform solid very dark navy background. Make the motion subtle and loopable, with no redesign between frames. Crisp clean silhouettes, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```

### `anim_elite`

- seed：`83149`
- 尺寸：1024×1024 / 方形
- 参考图：`monster_elite.png`
- 自动拼接风格前缀：否
- 生成源：`assets/ui/source/anim_elite.png`
- 处理后：`assets/ui/monster_elite_anim.png`

Prompt：

```text
Using the supplied reference creature, create a four-frame 2D game animation sprite sheet in an exact two by two grid. All four frames show the SAME character with identical colors, proportions, armor details, orthographic top-down camera and facing direction. Animate only deliberate leg steps, slight spike motion and a pulsing core. Frame one top left, frame two top right, frame three bottom left, frame four bottom right. Each full body is centered at the same position and scale within its quadrant, on a perfectly uniform solid very dark navy background. Make the motion subtle and loopable, with no redesign between frames. Crisp clean silhouettes, no text, no letters, no numbers, no dividers, no border, no UI, no extra objects
```


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
