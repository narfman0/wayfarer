## Veil portal — walk close, press F to travel. Optionally gated on a story
## flag; blocked portals show a hint instead of transporting.
class_name VeilPortal
extends Node3D

@export var display_name: String = "Veil Crossing"
## Identity for arrivals — SceneManager.pending_spawn_id matches against this.
@export var spawn_id: String = ""
## Key into SceneManager.LEVELS.
@export var target_plane: String = ""
## spawn_id of the portal to arrive at in the target level.
@export var target_spawn_id: String = ""
## Empty = always open. Otherwise requires GameState.has_flag(required_flag).
@export var required_flag: String = ""
@export var blocked_hint: String = "The way is shut."

var _player_near := false
var _prompt: Label3D

const _VeilTear = preload("res://scripts/world/veil_tear.gd")

func _ready() -> void:
	add_to_group("portals")

	var tear := _VeilTear.new()
	tear.color = Color(0.55, 0.35, 1.0)
	tear.ring_radius = 1.1
	tear.intensity = 1.0
	tear.position.y = 1.4
	add_child(tear)

	_prompt = Label3D.new()
	_prompt.position = Vector3(0, 2.9, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 48
	_prompt.pixel_size = 0.004
	_prompt.visible = false
	add_child(_prompt)

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	shape.shape = sphere
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

## Where arrivals should stand: just in front of the ring (its local -Z).
func spawn_position() -> Vector3:
	return global_position - global_transform.basis.z * 1.8

func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		_try_travel()

func _try_travel() -> void:
	if required_flag != "" and not GameState.has_flag(required_flag):
		_prompt.text = blocked_hint
		var timer := get_tree().create_timer(2.5)
		timer.timeout.connect(func():
			if is_instance_valid(_prompt) and _player_near:
				_prompt.text = _prompt_text())
		return
	AudioManager.play_sfx("portal")
	SceneManager.change_level(target_plane, target_spawn_id)

func _prompt_text() -> String:
	return "[F] %s" % display_name

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = true
		_prompt.text = _prompt_text()
		_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = false
		_prompt.visible = false
