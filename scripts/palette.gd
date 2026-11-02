extends RefCounted

## 全局配色。所有绘制都用代码完成，不依赖美术资源。

const BG := Color("060912")
const PANEL := Color("0a1020")
const ARENA_BG := Color("080c17")
const GRID := Color(0.18, 0.31, 0.48, 0.22)
const BORDER := Color("8fa6c4")
const BORDER_GLOW := Color(0.17, 0.32, 0.52, 0.8)

const TEXT := Color("e9f2ff")
const MUTED := Color("7f92ab")
const CYAN := Color("38e0ff")
const ACCENT := Color("ffb347")
const PINK := Color("ff4fb0")
const BALL := Color("ffd166")
const DANGER := Color("ff5f6d")

const METAL := Color("59677a")
const METAL_DARK := Color("2b3442")

const BLOCK_COLORS := [
	Color("38e0ff"),
	Color("4d86ff"),
	Color("a25bff"),
	Color("ff4fb0"),
	Color("ff6b4a"),
	Color("ffd166"),
]


static func block_color(hp: int) -> Color:
	return BLOCK_COLORS[clampi(hp - 1, 0, BLOCK_COLORS.size() - 1)]
