## Base for all world levels. Expects the standard level scene skeleton:
##   Level/Props, Characters/Sarro, Characters/Liris, CameraPivot, HUD,
##   optional Enemies and portals (group "portals").
## Subclass for level-specific behavior via _on_level_ready().
class_name WayfarerLevel
extends Node3D

const _Factory       = preload("res://scripts/characters/character_factory.gd")
const _MeleeAttacker = preload("res://scripts/combat/melee_attacker.gd")
const _Animator      = preload("res://scripts/world/character_animator.gd")
const _DamageNumber  = preload("res://scripts/world/damage_number.gd")
const _Dice          = preload("res://addons/srd/dice.gd")
const _Experience    = preload("res://addons/srd/systems/experience.gd")

## Key into SceneManager.LEVELS — also stored as GameState.current_plane.
@export var plane_id: String = "tamori"

## When this scene is run in isolation (no party in GameState — e.g. "Run
## Current Scene" in the editor), the fallback debug party is boosted to this
## level so late-game planes are actually testable. Ignored in normal play.
@export_range(1, 20) var debug_party_level: int = 1

## True when this run spawned its own debug party — autosave is skipped so an
## isolated test never overwrites the real save slot.
var _debug_party := false

@onready var _player    = $Characters/Sarro     # PlayerController
@onready var _companion = $Characters/Liris     # CompanionFollow
@onready var _cam_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _hud_root:  Control = $HUD

var _hud = null       # HUD
var _attacker = null  # MeleeAttacker

# ── Dialogue camera ───────────────────────────────────────────────────────────
# The Camera3D sits aimed straight at the pivot origin, so scaling its local
# position toward that origin dollies in while staying framed. During dialogue
# we ease closer, swing the yaw for a 3/4 angle, and lift the focus to torso
# height; on dialogue end we ease everything back.
const _CAM_DIALOGUE_DOLLY := 0.6           # fraction of resting camera distance
const _CAM_DIALOGUE_YAW   := deg_to_rad(28.0)
const _CAM_DIALOGUE_FOCUS := Vector3(0.0, 1.1, 0.0)  # pivot lift toward the torso
const _CAM_BLEND_SECS      := 0.7
var _cam_rest_pos: Vector3 = Vector3.ZERO  # resting Camera3D local position
var _cam_focus: Vector3 = Vector3.ZERO     # extra pivot offset (dialogue framing)
var _cam_tween: Tween = null

## Actions queued during pause; fired on resume.
var _queued_sarro: String = ""
var _queued_liris: String = ""

func _ready() -> void:
	_player.camera_pivot = _cam_pivot
	_companion.follow_target = _player
	_cam_rest_pos = _camera.position
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_setup_hud()
	_sync_party_to_scene()
	GameState.travel_to(plane_id)
	_setup_combat()
	_setup_enemies()
	_setup_prop_collision()
	_setup_animators()
	_apply_loaded_state()
	if not _debug_party:
		GameState.save_game()  # autosave on plane entry
	_on_level_ready()
	SceneManager.fade_in()

## Override for level-specific setup (opening dialogue, triggers, ...).
func _on_level_ready() -> void:
	_player.set_control_enabled(true)

## World props ship as Synty GLTFs with no collision. Generate a trimesh
## collider per prop mesh at load so the player can't walk through them.
##
## Colliders go on a dedicated layer (not the ground/enemy layers), and the
## player is told to collide with it — but click-to-move's raycast (CLICK_MASK
## = ground + enemies) deliberately omits this layer, so clicking past a prop
## still targets the ground instead of stopping on the prop's surface.
##
## Trimesh (not a box) matters for tall props: the player capsule tops out at
## 1.8 m, so a tree only blocks at its trunk while its canopy — and any box
## drawn around it — would otherwise wall off the ground around it.
const _PROP_LAYER := 1 << 3  # value 8; unused by ground(1)/enemies(2)/companion(4)

func _setup_prop_collision() -> void:
	var props := get_node_or_null("Level/Props")
	if props == null:
		return
	for mi: MeshInstance3D in props.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		mi.create_trimesh_collision()
		var body := _generated_static_body(mi)
		if body != null:
			body.collision_layer = _PROP_LAYER
			body.collision_mask = 0
	_player.collision_mask |= _PROP_LAYER

## The StaticBody3D that create_trimesh_collision() just parented under `mi`
## (Synty prop meshes carry no collision of their own, so it's the only one).
func _generated_static_body(mi: Node) -> StaticBody3D:
	for i in range(mi.get_child_count() - 1, -1, -1):
		if mi.get_child(i) is StaticBody3D:
			return mi.get_child(i)
	return null

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

var _defeated := false

func _process(_delta: float) -> void:
	_cam_pivot.global_position = _player.global_position + _cam_focus
	_check_player_targeting()
	if not _defeated and GameState.sarro != null and GameState.sarro.stats.current_hp <= 0:
		_on_party_defeated()

## Sarro at 0 HP: the Veil pulls the party back to the last stable tear.
func _on_party_defeated() -> void:
	_defeated = true
	_player.set_control_enabled(false)
	if _attacker != null:
		_attacker.stop()
	print("[Combat] The Veil pulls you back...")
	GameState.sarro.stats.current_hp = GameState.sarro.stats.max_hp
	if GameState.liris != null:
		GameState.liris.stats.current_hp = GameState.liris.stats.max_hp
	GameState.pending_player_pos = null
	SceneManager.change_level(plane_id)

## Ease the camera into the closer, angled conversation framing.
func _on_dialogue_started(_resource) -> void:
	_blend_camera(_cam_rest_pos * _CAM_DIALOGUE_DOLLY, _CAM_DIALOGUE_YAW, _CAM_DIALOGUE_FOCUS)

## Ease the camera back to the resting gameplay framing.
func _on_dialogue_ended(_resource) -> void:
	_blend_camera(_cam_rest_pos, 0.0, Vector3.ZERO)

func _blend_camera(cam_pos: Vector3, pivot_yaw: float, focus: Vector3) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_camera, "position", cam_pos, _CAM_BLEND_SECS)
	_cam_tween.tween_property(_cam_pivot, "rotation:y", pivot_yaw, _CAM_BLEND_SECS)
	_cam_tween.tween_property(self, "_cam_focus", focus, _CAM_BLEND_SECS)

func _setup_hud() -> void:
	var hud_scene := load("res://scenes/ui/hud.tscn")
	if hud_scene:
		_hud = hud_scene.instantiate()
		_hud_root.add_child(_hud)

func _setup_combat() -> void:
	_attacker = _MeleeAttacker.new()
	_attacker.owner_body = _player
	_attacker.character  = GameState.sarro
	add_child(_attacker)
	var liris_attacker = _MeleeAttacker.new()
	liris_attacker.owner_body = _companion
	liris_attacker.character  = GameState.liris
	add_child(liris_attacker)
	_companion.attacker = liris_attacker

func _setup_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var ec = enemy if enemy.get_script() != null and enemy.has_method("receive_damage") else null
		if ec == null:
			continue
		ec.character = _Factory.make_enemy(ec.enemy_type)
		ec.died.connect(_on_enemy_died.bind(ec))
		if ec.is_boss:
			ec.phase_changed.connect(_on_boss_phase.bind(ec))

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

func _on_enemy_died(ec) -> void:
	if _attacker != null:
		_attacker.stop()
	_player.target_enemy = null
	if _hud != null:
		_hud.track_enemy(null)
	print("[Combat] Enemy defeated!")

func _on_boss_phase(phase: int, _ec) -> void:
	if _hud != null:
		_hud.show_boss_phase(phase)

func _sync_party_to_scene() -> void:
	if GameState.sarro == null:
		_debug_party = true
		GameState.debug_session = true
		GameState.set_party(_Factory.make_sarro(), _Factory.make_liris())
		if debug_party_level > 1:
			GameState.grant_xp(_Experience.xp_for_level(debug_party_level))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()
	elif event.is_action_pressed("ability_1"):
		_use_second_wind()
	elif event.is_action_pressed("ability_2"):
		_use_guiding_bolt()
	elif event.is_action_pressed("ability_3"):
		_use_healing_word()
	elif event.is_action_pressed("ability_4"):
		_use_channel_divinity()

# ── Sarro Abilities ───────────────────────────────────────────────────────────

## [1] Second Wind: heal 1d10 + level, once per rest.
func _use_second_wind() -> void:
	var c = GameState.sarro
	if c == null or c.second_wind_used or _defeated:
		return
	if c.stats.current_hp >= c.stats.max_hp or c.stats.current_hp <= 0:
		return
	c.second_wind_used = true
	var heal: int = _Dice.roll(10) + c.stats.level
	c.stats.current_hp = mini(c.stats.max_hp, c.stats.current_hp + heal)
	_DamageNumber.spawn(self, _player.global_position, "+%d" % heal, Color(0.4, 1.0, 0.5))
	print("[Combat] Second Wind: +%d HP" % heal)

# ── Liris Abilities ───────────────────────────────────────────────────────────

## [2] Guiding Bolt: mark the current target so the next attack hits with advantage.
func _use_guiding_bolt() -> void:
	var c = GameState.liris
	if c == null or not c.guiding_bolt_ready or _defeated:
		return
	var tgt = _player.target_enemy
	if tgt == null or not tgt.has_method("receive_damage"):
		return
	c.guiding_bolt_ready = false
	tgt.guiding_bolt_active = true
	_DamageNumber.spawn(self, tgt.global_position + Vector3(0, 1.5, 0),
		"Guiding Bolt!", Color(0.95, 0.85, 0.3))
	print("[Spell] Liris: Guiding Bolt on %s" % tgt.name)

## [3] Healing Word: heal Sarro for 1d4 + WIS mod (short-rest charge).
func _use_healing_word() -> void:
	var c = GameState.liris
	var sarro = GameState.sarro
	if c == null or sarro == null or c.healing_word_charges <= 0 or _defeated:
		return
	if sarro.stats.current_hp <= 0:
		return
	c.healing_word_charges -= 1
	var heal: int = maxi(1, _Dice.roll(4) + c.stats.ability_modifier(4))  # 4 = WIS
	sarro.stats.current_hp = mini(sarro.stats.max_hp, sarro.stats.current_hp + heal)
	_DamageNumber.spawn(self, _player.global_position + Vector3(0, 1.5, 0),
		"+%d HW" % heal, Color(0.4, 1.0, 0.5))
	print("[Spell] Liris: Healing Word — Sarro +%d HP" % heal)

## [4] Channel Divinity — Sacred Flame burst on all enemies within 8 m of Liris.
## DEX save (DC = 8 + WIS mod + proficiency) or take 1d8 radiant.
func _use_channel_divinity() -> void:
	var c = GameState.liris
	if c == null or not c.channel_divinity_ready or _defeated:
		return
	c.channel_divinity_ready = false
	var dc: int = 8 + c.stats.ability_modifier(4) + c.stats.proficiency_bonus()
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or not enemy.has_method("receive_damage"):
			continue
		var dist: float = _companion.global_position.distance_to(enemy.global_position)
		if dist > 8.0:
			continue
		var save_roll: int = _Dice.roll_d20()
		if enemy.character != null:
			save_roll += enemy.character.stats.ability_modifier(1)  # 1 = DEX
		if save_roll < dc:
			var dmg: int = _Dice.roll(8)
			enemy.receive_damage(dmg)
			_DamageNumber.hit(self, enemy.global_position, dmg, false)
			hit_count += 1
	_DamageNumber.spawn(self, _companion.global_position + Vector3(0, 2.0, 0),
		"Sacred Flame ×%d" % hit_count, Color(0.95, 0.85, 0.3))
	print("[Spell] Liris: Channel Divinity — %d enemies hit (DC %d)" % [hit_count, dc])

# ── Pause / queue ─────────────────────────────────────────────────────────────

func _open_pause_menu() -> void:
	get_tree().paused = true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		var pm = pause_scene.instantiate()
		pm.queued.connect(_on_actions_queued)
		add_child(pm)

func _on_actions_queued(sarro_action: String, liris_action: String) -> void:
	_queued_sarro = sarro_action
	_queued_liris = liris_action
	_execute_queued_actions()

func _execute_queued_actions() -> void:
	match _queued_sarro:
		"ability_1": _use_second_wind()
	_queued_sarro = ""
	match _queued_liris:
		"ability_2": _use_guiding_bolt()
		"ability_3": _use_healing_word()
		"ability_4": _use_channel_divinity()
	_queued_liris = ""
