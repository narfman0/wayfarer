## Base for all world levels. Expects the standard level scene skeleton:
##   Level/Props, Characters/Sarro, Characters/Liris, CameraPivot, HUD,
##   optional Enemies and portals (group "portals").
## Subclass for level-specific behavior via _on_level_ready().
class_name WayfarerLevel
extends Node3D

const _Factory       = preload("res://scripts/characters/character_factory.gd")
const _MeleeAttacker = preload("res://scripts/combat/melee_attacker.gd")
const _SyntySkin     = preload("res://scripts/world/synty_skin.gd")
const _Animator      = preload("res://scripts/world/character_animator.gd")

## Key into SceneManager.LEVELS — also stored as GameState.current_plane.
@export var plane_id: String = "tamori"

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
	GameState.travel_to(plane_id)
	_setup_combat()
	_setup_enemies()
	_setup_animators()
	_apply_loaded_state()
	GameState.save_game()  # autosave on plane entry
	_on_level_ready()
	SceneManager.fade_in()

## Override for level-specific setup (opening dialogue, triggers, ...).
func _on_level_ready() -> void:
	_player.set_control_enabled(true)

## Colorize cooked Synty meshes with their pack atlases.
func _apply_synty_textures() -> void:
	_SyntySkin.apply_auto_children($Level/Props)
	for body in _bodies_with_skins():
		var skin = body.get_node_or_null("Skin")
		if skin != null:
			_SyntySkin.apply_auto(skin)

func _setup_animators() -> void:
	for body in _bodies_with_skins():
		var skin = body.get_node_or_null("Skin")
		if skin == null:
			continue
		var set_key := "femn" if body == _companion else "masc"
		_Animator.attach(skin, body, set_key)

func _bodies_with_skins() -> Array:
	var bodies: Array = [_player, _companion]
	bodies.append_array(get_tree().get_nodes_in_group("enemies"))
	return bodies

## Apply world state staged by GameState.load_game() or a portal transition.
func _apply_loaded_state() -> void:
	if GameState.pending_player_pos != null:
		_player.global_position = GameState.pending_player_pos
		GameState.pending_player_pos = null
	elif SceneManager.pending_spawn_id != "":
		for portal in get_tree().get_nodes_in_group("portals"):
			if portal.spawn_id == SceneManager.pending_spawn_id:
				_player.global_position = portal.spawn_position()
				_companion.global_position = portal.spawn_position() + Vector3(-1.2, 0, 1.2)
				break
		SceneManager.pending_spawn_id = ""

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
		ec.character = _Factory.make_enemy_char()
		ec.died.connect(_on_enemy_died.bind(ec))

func _check_player_targeting() -> void:
	var tgt = _player.target_enemy
	if tgt == null:
		return
	var ec = tgt if tgt != null and tgt.has_method("receive_damage") else null
	if ec == null:
		return
	if _hud != null:
		_hud.track_enemy(ec)
	var dist: float = _player.global_position.distance_to(ec.global_position)
	if dist <= 1.6:
		if not _attacker.is_attacking(ec):
			_attacker.start(ec)

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()

func _open_pause_menu() -> void:
	get_tree().paused = true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		add_child(pause_scene.instantiate())
