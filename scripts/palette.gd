extends RefCounted

## 全局配色。代码绘制与 assets/ui 下的美术素材共用这套色彩。

const BG := Color("0b0d10")
const PANEL := Color("14181c")
const ARENA_BG := Color("c7cbc8")
const GRID := Color(0.18, 0.22, 0.23, 0.18)
const BORDER := Color("a3a8aa")
const BORDER_GLOW := Color(0.45, 0.47, 0.48, 0.4)

const TEXT := Color("ece9e1")
const MUTED := Color("8f969b")
const INK := Color("17191b")
const INK_MUTED := Color("60676b")
const PAPER := Color("f0f0eb")
const CYAN := Color("69bdc2")
const ACCENT := Color("f1a33b")
const PINK := Color("b65c8d")
const BALL := Color("ffd375")
const DANGER := Color("e3655f")

const METAL := Color("73787c")
const METAL_DARK := Color("30353a")

const BLOCK_COLORS := [
	Color("69bdc2"),
	Color("718aa0"),
	Color("8b7195"),
	Color("b65c8d"),
	Color("b87355"),
	Color("d2a34f"),
]


static func block_color(hp: int) -> Color:
	return BLOCK_COLORS[clampi(hp - 1, 0, BLOCK_COLORS.size() - 1)]
