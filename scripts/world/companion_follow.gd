## Companion AI — Liris follows Sarro at a fixed offset, and joins the fight
## when enemies come near, swinging with her own MeleeAttacker.
class_name CompanionFollow
extends CharacterBody3D

const SPEED       := 5.2  # slightly faster than player so she catches up
const STOP_DIST   := 1.6  # metres — personal space bubble
const GRAVITY     := 9.8
const ENGAGE_DIST := 7.0  # metres — join combat when an enemy is this close
const MELEE_DIST  := 1.5

const _Dice = preload("res://addons/srd/dice.gd")
const _DamageNumber = preload("res://scripts/world/damage_number.gd")
const _CharAnim = preload("res://scripts/world/character_animator.gd")

@export var follow_target: CharacterBody3D

## MeleeAttacker wired by the level (character = GameState.liris).
var attacker = null

var _down := false
var _heal_cooldown: float = 0.0

func _ready() -> void:
	var skin := get_node_or_null("Skin")
	if skin != null:
		_CharAnim.attach(skin, self, "femn")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _heal_cooldown > 0.0:
		_heal_cooldown -= delta

	var enemy = _nearest_enemy()
	if _update_down_state(enemy != null):
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)
	elif enemy != null:
		if _heal_cooldown <= 0.0:
			_try_auto_heal()
		_engage(enemy, delta)
	else:
		if _heal_cooldown <= 0.0:
			_try_auto_heal()
		if attacker != null:
			attacker.stop()
		_follow(delta)

	move_and_slide()

## Liris at 0 HP drops out of the fight; the Veil steadies her once combat
## ends and she gets back up at partial strength. Returns true while down.
func _update_down_state(in_combat: bool) -> bool:
	var c = GameState.liris
	if c == null:
		return false
	if not _down and c.stats.current_hp <= 0:
		_down = true
		if attacker != null:
			attacker.stop()
		var skin = get_node_or_null("Skin")
		if skin != null:
			skin.rotation.x = -PI / 2
	elif _down and not in_combat:
		_down = false
		c.stats.current_hp = maxi(1, c.stats.max_hp / 3)
		var skin = get_node_or_null("Skin")
		if skin != null:
			skin.rotation.x = 0.0
		print("[Combat] Liris gets back up.")
	return _down

## Auto-use Healing Word when Sarro is below 40% HP and charges remain.
func _try_auto_heal() -> void:
	var liris_char = GameState.liris
	var sarro_char = GameState.sarro
	if liris_char == null or sarro_char == null:
		return
	if liris_char.healing_word_charges <= 0:
		return
	if sarro_char.stats.max_hp <= 0:
		return
	var sarro_pct := float(sarro_char.stats.current_hp) / float(sarro_char.stats.max_hp)
	if sarro_pct < 0.4 and sarro_char.stats.current_hp > 0:
		_cast_healing_word(liris_char, sarro_char)

func _cast_healing_word(caster, target) -> void:
	caster.healing_word_charges -= 1
	_heal_cooldown = 10.0  # don't spam — 10s between auto-heals
	var heal: int = _Dice.roll(4) + caster.stats.ability_modifier(4)  # 4 = WIS
	heal = maxi(1, heal)
	target.stats.current_hp = mini(target.stats.max_hp, target.stats.current_hp + heal)
	# `target` is a character sheet (Resource) — read position off the body.
	var pos: Vector3 = follow_target.global_position if follow_target != null else global_position
	_DamageNumber.spawn(get_tree().current_scene, pos + Vector3(0, 1.5, 0),
		"+%d HW" % heal, Color(0.4, 1.0, 0.6))
	print("[Spell] Liris: Healing Word — %s +%d HP" % [target.display_name, heal])

func _engage(enemy: Node3D, delta: float) -> void:
	var to_enemy := enemy.global_position - global_position
	to_enemy.y = 0.0
	var dist := to_enemy.length()
	if dist > MELEE_DIST:
		var dir := to_enemy.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)
		if attacker != null and not attacker.is_attacking(enemy):
			attacker.start(enemy)

func _follow(delta: float) -> void:
	if follow_target == null:
		return
	var to_target := follow_target.global_position - global_position
	to_target.y   = 0.0
	var dist       := to_target.length()
	if dist > STOP_DIST:
		var dir := to_target.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)

func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := ENGAGE_DIST
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or not enemy.is_inside_tree():
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best
