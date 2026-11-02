shader_type canvas_item;

// 主界面立绘待机动效：只有一张贴图，按局部权重做近似 Live2D 的形变。
// 坐标都是 720x960 设计稿 UV，锚点取自立绘实际位置：脚底、颈部、头部、衣摆。

uniform float feet_x = 0.78;
uniform float feet_y = 0.974;
uniform float neck_x = 0.781;
uniform float neck_y = 0.372;
// 头部权重按高度分带：颈部以上整颗头参与，颈部附近平滑过渡到躯干
uniform float head_band_top : hint_range(0.2, 0.6) = 0.335;
uniform float head_band_bottom : hint_range(0.3, 0.7) = 0.395;
uniform float torso_cy : hint_range(0.2, 0.8) = 0.50;
uniform float torso_ry : hint_range(0.05, 0.3) = 0.115;
uniform float coat_top : hint_range(0.3, 0.9) = 0.58;
uniform float coat_hem : hint_range(0.5, 1.0) = 0.735;

uniform float body_sway_deg : hint_range(0.0, 2.0) = 0.50;
uniform float body_sway_speed : hint_range(0.0, 2.0) = 0.55;
uniform float head_tilt_deg : hint_range(0.0, 5.0) = 2.6;
uniform float head_speed : hint_range(0.0, 2.0) = 0.9;
uniform float head_shift : hint_range(0.0, 0.01) = 0.0018;
uniform float hair_amount : hint_range(0.0, 0.01) = 0.0048;
uniform float coat_amount : hint_range(0.0, 0.01) = 0.0062;
uniform float breathe_amount : hint_range(0.0, 0.01) = 0.0028;
uniform float breathe_speed : hint_range(0.0, 3.0) = 1.45;
uniform float arm_deg : hint_range(0.0, 3.0) = 1.0;

vec2 rotate_around(vec2 point, vec2 center, float angle) {
	float cs = cos(angle);
	float sn = sin(angle);
	vec2 d = point - center;
	return center + vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
}

float blob(vec2 point, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.72, 1.05, length((point - center) / radius));
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float breath = sin(t * breathe_speed);

	// 重心：绕脚底整体轻摆，双脚固定在地面
	uv = rotate_around(uv, vec2(feet_x, feet_y), -radians(body_sway_deg) * sin(t * body_sway_speed));

	// 呼吸：胸腹起伏，腰部以下逐渐静止
	float torso = blob(uv, vec2(feet_x, torso_cy), vec2(0.13, torso_ry));
	uv.y += breathe_amount * breath * torso;

	// 头部：颈部以上整颗头绕颈转动，叠缓慢左右微移和点头
	float head = 1.0 - smoothstep(head_band_top, head_band_bottom, uv.y);
	float tilt = radians(head_tilt_deg) * sin(t * head_speed) * (0.75 + 0.25 * sin(t * 0.19 + 1.0));
	uv = mix(uv, rotate_around(uv, vec2(neck_x, neck_y), -tilt), head);
	uv.x += head_shift * sin(t * 0.29 + 0.4) * head;
	uv.y += 0.0011 * sin(t * head_speed - 0.5) * head + 0.0005 * breath * head;

	// 手臂：绕肩轻轻前后摆，和重心错开相位
	float arm_swing = radians(arm_deg) * sin(t * body_sway_speed - 0.9);
	float arm_l = blob(uv, vec2(0.672, 0.53), vec2(0.050, 0.135));
	float arm_r = blob(uv, vec2(0.892, 0.53), vec2(0.050, 0.135));
	uv = mix(uv, rotate_around(uv, vec2(0.676, 0.395), arm_swing), arm_l);
	uv = mix(uv, rotate_around(uv, vec2(0.888, 0.395), -arm_swing), arm_r);

	// 偶发的一阵风：幅度和频率都比基础摆动高一档，让待机不是单纯的循环
	float gust = smoothstep(0.45, 1.0, sin(t * 0.23 + 2.1));
	float wind = 0.7 + 1.1 * gust;

	// 发丝：比头部慢半拍，叠一个二次谐波做回弹
	float hair = head * (1.0 - smoothstep(head_band_top, neck_y, uv.y));
	float hair_phase = t * head_speed - 0.85;
	uv.x += hair_amount * wind * (sin(hair_phase) + 0.3 * sin(hair_phase * 2.0)) * hair;
	uv.x += 0.0018 * gust * sin(t * 2.6 + uv.y * 8.0) * hair;
	uv.y += 0.0012 * sin(t * head_speed * 0.5 + 1.7) * hair;

	// 大衣下摆：左右摆加轻微上下浮动，裤腿和靴子不受影响
	float coat = smoothstep(coat_top, 0.68, uv.y) * (1.0 - smoothstep(coat_hem - 0.01, coat_hem + 0.045, uv.y));
	float coat_phase = t * 0.8 - 1.0;
	uv.x += coat_amount * wind * (sin(coat_phase) + 0.28 * sin(coat_phase * 2.0 + 0.4)) * coat;
	uv.x += 0.0016 * gust * sin(t * 2.2 + 0.7) * coat;
	uv.y += 0.0010 * sin(t * 1.25 + 0.6) * coat;

	COLOR = texture(TEXTURE, uv) * COLOR;
}
