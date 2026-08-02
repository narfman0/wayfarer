## Drives Sarro's melee attack loop against a targeted enemy.
## Attach to the same node as PlayerController, or instantiate from TamoriScene.
class_name MeleeAttacker
extends Node

const _Dice           = preload("res://addons/srd/dice.gd")
const _CharacterStats = preload("res://addons/srd/resources/character_stats.gd")
const _Combatant      = preload("res://addons/srd/systems/combatant.gd")
const _ArmorData      = preload("res://addons/srd/resources/armor_data.gd")
const _DamageNumber   = preload("res://scripts/world/damage_number.gd")

const MELEE_RANGE  := 1.6   # metres
const ATTACK_RATE  := 1.0   # seconds between attacks

var owner_body: CharacterBody3D = null
var character = null   # WayfarerCharacter

var _timer: float = 0.0
var _active: bool = false
var _target = null  # EnemyController

signal attack_result(event: Dictionary)

func start(target) -> void:  # target: EnemyController
	_target = target
	_active = true
	_timer  = 0.0  # fire immediately on first tick

func stop() -> void:
	_active = false
	_target = null

func is_attacking(enemy) -> bool:  # enemy: EnemyController
	return _active and _target == enemy

func _process(delta: float) -> void:
	if not _active or _target == null or owner_body == null:
		return
	if _target.character == null or _target.character.stats.current_hp <= 0:
		stop(); return

	var dist := owner_body.global_position.distance_to(_target.global_position)
	if dist > MELEE_RANGE:
		return  # PlayerController is still moving us into range

	_timer -= delta
	if _timer <= 0.0:
		_timer = ATTACK_RATE
		_do_attack()

func _do_attack() -> void:
	if character == null or _target == null:
		return

	var attacker = character.make_combatant()
	var defender = _target.character.make_combatant() if _target.character != null else _make_default_enemy_combatant()

	# Advantage from Guiding Bolt: roll 2d20 take higher.
	var advantage: bool = _target.get("guiding_bolt_active") == true
	var d20: int
	if advantage:
		d20 = maxi(_Dice.roll_d20(), _Dice.roll_d20())
		_target.guiding_bolt_active = false
	else:
		d20 = _Dice.roll_d20()
	var atk_mod: int   = attacker.attack_modifier()
	var total_atk: int = d20 + atk_mod
	var target_ac: int = defender.armor_class

	var hit: bool  = total_atk >= target_ac
	var crit: bool = d20 == 20
	var target_name: String = _target.name  # capture before damage — a kill nulls _target via stop()

	var target_pos: Vector3 = _target.global_position
	lunge(owner_body, target_pos)
	var dmg := 0
	if hit:
		dmg = attacker.roll_damage(crit)
		_DamageNumber.hit(owner_body.get_tree().current_scene, target_pos, dmg, crit)
		_target.receive_damage(dmg)
	else:
		_DamageNumber.miss(owner_body.get_tree().current_scene, target_pos)

	var ev := {
		"type": "attack",
		"attacker": character.display_name,
		"target": target_name,
		"d20": d20, "attack_mod": atk_mod, "target_ac": target_ac,
		"hit": hit, "crit": crit, "damage": dmg,
	}
	attack_result.emit(ev)
	print("[Combat] ", _format(ev))

## Procedural attack swing: dart the body's Skin toward the target and back.
## (No combat clips in the animation pack yet — this sells the hit at
## isometric zoom.)
static func lunge(body: Node3D, toward: Vector3) -> void:
	var skin = body.get_node_or_null("Skin")
	if skin == null:
		return
	var dir: Vector3 = (toward - body.global_position)
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var local_dir: Vector3 = body.global_transform.basis.inverse() * dir.normalized()
	var tween := skin.create_tween()
	tween.tween_property(skin, "position", local_dir * 0.4, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(skin, "position", Vector3.ZERO, 0.18).set_ease(Tween.EASE_IN_OUT)

func _make_default_enemy_combatant():
	var stats = _CharacterStats.new()
	stats.max_hp = 11; stats.current_hp = 11
	stats.strength = 12; stats.dexterity = 10; stats.constitution = 10
	var combatant = _Combatant.new(stats, null, null)
	combatant.equipment.equip_armor(_ArmorData.make_studded_leather())
	return combatant

func _format(ev: Dictionary) -> String:
	if ev.get("crit"):
		return "%s CRITS %s for %d!" % [ev["attacker"], ev["target"], ev["damage"]]
	if ev.get("hit"):
		return "%s hits %s for %d (d20=%d+%d vs AC%d)" % [
			ev["attacker"], ev["target"], ev["damage"],
			ev["d20"], ev["attack_mod"], ev["target_ac"]]
	return "%s misses %s (d20=%d+%d vs AC%d)" % [
		ev["attacker"], ev["target"], ev["d20"], ev["attack_mod"], ev["target_ac"]]
