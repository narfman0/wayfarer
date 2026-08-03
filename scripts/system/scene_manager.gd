## Autoload — level transitions with fade, portal spawn staging, and the
## plane-id → scene registry.
extends CanvasLayer

const LEVELS := {
	"tamori": "res://scenes/world/tamori.tscn",
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
	"convergence": "res://scenes/world/convergence.tscn",
}

## Set before a transition; the arriving level places the player at the
## portal whose spawn_id matches, then clears it.
var pending_spawn_id: String = ""

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func level_scene_for(plane_id: String) -> String:
	return LEVELS.get(plane_id, LEVELS["tamori"])

## Fade out, switch to the plane's scene, arrive at target_spawn_id.
func change_level(plane_id: String, target_spawn_id: String = "") -> void:
	if _busy:
		return
	_busy = true
	pending_spawn_id = target_spawn_id
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	await tween.finished
	get_tree().change_scene_to_file(level_scene_for(plane_id))
	_busy = false
	# the arriving WayfarerLevel calls fade_in() at the end of its _ready

func fade_in() -> void:
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.35)
