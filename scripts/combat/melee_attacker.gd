## Drives Sarro's melee attack loop against a targeted enemy.
## Attach to the same node as PlayerController, or instantiate from TamoriScene.
class_name MeleeAttacker
extends Node

const MELEE_RANGE  := 1.6   # metres
const ATTACK_RATE  := 1.0   # seconds between attacks

var owner_body: CharacterBody3D = null
var character:  WayfarerCharacter = null

var _timer: float = 0.0
var _active: bool = false
var _target: EnemyController = null

signal attack_result(event: Dictionary)

func start(target: EnemyController) -> void:
	_target = target
	_active = true
	_timer  = 0.0  # fire immediately on first tick

func stop() -> void:
	_active = false
	_target = null

func is_attacking(enemy: EnemyController) -> bool:
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

	var attacker := character.make_combatant()
	var defender := _target.character.make_combatant() if _target.character != null else _make_default_enemy_combatant()

	# SRD attack roll
	var d20       := Dice.roll_d20()
	var atk_mod   := attacker.attack_modifier()
	var total_atk := d20 + atk_mod
	var target_ac := defender.stats.armor_class

	var hit  := total_atk >= target_ac
	var crit := d20 == 20

	var dmg := 0
	if hit:
		dmg = attacker.roll_damage(crit)
		_target.receive_damage(dmg)

	var ev := {
		"type": "attack",
		"attacker": character.display_name,
		"target": _target.name,
		"d20": d20, "attack_mod": atk_mod, "target_ac": target_ac,
		"hit": hit, "crit": crit, "damage": dmg,
	}
	attack_result.emit(ev)
	print("[Combat] ", _format(ev))

func _make_default_enemy_combatant() -> Combatant:
	var stats := CharacterStats.new()
	stats.armor_class = 12; stats.max_hp = 11; stats.current_hp = 11
	stats.strength = 12; stats.dexterity = 10; stats.constitution = 10
	return Combatant.new(stats, null, null)

func _format(ev: Dictionary) -> String:
	if ev.get("crit"):
		return "%s CRITS %s for %d!" % [ev["attacker"], ev["target"], ev["damage"]]
	if ev.get("hit"):
		return "%s hits %s for %d (d20=%d+%d vs AC%d)" % [
			ev["attacker"], ev["target"], ev["damage"],
			ev["d20"], ev["attack_mod"], ev["target_ac"]]
	return "%s misses %s (d20=%d+%d vs AC%d)" % [
		ev["attacker"], ev["target"], ev["d20"], ev["attack_mod"], ev["target_ac"]]
