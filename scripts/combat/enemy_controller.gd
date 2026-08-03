## Enemy AI: Patrol → Chase → Attack state machine, plus an archetype layer
## that changes the player's counterplay per enemy type:
##   bruiser    — walks up and swings (the original behavior)
##   skirmisher — kites to a range band and fires dodgeable projectiles
##   heavy      — melee plus a telegraphed AoE slam (step out of the circle)
## Archetype is derived from enemy_type (see _TYPE_ARCHETYPES) so existing
## scenes upgrade without edits; the export overrides per placement.
class_name EnemyController
extends CharacterBody3D

const _Dice           = preload("res://addons/srd/dice.gd")
const _CharacterStats = preload("res://addons/srd/resources/character_stats.gd")
const _DamageNumber   = preload("res://scripts/world/damage_number.gd")
const _MeleeAttacker  = preload("res://scripts/combat/melee_attacker.gd")
const _EquipPickup    = preload("res://scripts/world/equipment_pickup.gd")
const _WeaponData     = preload("res://addons/srd/resources/weapon_data.gd")
const _ArmorData      = preload("res://addons/srd/resources/armor_data.gd")
const _Telegraph      = preload("res://scripts/combat/telegraph.gd")
const _Projectile     = preload("res://scripts/combat/projectile.gd")
const _Juice          = preload("res://scripts/combat/juice.gd")

enum State { PATROL, CHASE, ATTACK }

const SPEED      := 3.0
const GRAVITY    := 9.8
const MELEE_DIST := 1.6   # metres — switch to Attack state
const CHASE_DIST := 12.0  # metres — give up chase beyond this

# Skirmisher: hold [RANGED_MIN, RANGED_MAX] and volley; retreat when crowded.
const RANGED_MIN  := 4.0
const RANGED_MAX  := 9.5
const RANGED_RATE := 2.2

# Heavy: telegraphed circle slam at the target's feet.
const SLAM_RANGE  := 5.0   # start the windup within this range
const SLAM_RADIUS := 2.4
const SLAM_WINDUP := 1.1   # telegraph duration — the dodge window
const SLAM_RATE   := 7.0   # cooldown between slams

const _PHASE_INVULN := 1.8  # seconds of invulnerability during phase transition

## Melee counterplay per enemy type. Anything unlisted is a bruiser.
const _TYPE_ARCHETYPES := {
	"brute": "heavy",
	"anchor_warden": "heavy",
	"extractor_guard": "skirmisher",
	"extractor_enforcer": "heavy",
	"kaveth_shade": "heavy",
	"dock_blade": "skirmisher",
	"veil_fragment": "skirmisher",
	"cael": "heavy",
}

@export var patrol_points: Array[NodePath] = []
@export var aggro_radius: float = 6.0
## XP granted to the party on kill.
@export var xp_value: int = 50
## Roster key for character_factory.make_enemy (bandit / brute / anchor_warden).
@export var enemy_type: String = "bandit"
## "auto" derives from enemy_type via _TYPE_ARCHETYPES.
@export_enum("auto", "bruiser", "skirmisher", "heavy") var archetype: String = "auto"
## Set true for the boss; enables phase transitions.
@export var is_boss: bool = false
## Equipment to drop on death: "greatsword", "longsword", "chain_mail", "scale_mail", or "".
@export var loot_preset: String = ""

## Filled by WayfarerCharacter factory in task 8. Nil = use defaults.
var character = null  # WayfarerCharacter

## Set by Liris's Guiding Bolt; consumed on the first hit this enemy takes.
var guiding_bolt_active: bool = false

var _state: State = State.PATROL
var _arch: String = "bruiser"
var _patrol_idx: int = 0
var _target: CharacterBody3D = null
var _attack_timer: float = 0.0
var _ranged_timer: float = 0.0
var _slam_timer: float = 2.5   # first slam lands shortly after combat starts
var _slam_winding: bool = false
var _knockback: Vector3 = Vector3.ZERO
var _dead: bool = false
var _phase: int = 0          # 0 = fresh, 1 = 60% threshold, 2 = 30% threshold
var _invuln_timer: float = 0.0

## Emitted when this enemy takes damage (hp_current, hp_max).
signal hp_changed(current: int, max_hp: int)
## Emitted when dead.
signal died
## Emitted when boss enters a new phase (1 = 60%, 2 = 30%).
signal phase_changed(phase: int)

func _ready() -> void:
	add_to_group("enemies")
	_arch = archetype if archetype != "auto" else str(_TYPE_ARCHETYPES.get(enemy_type, "bruiser"))
	var aggro_area := Area3D.new()
	var shape_node := CollisionShape3D.new()
	var sphere     := SphereShape3D.new()
	sphere.radius  = aggro_radius
	shape_node.shape = sphere
	aggro_area.add_child(shape_node)
	aggro_area.collision_layer = 0
	aggro_area.collision_mask  = 5  # detect player (1) and companion (4) layers
	add_child(aggro_area)
	aggro_area.body_entered.connect(_on_body_entered)
	aggro_area.body_exited.connect(_on_body_exited)

## Nearest living party member within chase range, or null.
func _acquire_target() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := CHASE_DIST
	var candidates: Array = get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("companions")
	for body in candidates:
		if not body is CharacterBody3D or not _is_alive(body):
			continue
		var d: float = global_position.distance_to(body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best

func _is_alive(body: Node) -> bool:
	var c = _char_for(body)
	return c != null and c.stats.current_hp > 0

## The WayfarerCharacter behind a party body.
func _char_for(body: Node):
	if body == null:
		return null
	if body.is_in_group("players"):
		return GameState.sarro
	if body.is_in_group("companions"):
		return GameState.liris
	return null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _invuln_timer > 0.0:
		_invuln_timer -= delta

	if _slam_winding:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		match _state:
			State.PATROL: _do_patrol(delta)
			State.CHASE:  _do_chase(delta)
			State.ATTACK: _do_attack(delta)
		if _arch == "heavy" and _state != State.PATROL:
			_tick_slam(delta)

	# Knockback rides on top of whatever the state set, then decays fast.
	velocity.x += _knockback.x
	velocity.z += _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)

	move_and_slide()

func _do_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity.x = 0.0; velocity.z = 0.0
		return
	var wp_node := get_node_or_null(patrol_points[_patrol_idx])
	if wp_node == null:
		return
	var to_wp: Vector3 = (wp_node as Node3D).global_position - global_position
	to_wp.y   = 0.0
	if to_wp.length() < 0.5:
		_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
		return
	var dir: Vector3 = to_wp.normalized()
	velocity.x = dir.x * SPEED * 0.6
	velocity.z = dir.z * SPEED * 0.6
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)

func _do_chase(delta: float) -> void:
	_target = _acquire_target()
	if _target == null:
		_state = State.PATROL; return
	if _arch == "skirmisher":
		_do_chase_skirmisher(delta)
		return
	var to_target := _target.global_position - global_position
	to_target.y   = 0.0
	var dist := to_target.length()
	if dist > CHASE_DIST:
		_state = State.PATROL; _target = null; return
	if dist <= MELEE_DIST:
		_state = State.ATTACK; velocity.x = 0.0; velocity.z = 0.0; return
	var dir    := to_target.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)

## Skirmisher chase: face the target, hold the range band, volley. Falls back
## to melee only when actually caught.
func _do_chase_skirmisher(delta: float) -> void:
	var to_target := _target.global_position - global_position
	to_target.y   = 0.0
	var dist := to_target.length()
	if dist > CHASE_DIST:
		_state = State.PATROL; _target = null; return
	var dir := to_target.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)

	if dist <= MELEE_DIST:
		_state = State.ATTACK; velocity.x = 0.0; velocity.z = 0.0; return
	elif dist < RANGED_MIN:      # crowded — back away, still firing
		velocity.x = -dir.x * SPEED * 0.8
		velocity.z = -dir.z * SPEED * 0.8
	elif dist <= RANGED_MAX:     # in the band — hold and fire
		velocity.x = 0.0
		velocity.z = 0.0
	else:                        # too far — close in
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED

	_ranged_timer -= delta
	if _ranged_timer <= 0.0 and dist <= RANGED_MAX and _invuln_timer <= 0.0:
		_ranged_timer = RANGED_RATE
		_fire_projectile()

func _do_attack(delta: float) -> void:
	_target = _acquire_target()
	if _target == null:
		_state = State.PATROL; return
	var dist := global_position.distance_to(_target.global_position)
	if dist > MELEE_DIST + 0.5:
		_state = State.CHASE; return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = 1.5
		if _invuln_timer <= 0.0:
			_fire_attack()

# ── Attack resolution (shared by melee, projectile, slam) ────────────────────

func _fire_attack() -> void:
	if character == null or _target == null:
		return
	_MeleeAttacker.lunge(self, _target.global_position)
	AudioManager.play_sfx("swing", -3.0)
	_resolve_attack_on(_target)

## SRD attack roll vs the party character behind `body`; applies damage.
func _resolve_attack_on(body: CharacterBody3D) -> void:
	if character == null:
		return
	var target_char = _char_for(body)
	if target_char == null:
		return

	var attacker = character.make_combatant()

	var d20: int       = _Dice.roll_d20()
	var atk_mod: int   = attacker.attack_modifier()
	var total_atk: int = d20 + atk_mod
	var target_ac: int = target_char.make_combatant().armor_class

	var hit: bool  = total_atk >= target_ac
	var crit: bool = d20 == 20
	var dmg  := 0

	if hit:
		dmg = attacker.roll_damage(crit)
		_apply_party_damage(target_char, body, dmg, crit)
	else:
		_DamageNumber.miss(get_tree().current_scene, body.global_position)

	var enemy_name: String = character.display_name
	var target_name: String = target_char.display_name
	if hit:
		print("[Combat] %s hits %s for %d (d20=%d+%d vs AC%d)" % [enemy_name, target_name, dmg, d20, atk_mod, target_ac])
	else:
		print("[Combat] %s misses %s (d20=%d+%d vs AC%d)" % [enemy_name, target_name, d20, atk_mod, target_ac])

## Damage + feedback for a party member taking a hit from this enemy.
func _apply_party_damage(target_char, body: Node3D, dmg: int, crit: bool) -> void:
	target_char.stats.current_hp = max(0, target_char.stats.current_hp - dmg)
	var scene := get_tree().current_scene
	AudioManager.play_sfx("crit" if crit else "hit", -2.0)
	_DamageNumber.hit(scene, body.global_position, dmg, crit)
	_Juice.impact_burst(scene, body.global_position, Color(1.0, 0.45, 0.3))
	if body.is_in_group("players"):
		_Juice.shake(get_viewport().get_camera_3d(), 0.09)
	if target_char.stats.current_hp <= 0 and target_char == GameState.liris:
		print("[Combat] Liris is down!")

# ── Skirmisher ────────────────────────────────────────────────────────────────

func _fire_projectile() -> void:
	if character == null or _target == null:
		return
	_MeleeAttacker.lunge(self, _target.global_position)
	AudioManager.play_sfx("swing", -4.0, 0.15)
	_Projectile.fire(get_tree().current_scene, global_position,
		_target.global_position, _on_projectile_hit)

func _on_projectile_hit(body: CharacterBody3D) -> void:
	if _dead or character == null:
		return
	_resolve_attack_on(body)

# ── Heavy slam ────────────────────────────────────────────────────────────────

func _tick_slam(delta: float) -> void:
	_slam_timer -= delta
	if _slam_timer > 0.0 or _invuln_timer > 0.0:
		return
	var tgt := _acquire_target()
	if tgt == null or global_position.distance_to(tgt.global_position) > SLAM_RANGE:
		return
	_slam_timer = SLAM_RATE
	_slam_winding = true
	var t = _Telegraph.show_circle(get_tree().current_scene,
		tgt.global_position, SLAM_RADIUS, SLAM_WINDUP)
	t.fired.connect(_on_slam_fired.bind(t))

## Fires on the telegraph the player watched fill — hit iff still inside it.
func _on_slam_fired(t) -> void:
	_slam_winding = false
	if _dead or character == null:
		return
	_MeleeAttacker.lunge(self, t.global_position)
	_Juice.shake(get_viewport().get_camera_3d(), 0.12)
	var attacker = character.make_combatant()
	var bodies: Array = get_tree().get_nodes_in_group("players") \
		+ get_tree().get_nodes_in_group("companions")
	for body in bodies:
		if not body is Node3D or not _is_alive(body):
			continue
		if not t.contains((body as Node3D).global_position):
			continue
		var target_char = _char_for(body)
		var dmg: int = attacker.roll_damage(false)
		_apply_party_damage(target_char, body, dmg, false)
		print("[Combat] %s's slam catches %s for %d" %
			[character.display_name, target_char.display_name, dmg])

# ── Damage intake / death ─────────────────────────────────────────────────────

func receive_damage(amount: int, from: Vector3 = Vector3.INF) -> void:
	if character == null or _invuln_timer > 0.0 or _dead:
		return
	guiding_bolt_active = false  # consumed on hit regardless of outcome
	character.stats.current_hp = max(0, character.stats.current_hp - amount)
	hp_changed.emit(character.stats.current_hp, character.stats.max_hp)
	_Juice.impact_burst(get_tree().current_scene, global_position)
	if from != Vector3.INF:
		var away := global_position - from
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_knockback = away.normalized() * 3.5
	if is_boss:
		_check_phase_transition()
	if character.stats.current_hp <= 0:
		_die()

## Corpse goes inert immediately (no group, no collision, no AI) so targeting,
## clicks, and further hits all pass over it — then Juice animates the
## send-off and frees the body.
func _die() -> void:
	_dead = true
	_slam_winding = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	GameState.grant_xp(xp_value)
	AudioManager.play_sfx("death")
	if loot_preset != "":
		_spawn_loot()
	died.emit()
	_Juice.death_collapse(self)

# ── Boss phases ───────────────────────────────────────────────────────────────

func _check_phase_transition() -> void:
	if character == null or character.stats.max_hp <= 0:
		return
	var pct := float(character.stats.current_hp) / float(character.stats.max_hp)
	if _phase == 0 and pct <= 0.6:
		_phase = 1
		_enter_phase(1)
	elif _phase == 1 and pct <= 0.3:
		_phase = 2
		_enter_phase(2)

func _enter_phase(phase: int) -> void:
	_invuln_timer = _PHASE_INVULN
	_state = State.PATROL  # brief retreat feel during transition
	character.stats.strength = mini(30, character.stats.strength + 3)
	character.stats.constitution = mini(30, character.stats.constitution + 2)
	_DamageNumber.spawn(get_tree().current_scene, global_position + Vector3(0, 2, 0),
		"Phase %d!" % phase, Color(1.0, 0.4, 0.15))
	phase_changed.emit(phase)
	print("[Boss] %s — phase %d!" % [character.display_name, phase])

# ── Loot ─────────────────────────────────────────────────────────────────────

func _spawn_loot() -> void:
	var pickup = _EquipPickup.new()
	pickup.position = global_position + Vector3(0, 0.5, 0)
	match loot_preset:
		"greatsword":
			pickup.slot = "main_hand"
			pickup.item = _WeaponData.make_greatsword()
		"longsword":
			pickup.slot = "main_hand"
			pickup.item = _WeaponData.make_longsword()
		"chain_mail":
			pickup.slot = "armor"
			pickup.item = _ArmorData.make_chain_mail()
		"scale_mail":
			pickup.slot = "armor"
			pickup.item = _ArmorData.make_scale_mail()
		_:
			return  # unknown preset — no drop
	get_tree().current_scene.add_child(pickup)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and _state == State.PATROL:
		_target = body as CharacterBody3D
		_state  = State.CHASE

func _on_body_exited(body: Node3D) -> void:
	if body == _target and _state != State.ATTACK:
		_target = null
		_state  = State.PATROL
