extends RefCounted

## 移动端 UI 基线。设计视口固定 400×800，1 逻辑像素约等于手机上的 1dp。
## 可点击控件的短边不小于 TOUCH，正文不小于 FONT_BODY，保证手机上好按、好看。

const DESIGN := Vector2i(400, 800)

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

const HUD_HEIGHT := 94.0
const SHOP_HEIGHT := 112.0
const TOAST_HEIGHT := 52.0
