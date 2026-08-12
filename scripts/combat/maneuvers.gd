## Standard D&D maneuvers + class-flavor actives, resolved as contested
## checks (d20 + ability mod vs d20 + ability mod; ties go to the defender,
## per 5e). Bosses resist forced movement and holds outright — their fights
## are choreographed — but still show the RESISTED feedback.
class_name Maneuvers
extends RefCounted

const _Dice = preload("res://addons/srd/dice.gd")
const _DamageNumber = preload("res://scripts/world/damage_number.gd")
const _Vfx = preload("res://scripts/combat/vfx.gd")
const _Juice = preload("res://scripts/combat/juice.gd")

const SHOVE_CD := 6.0
const GRAPPLE_CD := 12.0
const FLAVOR_CD := 10.0
const SHOVE_PUSH := 7.0        # knockback impulse (decays at 18 m/s²)
const GRAPPLE_HOLD := 2.5      # seconds rooted
const TRIP_PRONE := 1.5        # seconds down

## Contested check: attacker's ability vs defender's. Ability indices match
## CharacterStats.ability_modifier (0 = STR, 1 = DEX, ...).
static func contest(a_char, d_char, a_ability := 0, d_ability := 0) -> bool:
	var a: int = _Dice.roll_d20() + (a_char.stats.ability_modifier(a_ability) if a_char != null and a_char.stats != null else 0)
	var d: int = _Dice.roll_d20() + (d_char.stats.ability_modifier(d_ability) if d_char != null and d_char.stats != null else 0)
	return a > d  # ties to the defender

## True if the target is boss-grade and shrugs off forced movement/holds.
static func resists(target: Node3D) -> bool:
	return target.get("is_boss") == true

static func feedback(scene: Node, pos: Vector3, text: String, color: Color) -> void:
	_DamageNumber.spawn(scene, pos + Vector3(0, 2.2, 0), text, color)

## Knock the target away from `from_pos`. Returns false on resist.
static func apply_shove(scene: Node, target: Node3D, from_pos: Vector3) -> bool:
	if resists(target):
		feedback(scene, target.global_position, "RESISTED", Color(0.8, 0.8, 0.85))
		return false
	var away := target.global_position - from_pos
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD
	target.set("_knockback", away.normalized() * SHOVE_PUSH)
	if target.has_method("stun"):
		target.stun(0.3)
	feedback(scene, target.global_position, "SHOVED", Color(1.0, 0.75, 0.35))
	_Juice.flash_light(scene, target.global_position, Color(1.0, 0.75, 0.35), 1.6, 0.2)
	return true
