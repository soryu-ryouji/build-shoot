extends Control

## 主界面立绘骨架：五张分层贴图按各自枢轴摆动。
## 腿部只跟随整体重心，躯干负责呼吸，头部绕颈转动，右臂和大衣用弹簧做延迟跟随。

const DesignSize := Vector2(720.0, 960.0)
const LegsTexture = preload("res://assets/ui/menu_char_legs.png")
const CoatTexture = preload("res://assets/ui/menu_char_coat.png")
const TorsoTexture = preload("res://assets/ui/menu_char_torso.png")
const ArmTexture = preload("res://assets/ui/menu_char_arm_r.png")
const HeadTexture = preload("res://assets/ui/menu_char_head.png")

# 设计稿坐标下的关节位置
const FEET := Vector2(560.0, 935.0)
const HIP := Vector2(560.0, 560.0)
const COAT := Vector2(560.0, 545.0)
const SHOULDER := Vector2(636.0, 395.0)
const NECK := Vector2(562.0, 360.0)

const BODY_SWAY_DEG := 0.5
const BODY_SPEED := 0.55
const HEAD_TILT_DEG := 2.4
const HEAD_SPEED := 0.9
const BREATH_SCALE := 0.0065
const BREATH_SPEED := 1.45

var _time := 0.0
var _body_angle := 0.0
var _breath := 1.0
var _head_angle := 0.0
var _head_offset := Vector2.ZERO
var _coat_angle := 0.0
var _coat_velocity := 0.0
var _arm_angle := 0.0
var _arm_velocity := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	var breath := sin(_time * BREATH_SPEED)
	var gust := smoothstep(0.45, 1.0, sin(_time * 0.23 + 2.1))
	var wind := 0.75 + 0.9 * gust

	_body_angle = deg_to_rad(BODY_SWAY_DEG) * sin(_time * BODY_SPEED) * (0.8 + 0.2 * wind)
	_breath = 1.0 + BREATH_SCALE * breath

	# 大衣比重心慢一拍，弹簧带一点过冲
	var coat_target := -_body_angle * 1.6 + deg_to_rad(0.9) * sin(_time * 0.43 + 1.0) * wind
	_coat_velocity += (coat_target - _coat_angle) * 18.0 * delta
	_coat_velocity *= exp(-6.0 * delta)
	_coat_angle += _coat_velocity * delta

	# 右臂绕肩摆，相位和重心错开
	var arm_target := -_body_angle * 0.8 + deg_to_rad(0.6) * sin(_time * 0.5 - 0.9) * wind
	_arm_velocity += (arm_target - _arm_angle) * 35.0 * delta
	_arm_velocity *= exp(-6.0 * delta)
	_arm_angle += _arm_velocity * delta

	# 头颈：缓慢转动 + 横向微移 + 点头，叠加重心反作用
	_head_angle = deg_to_rad(HEAD_TILT_DEG) * sin(_time * HEAD_SPEED) * (0.75 + 0.25 * sin(_time * 0.19 + 1.0))
	_head_angle += -_body_angle * 0.35
	_head_offset = Vector2(
		2.2 * sin(_time * 0.29 + 0.4) * wind,
		1.4 * sin(_time * HEAD_SPEED - 0.5) + 1.0 * breath,
	)
	queue_redraw()


func _draw() -> void:
	var base := Transform2D(0.0, size / DesignSize, 0.0, Vector2.ZERO)
	var body := _rotate_around(FEET, _body_angle)
	var hips := body * _scale_around(HIP, Vector2(1.0, _breath))

	_draw_part(LegsTexture, base * body)
	_draw_part(CoatTexture, base * hips * _rotate_around(COAT, _coat_angle))
	_draw_part(TorsoTexture, base * hips)
	_draw_part(ArmTexture, base * hips * _rotate_around(SHOULDER, _arm_angle))
	_draw_part(
		HeadTexture,
		base * hips * Transform2D(0.0, _head_offset) * _rotate_around(NECK, _head_angle),
	)


func _draw_part(texture: Texture2D, matrix: Transform2D) -> void:
	draw_set_transform_matrix(matrix)
	draw_texture(texture, Vector2.ZERO)


func _rotate_around(pivot: Vector2, angle: float) -> Transform2D:
	var rotation := Transform2D(angle, Vector2.ZERO)
	return Transform2D(rotation.x, rotation.y, pivot - rotation * pivot)


func _scale_around(pivot: Vector2, factor: Vector2) -> Transform2D:
	return Transform2D(
		Vector2(factor.x, 0.0),
		Vector2(0.0, factor.y),
		pivot - Vector2(factor.x * pivot.x, factor.y * pivot.y),
	)
