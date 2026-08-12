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
const _Vfx            = preload("res://scripts/combat/vfx.gd")

const MELEE_RANGE  := 1.6   # metres
const ATTACK_RATE  := 1.0   # seconds between attacks

## Contact-frame timing. Rolls happen at swing start; damage, sound, and
## numbers land when the blade visually connects. Player wind-ups stay snappy
## (<0.3s to contact) and the follow-through is cancelable into movement.
## Native contact sits ~40% into the clips (light 0.87s, heavy 2.10s); these
## speeds place it at WINDUP seconds.
const WINDUP     := {"attack": 0.18, "attack_heavy": 0.30}
const CLIP_SPEED := {"attack": 2.0, "attack_heavy": 3.0}
const RELEASE_FRAC := 0.65  # recovery cancels after 65% of the scaled clip

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
	# Heavy Strike: the primed swing hits harder, staggers, and swings the
	# heavy clip regardless of crit. Cooldown starts now.
	var heavy: bool = character.get("heavy_strike_primed") == true
	if heavy:
		character.heavy_strike_primed = false
		character.heavy_strike_cd = 8.0
	var target_name: String = _target.name  # capture before damage — a kill nulls _target via stop()

	# Swing now, land at the contact frame. The clip choice needs the roll
	# (crit → heavy), so rolls resolve up front and only the application —
	# damage, numbers, sound, stun — waits for the blade.
	var clip: String = "attack_heavy" if (crit or heavy) else "attack"
	_CharAnim.oneshot(owner_body, clip, CLIP_SPEED[clip], RELEASE_FRAC)
	lunge(owner_body, _target.global_position)
	_Vfx.slash_arc(owner_body.get_tree().current_scene, owner_body.global_position,
		_target.global_position,
		Color(1.0, 0.7, 0.3) if heavy else Color(1.0, 0.95, 0.8), crit or heavy)
	AudioManager.play_sfx("swing")

	var dmg := 0
	if hit:
		dmg = attacker.roll_damage(crit)
		if heavy:
			dmg += _Dice.roll(6) + _Dice.roll(6)
	var ev := {
		"heavy": heavy,
		"type": "attack",
		"attacker": character.display_name,
		"target": target_name,
		"d20": d20, "attack_mod": atk_mod, "target_ac": target_ac,
		"hit": hit, "crit": crit, "damage": dmg,
	}
	var tgt = _target  # capture — stop()/retarget may null _target mid-swing
	owner_body.get_tree().create_timer(WINDUP[clip]).timeout.connect(
		_land_attack.bind(tgt, ev))

## The contact frame: apply the pre-rolled result to the world. The target
## may have died, despawned, or been felled by Liris during the wind-up —
## in that case the swing whiffs silently.
func _land_attack(tgt, ev: Dictionary) -> void:
	if owner_body == null or not is_instance_valid(owner_body):
		return
	if tgt == null or not is_instance_valid(tgt) or tgt.character == null:
		return
	var scene: Node = owner_body.get_tree().current_scene
	var target_pos: Vector3 = tgt.global_position
	if ev["hit"]:
		if tgt.character.stats.current_hp <= 0:
			return  # already down — no double-kill feedback
		var dmg: int = ev["damage"]
		# Threshold Thief: +1d6 against staggered or casting targets —
		# judged at contact, when the opening actually exists.
		if character != null and character.subclass_key == "threshold_thief" \
				and (tgt.is_stunned() or tgt.is_casting()):
			dmg += _Dice.roll(6)
			ev["damage"] = dmg
		_DamageNumber.hit(scene, target_pos, dmg, ev["crit"])
		tgt.receive_damage(dmg, owner_body.global_position)
		# Sentinel (feat) and Heavy Strike both stagger on hit.
		if character != null and (_Progression.has_feat(character, "sentinel")
				or ev.get("heavy", false)):
			tgt.stun(0.4)
		AudioManager.play_sfx("crit" if ev["crit"] else "hit")
		_Juice.hit_stop(owner_body.get_tree(), 0.08 if ev["crit"] else 0.05)
		if ev["crit"]:
			_Juice.shake(owner_body.get_viewport().get_camera_3d(), 0.16)
	else:
		_DamageNumber.miss(scene, target_pos)
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
