## Talkable villager. Walk close, press F (interact) to start dialogue.
## Dialogue conditions/mutations read and write GameState flags — see
## dialogue/village.dialogue for the pattern.
class_name VillageNPC
extends Node3D

const _SyntySkin = preload("res://scripts/world/synty_skin.gd")

@export var npc_display_name: String = "Villager"
@export_file("*.dialogue") var dialogue_path: String = ""
@export var dialogue_title: String = ""
@export var talk_radius: float = 2.5

var _player_near := false
var _talking := false
var _prompt: Label3D

func _ready() -> void:
	var skin := get_node_or_null("Skin")
	if skin != null:
		_SyntySkin.apply_auto(skin)

	_prompt = Label3D.new()
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

func _unhandled_input(event: InputEvent) -> void:
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
		_prompt.visible = not _talking

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = false
		_prompt.visible = false

func _get_player():
	var players := get_tree().get_nodes_in_group("players")
	return players[0] if players.size() > 0 else null
