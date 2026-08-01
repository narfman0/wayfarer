## Tamori — feudal Japanese-inspired plane. First area Sarro visits.
class_name TamoriScene
extends Node3D

@export var start_dialogue: String = "tamori_tavern"
## Set true in the editor to skip opening dialogue for movement/combat testing.
@export var skip_opening_dialogue: bool = false

const _Factory       = preload("res://scripts/characters/character_factory.gd")
const _MeleeAttacker = preload("res://scripts/combat/melee_attacker.gd")
const _SyntySkin     = preload("res://scripts/world/synty_skin.gd")


@onready var _player    = $Characters/Sarro     # PlayerController
@onready var _companion = $Characters/Liris     # CompanionFollow
@onready var _cam_pivot: Node3D = $CameraPivot
@onready var _hud_root:  Control = $HUD

var _hud = null       # HUD
var _attacker = null  # MeleeAttacker

func _ready() -> void:
	_player.camera_pivot = _cam_pivot
	_companion.follow_target = _player
	_apply_synty_textures()
	_setup_hud()
	_sync_party_to_scene()
	_setup_combat()
	_setup_enemies()
	_apply_loaded_state()
	GameState.save_game()  # autosave on plane entry
	if skip_opening_dialogue:
		_player.set_control_enabled(true)
	else:
		_start_opening_dialogue()

## Colorize cooked Synty meshes with their pack atlases.
func _apply_synty_textures() -> void:
	_SyntySkin.apply_auto_children($Level/Props)
	var bodies: Array = [$Characters/Sarro, $Characters/Liris]
	bodies.append_array(get_tree().get_nodes_in_group("enemies"))
	for body in bodies:
		var skin = body.get_node_or_null("Skin")
		if skin != null:
			_SyntySkin.apply_auto(skin)

## Apply world state staged by GameState.load_game().
func _apply_loaded_state() -> void:
	if GameState.pending_player_pos != null:
		_player.global_position = GameState.pending_player_pos
		GameState.pending_player_pos = null

func _process(_delta: float) -> void:
	_cam_pivot.global_position = _player.global_position
	_check_player_targeting()

func _setup_hud() -> void:
	var hud_scene := load("res://scenes/ui/hud.tscn")
	if hud_scene:
		_hud = hud_scene.instantiate()
		_hud_root.add_child(_hud)

func _setup_combat() -> void:
	_attacker = _MeleeAttacker.new()
	_attacker.owner_body = _player
	_attacker.character  = GameState.sarro  # party is synced before combat setup
	add_child(_attacker)

func _setup_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var ec = enemy if enemy.get_script() != null and enemy.has_method("receive_damage") else null
		if ec == null:
			continue
		# Give each enemy a default character for stat purposes
		ec.character = _make_enemy_char()
		ec.died.connect(_on_enemy_died.bind(ec))

func _make_enemy_char():
	return _Factory.make_enemy_char()

func _check_player_targeting() -> void:
	var tgt = _player.target_enemy
	if tgt == null:
		return
	var ec = tgt if tgt != null and tgt.has_method("receive_damage") else null
	if ec == null:
		return
	if _hud != null:
		_hud.track_enemy(ec)
	# Within melee range → start/continue attacking
	var dist: float = _player.global_position.distance_to(ec.global_position)
	if dist <= 1.6:
		if not _attacker.is_attacking(ec):
			_attacker.start(ec)
	# If player re-clicks elsewhere, attacker.stop() handled by PlayerController clearing target_enemy

func _on_enemy_died(ec) -> void:  # EnemyController
	if _attacker != null:
		_attacker.stop()
	_player.target_enemy = null
	if _hud != null:
		_hud.track_enemy(null)
	print("[Combat] Enemy defeated!")

func _sync_party_to_scene() -> void:
	if GameState.sarro == null:
		GameState.set_party(_Factory.make_sarro(), _Factory.make_liris())

func _start_opening_dialogue() -> void:
	_player.set_control_enabled(false)
	await get_tree().process_frame
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/tamori_tavern.dialogue"),
		start_dialogue
	)
	await DialogueManager.dialogue_ended
	_player.set_control_enabled(true)
	_on_opening_finished()

func _on_opening_finished() -> void:
	pass  # future: quest/flag updates after the opening scene

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()

func _open_pause_menu() -> void:
	get_tree().paused = true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		add_child(pause_scene.instantiate())
