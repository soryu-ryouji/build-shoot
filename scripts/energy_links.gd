extends Node2D

## 增益来源到目标的能量链。几何只在关系变化时更新，流动动画完全在 GPU 上运行。

const LINK_WIDTH := 10.0
const LINK_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;

varying float packet_count;
varying float phase;

void vertex() {
	packet_count = max(INSTANCE_CUSTOM.r, 1.0);
	phase = INSTANCE_CUSTOM.g;
}

void fragment() {
	float side = abs(UV.y - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.08, 0.30, side);
	float halo = 1.0 - smoothstep(0.15, 1.0, side);
	// UV.x 沿来源指向目标；减去 TIME 让能量包向终点流动。
	float wave = fract(UV.x * packet_count - TIME * 1.6 + phase);
	float packet = pow(1.0 - wave, 10.0);
	float endpoints = smoothstep(0.0, 0.035, UV.x) * (1.0 - smoothstep(0.965, 1.0, UV.x));
	float alpha = (halo * 0.08 + core * (0.12 + packet * 0.88)) * endpoints;
	COLOR = vec4(COLOR.rgb, COLOR.a * alpha);
}
"""

var _multimesh: MultiMesh
var _segments: Array = []


func _ready() -> void:
	# 高于建筑（z=4），低于命中特效（z=6），避免链节被建筑遮住。
	z_index = 5
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_multimesh.instance_count = 0
	var node := MultiMeshInstance2D.new()
	node.name = "EnergyLinkBatch"
	node.multimesh = _multimesh
	var shader := Shader.new()
	shader.code = LINK_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	add_child(node)


func set_links(links: Array) -> void:
	_segments.clear()
	if _multimesh == null:
		return
	_multimesh.instance_count = links.size()
	var count := 0
	for link in links:
		var source = link.get("source")
		var target = link.get("target")
		if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
			continue
		var source_pos: Vector2 = source.global_position
		var target_pos: Vector2 = target.global_position
		var offset := target_pos - source_pos
		var distance := offset.length()
		if distance <= 1.0:
			continue
		var direction := offset / distance
		var start := source_pos + direction * (float(source.get("base_radius")) + 5.0)
		var end := target_pos - direction * (float(target.get("base_radius")) + 5.0)
		var length := start.distance_to(end)
		if length <= 4.0:
			continue
		var center := (start + end) * 0.5
		var axis_x := direction * length
		var axis_y := direction.orthogonal() * LINK_WIDTH
		_multimesh.set_instance_transform_2d(count, Transform2D(axis_x, axis_y, center))
		_multimesh.set_instance_color(count, Color(0.34, 0.86, 1.0, 0.72))
		var phase := float(count % 8) / 8.0
		_multimesh.set_instance_custom_data(count, Color(length / 48.0, phase, 0.0, 0.0))
		_segments.append({"start": start, "end": end, "source": source, "target": target})
		count += 1
	_multimesh.instance_count = count


func link_count() -> int:
	return _segments.size()


func get_segments() -> Array:
	return _segments
