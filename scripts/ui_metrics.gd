extends RefCounted

## 横屏 UI 基线。960×540 逻辑视口，宽屏设备只扩展横向空间。
## 可点击控件的短边不小于 TOUCH，正文不小于 FONT_BODY。

const DESIGN := Vector2i(960, 540)

const MARGIN := 14.0
const GAP := 10.0

## 点击区域下限（逻辑像素 ≈ dp）
const TOUCH := 52.0
const TOUCH_LARGE := 58.0

const FONT_MICRO := 12
const FONT_SMALL := 13
const FONT_BODY := 15
const FONT_LABEL := 17
const FONT_TITLE := 23
const FONT_DISPLAY := 42

## 顶部只保留菜单、金币与能源；底部为标签页和可直接拖拽的道具卡。
const HUD_HEIGHT := 60.0
const SHOP_HEIGHT := 146.0
const SHOP_MAX_WIDTH := 680.0
const SHOP_TAB_HEIGHT := 48.0
const SHOP_CARD_HEIGHT := 76.0
const FOCUS_WIDTH := 720.0
const TOAST_HEIGHT := 48.0
