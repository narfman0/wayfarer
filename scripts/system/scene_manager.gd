## Autoload — level transitions with fade, portal spawn staging, and the
## plane-id → scene registry.
extends CanvasLayer

const LEVELS := {
	"tamori": "res://scenes/world/tamori.tscn",
	"dungeon_run": "res://scenes/world/dungeon_run.tscn",
	"tamori_road": "res://scenes/world/tamori_road.tscn",
	"tamori_fields": "res://scenes/world/tamori_fields.tscn",
	"tamori_anchor": "res://scenes/world/tamori_anchor.tscn",
	"reach": "res://scenes/world/reach.tscn",
	"reach_rig": "res://scenes/world/reach_rig.tscn",
	"kaveth": "res://scenes/world/kaveth.tscn",
	"kaveth_vault": "res://scenes/world/kaveth_vault.tscn",
	"verath": "res://scenes/world/verath.tscn",
	"verath_seawall": "res://scenes/world/verath_seawall.tscn",
	"between": "res://scenes/world/between.tscn",
	"ashan": "res://scenes/world/ashan.tscn",
	"convergence_approach": "res://scenes/world/convergence_approach.tscn",
	"convergence": "res://scenes/world/convergence.tscn",
}

## Set before a transition; the arriving level places the player at the
## portal whose spawn_id matches, then clears it.
var pending_spawn_id: String = ""

var _fade: ColorRect
var _veil: ColorRect
var _busy := false

## Screen-space veil distortion: chromatic split + radial smear that pulses
## during portal transit — crossing the Veil should feel like the image
## itself tears slightly. `strength` is driven by the transit tweens.
const _VEIL_SHADER := "
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - vec2(0.5);
	float r = length(from_center);
	vec2 dir = r > 0.0001 ? from_center / r : vec2(0.0);
	float amt = strength * (0.004 + 0.012 * r);
	vec3 col;
	col.r = texture(screen_tex, uv + dir * amt).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * amt).b;
	COLOR = vec4(col, 1.0);
}
"

func _ready() -> void:
	layer = 100
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = _VEIL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_veil.material = mat
	_veil.visible = false
	add_child(_veil)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func _set_veil_strength(v: float) -> void:
	_veil.visible = v > 0.001
	(_veil.material as ShaderMaterial).set_shader_parameter("strength", v)

func level_scene_for(plane_id: String) -> String:
	return LEVELS.get(plane_id, LEVELS["tamori"])

## Fade out, switch to the plane's scene, arrive at target_spawn_id.
func change_level(plane_id: String, target_spawn_id: String = "") -> void:
	if _busy:
		return
	_busy = true
	pending_spawn_id = target_spawn_id
	var tween := create_tween()
	tween.tween_method(_set_veil_strength, 0.0, 1.0, 0.35)  # image tears as we cross
	tween.parallel().tween_property(_fade, "color:a", 1.0, 0.35)
	await tween.finished
	get_tree().change_scene_to_file(level_scene_for(plane_id))
	_busy = false
	# the arriving WayfarerLevel calls fade_in() at the end of its _ready

func fade_in() -> void:
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_method(_set_veil_strength, 1.0, 0.0, 0.35)  # ...and knits back
	tween.parallel().tween_property(_fade, "color:a", 0.0, 0.35)
