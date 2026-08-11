## Drives Sarro's melee attack loop against a targeted enemy.
## Attach to the same node as PlayerController, or instantiate from TamoriScene.
class_name MeleeAttacker
extends Node

const _Dice           = preload("res://addons/srd/dice.gd")
const _CharacterStats = preload("res://addons/srd/resources/character_stats.gd")
const _Combatant      = preload("res://addons/srd/systems/combatant.gd")
const _ArmorData      = preload("res://addons/srd/resources/armor_data.gd")
const _DamageNumber   = preload("res://scripts/world/damage_number.gd")
const _Juice          = preload("res://scripts/combat/juice.gd")
const _Progression    = preload("res://scripts/characters/character_progression.gd")
const _CharAnim       = preload("res://scripts/world/character_animator.gd")

const MELEE_RANGE  := 1.6   # metres
const ATTACK_RATE  := 1.0   # seconds between attacks

## Attack-interval multiplier — Action Surge sets this below 1.0 briefly.
var rate_scale: float = 1.0

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

## One-shot attack roll against target (used for opportunity attacks, etc.)
## Does not affect the ongoing attack loop.
func fire_once(target) -> void:
	var saved = _target
	var saved_active := _active
	_target = target
	_do_attack()
	_target = saved
	_active = saved_active

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
		_timer = ATTACK_RATE * rate_scale
		_do_attack()

func _do_attack() -> void:
	if character == null or _target == null:
		return

	var attacker = character.make_combatant()
	var defender = _target.character.make_combatant() if _target.character != null else _make_default_enemy_combatant()

	# Advantage: Guiding Bolt mark, or the Freeblade riposte window an
	# enemy's miss just opened. Roll 2d20 take higher.
	var advantage: bool = _target.get("guiding_bolt_active") == true
	if character.riposte_until_ms > 0 and Time.get_ticks_msec() < character.riposte_until_ms:
		advantage = true
		character.riposte_until_ms = 0
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
	# Lucky (feat): the Veil nudges a miss into a second roll.
	if not hit and character.lucky_points > 0:
		character.lucky_points -= 1
		d20 = _Dice.roll_d20()
		total_atk = d20 + atk_mod
		hit = total_atk >= target_ac
		_DamageNumber.spawn(owner_body.get_tree().current_scene,
			_target.global_position + Vector3(0, 2.2, 0), "Lucky!", Color(0.5, 0.9, 1.0))
	var crit: bool = d20 >= attacker.crit_threshold
	var target_name: String = _target.name  # capture before damage — a kill nulls _target via stop()

	var target_pos: Vector3 = _target.global_position
	# Real sword swing where a clip exists; the procedural lunge stays as a
	# readability accent underneath it.
	_CharAnim.oneshot(owner_body, "attack_heavy" if crit else "attack")
	lunge(owner_body, target_pos)
	var dmg := 0
	AudioManager.play_sfx("swing")
	if hit:
		dmg = attacker.roll_damage(crit)
		# Threshold Thief: +1d6 against staggered or casting targets.
		if character.subclass_key == "threshold_thief" \
				and (_target.is_stunned() or _target.is_casting()):
			dmg += _Dice.roll(6)
		_DamageNumber.hit(owner_body.get_tree().current_scene, target_pos, dmg, crit)
		_target.receive_damage(dmg, owner_body.global_position)
		# Sentinel (feat): every landed hit staggers for a beat.
		if _Progression.has_feat(character, "sentinel"):
			_target.stun(0.4)
		AudioManager.play_sfx("crit" if crit else "hit")
		_Juice.hit_stop(owner_body.get_tree(), 0.08 if crit else 0.05)
		if crit:
			_Juice.shake(owner_body.get_viewport().get_camera_3d(), 0.16)
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
