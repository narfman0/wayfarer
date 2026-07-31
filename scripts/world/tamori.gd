## Tamori — feudal Japanese-inspired plane. First area Sarro visits.
class_name TamoriScene
extends Node3D

@export var start_dialogue: String = "tamori_tavern"
## Set true in the editor to skip opening dialogue for movement/combat testing.
@export var skip_opening_dialogue: bool = false

@onready var _player:    PlayerController = $Characters/Sarro
@onready var _companion: CompanionFollow  = $Characters/Liris
@onready var _cam_pivot: Node3D           = $CameraPivot
@onready var _hud_root:  Control          = $HUD

var _hud:      HUD = null
var _attacker: MeleeAttacker = null

func _ready() -> void:
	_player.camera_pivot = _cam_pivot
	_companion.follow_target = _player
	_setup_hud()
	_setup_combat()
	_setup_enemies()
	_sync_party_to_scene()
	if skip_opening_dialogue:
		_player.set_control_enabled(true)
	else:
		_start_opening_dialogue()

func _process(_delta: float) -> void:
	_cam_pivot.global_position = _player.global_position
	_check_player_targeting()

func _setup_hud() -> void:
	var hud_scene := load("res://scenes/ui/hud.tscn")
	if hud_scene:
		_hud = hud_scene.instantiate() as HUD
		_hud_root.add_child(_hud)

func _setup_combat() -> void:
	_attacker = MeleeAttacker.new()
	_attacker.owner_body = _player
	_attacker.character  = GameState.sarro if GameState.sarro != null else WayfarerCharacter.make_sarro()
	add_child(_attacker)

func _setup_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var ec := enemy as EnemyController
		if ec == null:
			continue
		# Give each enemy a default character for stat purposes
		ec.character = _make_enemy_char()
		ec.died.connect(_on_enemy_died.bind(ec))

func _make_enemy_char() -> WayfarerCharacter:
	var c := WayfarerCharacter.new()
	c.display_name = "Bandit"
	c.stats.character_name = "Bandit"
	c.stats.level = 1; c.stats.max_hp = 11; c.stats.armor_class = 12
	c.stats.strength = 12; c.stats.dexterity = 10; c.stats.constitution = 10
	c.stats.reset()
	var dagger := WeaponData.new()
	dagger.weapon_name = "Dagger"
	dagger.weapon_type = SRD.WeaponType.SIMPLE
	dagger.damage_type = SRD.DamageType.PIERCING
	dagger.die_count = 1; dagger.die_sides = 4
	c.equipment.equip_main_hand(dagger)
	c.setup()
	return c

func _check_player_targeting() -> void:
	var tgt := _player.target_enemy
	if tgt == null:
		return
	var ec := tgt as EnemyController
	if ec == null:
		return
	if _hud != null:
		_hud.track_enemy(ec)
	# Within melee range → start/continue attacking
	var dist := _player.global_position.distance_to(ec.global_position)
	if dist <= 1.6:
		if not _attacker.is_attacking(ec):
			_attacker.start(ec)
	# If player re-clicks elsewhere, attacker.stop() handled by PlayerController clearing target_enemy

func _on_enemy_died(ec: EnemyController) -> void:
	if _attacker != null:
		_attacker.stop()
	_player.target_enemy = null
	if _hud != null:
		_hud.track_enemy(null)
	print("[Combat] Enemy defeated!")

func _sync_party_to_scene() -> void:
	if GameState.sarro == null:
		GameState.set_party(WayfarerCharacter.make_sarro(), WayfarerCharacter.make_liris())

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
	GameState.save_game(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()

func _open_pause_menu() -> void:
	get_tree().paused = true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		add_child(pause_scene.instantiate())
