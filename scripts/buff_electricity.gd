extends Node2D

## 强化建筑的环绕电弧。GPU 驱动旋转和抖动，倍率只改变弧段数量。

const MAX_ARCS := 12
const ELECTRIC_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float extent = 96.0;
uniform float orbit_radius = 38.0;
uniform float phase = 0.0;
uniform int arc_count = 2;
uniform vec4 electric_color : source_color = vec4(0.40, 0.90, 1.0, 1.0);

void fragment() {
	vec2 local = (UV - 0.5) * extent;
	float radius = length(local);
	float angle = atan(local.y, local.x);
	float energy = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= arc_count) {
			break;
		}
		float fi = float(i);
		float center = fi * 6.2831853 / float(arc_count) + TIME * 1.25 + phase;
		float angular_distance = abs(atan(sin(angle - center), cos(angle - center)));
		float segment = 1.0 - smoothstep(0.34, 0.62, angular_distance);
		float wobble = sin(angle * 13.0 + TIME * 19.0 + fi) * 1.25;
		wobble += sin(angle * 29.0 - TIME * 27.0 + fi * 2.0) * 0.65;
		float radial = abs(radius - orbit_radius - wobble);
		float core = 1.0 - smoothstep(0.25, 1.25, radial);
		float glow = 1.0 - smoothstep(0.8, 4.5, radial);
		energy += segment * (core + glow * 0.24);
	}
	COLOR = vec4(electric_color.rgb, electric_color.a * min(energy, 1.0) * 0.82);
}
"""

var emitting := false:
	set(value):
		emitting = value
		_update_visibility()
var _multiplier := 1.0
var _arcs := 0
var _material: ShaderMaterial


func _ready() -> void:
	z_index = 1
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ELECTRIC_SHADER
	_material.shader = shader
	var parent := get_parent()
	var base_radius := float(parent.get("base_radius")) if parent != null else 26.0
	_material.set_shader_parameter("extent", (base_radius + 22.0) * 2.0)
	_material.set_shader_parameter("orbit_radius", base_radius + 12.0)
	_material.set_shader_parameter("phase", float(get_instance_id() % 100) * 0.071)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (base_radius + 22.0) * 2.0
	var mesh := MeshInstance2D.new()
	mesh.name = "ElectricityMesh"
	mesh.mesh = quad
	mesh.material = _material
	add_child(mesh)
	_update_visibility()


func set_multiplier(value: float) -> void:
	if is_equal_approx(_multiplier, value):
		return
	_multiplier = value
	if value <= 1.0:
		_arcs = 0
	else:
		var doublings := int(floor(log(value) / log(2.0) + 0.001))
		_arcs = clampi(1 + doublings, 2, MAX_ARCS)
	if _material != null:
		_material.set_shader_parameter("arc_count", _arcs)
	_update_visibility()


func get_arc_count() -> int:
	return _arcs


func _update_visibility() -> void:
	visible = emitting and _arcs > 0
