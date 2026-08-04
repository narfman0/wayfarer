@tool
## Story beat marker — walk close, press F to resolve the beat: sets a story
## flag and grants quest XP, once ever (persisted via GameState flags).
## v1 stand-in for full dialogue scenes; a gold ring marks unresolved beats.
class_name StoryEvent
extends Node3D

@export var display_name: String = "Story Beat"
## Flag set when resolved; also the once-only guard.
@export var flag_name: String = ""
@export var xp_amount: int = 0
## Shown for a few seconds after resolving (one or two short lines).
@export_multiline var resolve_text: String = ""

var _player_near := false
var _prompt: Label3D
var _ring: MeshInstance3D

func _ready() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	_ring.mesh = torus
	_ring.position.y = 0.9
	_ring.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 1.8
	_ring.material_override = mat
	add_child(_ring)

	_prompt = Label3D.new()
	_prompt.position = Vector3(0, 2.4, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 44
	_prompt.pixel_size = 0.004
	_prompt.text = "[F] %s" % display_name
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

	if not Engine.is_editor_hint() and _is_resolved():
		_mark_spent()

func _is_resolved() -> bool:
	return flag_name != "" and GameState.has_flag(flag_name)

func _mark_spent() -> void:
	var mat := _ring.material_override as StandardMaterial3D
	mat.albedo_color = Color(0.4, 0.38, 0.32)
	mat.emission_energy_multiplier = 0.2
	_prompt.visible = false
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _player_near and event.is_action_pressed("interact") and not _is_resolved():
		_resolve()

func _resolve() -> void:
	if flag_name != "":
		GameState.set_flag(flag_name)
	if xp_amount > 0:
		GameState.grant_xp(xp_amount)
	GameState.save_game()
	_prompt.text = resolve_text if resolve_text != "" else "Something settles."
	_prompt.visible = true
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			_mark_spent())

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = true
		if not _is_resolved():
			_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = false
		if not _is_resolved() or _prompt.text.begins_with("[F]"):
			_prompt.visible = false
