@tool
## Talkable villager. Walk close, press F (interact) to start dialogue.
## Dialogue conditions/mutations read and write GameState flags — see
## dialogue/village.dialogue for the pattern.
class_name VillageNPC
extends Node3D

const _Animator  = preload("res://scripts/world/character_animator.gd")

@export var npc_display_name: String = "Villager"
@export_file("*.dialogue") var dialogue_path: String = ""
@export var dialogue_title: String = ""
@export var talk_radius: float = 2.5
@export var feminine: bool = false
## Ambient one-liners shown when the player wanders close (used when there is
## no dialogue, or alongside it as flavor between conversations).
@export var bark_lines: Array[String] = []
## Idle stroll between these points (with a pause at each). Empty = stand
## still. This is what makes a plane read as lived-in rather than staged.
@export var wander_points: Array[NodePath] = []

const _WALK_SPEED := 1.1

var _wander_idx := 0
var _pause_left := 2.0

const BARK_COOLDOWN_MS := 9000

var _player_near := false
var _talking := false
var _prompt: Label3D
var _last_bark_ms := -BARK_COOLDOWN_MS

func _ready() -> void:
	var skin := get_node_or_null("Skin")
	if skin != null and not Engine.is_editor_hint():
		_Animator.attach(skin, null, "femn" if feminine else "masc")

	_prompt = preload("res://scripts/ui/screen_prompt.gd").new()
	_prompt.text = "[F] Talk to %s" % npc_display_name
	_prompt.position = Vector3(0, 2.2, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 48
	_prompt.pixel_size = 0.004
	_prompt.visible = false
	add_child(_prompt)

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = talk_radius
	shape.shape = sphere
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 1  # player layer
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return  # strolling in the editor would dirty saved positions
	if wander_points.is_empty() or _talking or _player_near:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	var wp := get_node_or_null(wander_points[_wander_idx])
	if wp == null:
		return
	var to_wp: Vector3 = (wp as Node3D).global_position - global_position
	to_wp.y = 0.0
	if to_wp.length() < 0.4:
		_wander_idx = (_wander_idx + 1) % wander_points.size()
		_pause_left = randf_range(2.5, 6.0)
		return
	var dir := to_wp.normalized()
	global_position += dir * _WALK_SPEED * delta
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _player_near and not _talking and event.is_action_pressed("interact"):
		_talk()

func _talk() -> void:
	if dialogue_path.is_empty():
		return
	var res := load(dialogue_path)
	if res == null:
		push_warning("NPC %s: missing dialogue %s" % [npc_display_name, dialogue_path])
		return
	_talking = true
	_prompt.visible = false
	var player = _get_player()  # PlayerController or null
	if player != null:
		player.set_control_enabled(false)
	DialogueManager.show_dialogue_balloon(res, dialogue_title)
	await DialogueManager.dialogue_ended
	if player != null:
		player.set_control_enabled(true)
	_talking = false
	_prompt.visible = _player_near

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = true
		if dialogue_path.is_empty() and bark_lines.size() > 0:
			_show_bark()
		else:
			_prompt.visible = not _talking

func _show_bark() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_bark_ms < BARK_COOLDOWN_MS:
		return
	_last_bark_ms = now
	_prompt.text = "%s: %s" % [npc_display_name, bark_lines.pick_random()]
	_prompt.visible = true
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(_prompt) and dialogue_path.is_empty():
		_prompt.visible = false

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = false
		_prompt.visible = false

func _get_player():
	var players := get_tree().get_nodes_in_group("players")
	return players[0] if players.size() > 0 else null
