shader_type canvas_item;

// 主界面立绘待机动效：呼吸、重心摇摆、发梢与衣摆错位，全部由时间驱动。
// 贴图是一整张 720x960 设计稿尺寸的透明层，所以锚点直接用 UV 表示。

uniform float body_x : hint_range(0.0, 1.0) = 0.778;
uniform float feet_y : hint_range(0.0, 1.0) = 0.974;
uniform float head_y : hint_range(0.0, 1.0) = 0.26;
uniform float coat_y : hint_range(0.0, 1.0) = 0.68;

uniform float breathe_amount : hint_range(0.0, 0.01) = 0.003;
uniform float breathe_speed : hint_range(0.0, 3.0) = 1.15;
uniform float sway_degrees : hint_range(0.0, 2.0) = 0.24;
uniform float sway_speed : hint_range(0.0, 2.0) = 0.42;
uniform float hair_amount : hint_range(0.0, 0.01) = 0.0017;
uniform float hair_speed : hint_range(0.0, 3.0) = 0.9;
uniform float coat_amount : hint_range(0.0, 0.01) = 0.0015;
uniform float coat_speed : hint_range(0.0, 3.0) = 1.35;

void fragment() {
	vec2 uv = UV;
	vec2 pivot = vec2(body_x, feet_y);
	float t = TIME;

	// 呼吸：脚底固定，身体随吸气轻微拉长
	uv = (uv - pivot) / vec2(1.0, 1.0 + breathe_amount * sin(t * breathe_speed)) + pivot;

	// 重心左右缓慢偏移
	float angle = radians(sway_degrees) * sin(t * sway_speed);
	float cs = cos(angle);
	float sn = sin(angle);
	vec2 offset = uv - pivot;
	uv = pivot + vec2(offset.x * cs - offset.y * sn, offset.x * sn + offset.y * cs);

	// 发梢跟着风向落后半拍
	float head_band = 1.0 - smoothstep(0.0, 0.075, abs(uv.y - head_y));
	uv.x += hair_amount * head_band * sin(t * hair_speed + uv.y * 26.0);

	// 大衣下摆的摆动，越靠近衣角越明显，不带动裤子
	float coat_band = smoothstep(coat_y - 0.12, coat_y, uv.y) * (1.0 - smoothstep(0.79, 0.85, uv.y));
	uv.x += coat_amount * coat_band * sin(t * coat_speed + uv.x * 12.0);

	COLOR = texture(TEXTURE, uv) * COLOR;
}
