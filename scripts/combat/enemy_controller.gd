## Enemy AI: Patrol → Chase → Attack state machine, plus an archetype layer
## that changes the player's counterplay per enemy type:
##   bruiser    — walks up and swings (the original behavior)
##   skirmisher — kites to a range band and fires dodgeable projectiles
##   heavy      — melee plus a telegraphed AoE slam (step out of the circle)
## Archetype is derived from enemy_type (see _TYPE_ARCHETYPES) so existing
## scenes upgrade without edits; the export overrides per placement.
class_name EnemyController
extends CharacterBody3D

const _CharAnim       = preload("res://scripts/world/character_animator.gd")
const _Dice           = preload("res://addons/srd/dice.gd")
const _CharacterStats = preload("res://addons/srd/resources/character_stats.gd")
const _DamageNumber   = preload("res://scripts/world/damage_number.gd")
const _MeleeAttacker  = preload("res://scripts/combat/melee_attacker.gd")
const _EquipPickup    = preload("res://scripts/world/equipment_pickup.gd")
const _LootBag        = preload("res://scripts/world/loot_bag.gd")
const _LootTable      = preload("res://scripts/items/loot_table.gd")
const _WeaponData     = preload("res://addons/srd/resources/weapon_data.gd")
const _ArmorData      = preload("res://addons/srd/resources/armor_data.gd")
const _Telegraph      = preload("res://scripts/combat/telegraph.gd")
const _Projectile     = preload("res://scripts/combat/projectile.gd")
const _Juice          = preload("res://scripts/combat/juice.gd")
const _Vfx            = preload("res://scripts/combat/vfx.gd")

enum State { PATROL, CHASE, ATTACK, RETURN }

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

## Basic-swing wind-up: the readable beat between the blade going up and
## damage landing. Deliberately ~3× the player's (contact-frame asymmetry:
## player attacks feel snappy, enemy attacks are reactable). Stepping out of
## reach dodges the blow; a stagger during the wind-up interrupts it. This
## window is also where boss ability/impact-area projection will hook in.
const MELEE_WINDUP := 0.5
const MELEE_CLIP_SPEED := 0.8   # slows the 0.87s light clip so contact ≈ wind-up

const _PHASE_INVULN := 1.8  # seconds of invulnerability during phase transition

# Support: hangs back and channels an interruptible group heal — creates the
# kill-order/interrupt decision. Assigned per-node via the archetype export
# (a type-wide mapping would make every zealot a healer).
const SUPPORT_MIN  := 4.0
const SUPPORT_MAX  := 8.0
const SUPPORT_PERIOD := 9.0
const SUPPORT_CAST := 3.0
const SUPPORT_RANGE := 10.0

## Melee counterplay per enemy type. Anything unlisted is a bruiser.
const _TYPE_ARCHETYPES := {
	"brute": "heavy",
	"anchor_warden": "heavy",
	"extractor_guard": "skirmisher",
	"extractor_enforcer": "heavy",
	"extractor_engine": "heavy",
	"kaveth_shade": "heavy",
	"dock_blade": "skirmisher",
	"veil_fragment": "skirmisher",
	"cael": "heavy",
	"skeleton_ranger": "skirmisher",
	"skeleton_armored": "heavy",
	"hunter": "heavy",
}

@export var patrol_points: Array[NodePath] = []
@export var aggro_radius: float = 6.0
## XP granted to the party on kill.
@export var xp_value: int = 50
## Roster key for character_factory.make_enemy (bandit / brute / anchor_warden).
@export var enemy_type: String = "bandit"
## "auto" derives from enemy_type via _TYPE_ARCHETYPES.
@export_enum("auto", "bruiser", "skirmisher", "heavy", "support") var archetype: String = "auto"
## Enemies sharing a non-empty pack_id aggro together: pulling one guard
## pulls the camp, so camp layouts matter.
@export var pack_id: String = ""
## Chase gives up beyond this radius FROM SPAWN (not from self) — the enemy
## walks home and heals to full, so camps are re-attemptable and can't be
## dragged apart one enemy at a time.
@export var leash_radius: float = 18.0
## Set true for the boss; enables phase transitions.
@export var is_boss: bool = false
## Equipment to drop on death: "greatsword", "longsword", "chain_mail", "scale_mail", or "".
@export var loot_preset: String = ""
## LootTable key to roll from on death ("bandit", "dungeon_basic", etc.; "" = no loot bag).
@export var loot_table_key: String = ""
## Seed for the loot roll. 0 = derived from world position at death time.
@export var loot_seed: int = 0

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
var _support_timer: float = 4.0   # first litany shortly after combat starts
var _slam_timer: float = 2.5   # first slam lands shortly after combat starts
var _slam_winding: bool = false
var _knockback: Vector3 = Vector3.ZERO
var _dead: bool = false
var _phase: int = 0          # 0 = fresh, 1 = 60% threshold, 2 = 30% threshold
var _invuln_timer: float = 0.0
var _spawn_pos: Vector3 = Vector3.ZERO
var _ambush_hidden := false

# Casting/channeling (A4 interrupt hook): while a cast runs the enemy stands
# still showing a bar; Shield Bash cancels it inside the window.
var _cast_label: String = ""
var _cast_left: float = 0.0
var _cast_total: float = 0.0
var _cast_bar: Label3D = null
var _stun_left: float = 0.0

## Emitted when this enemy takes damage (hp_current, hp_max).
signal hp_changed(current: int, max_hp: int)
## Emitted when dead.
signal died
## Emitted when boss enters a new phase (1 = 60%, 2 = 30%).
signal phase_changed(phase: int)
signal cast_finished(label: String)
signal cast_interrupted(label: String)

func _ready() -> void:
	add_to_group("enemies")
	_arch = archetype if archetype != "auto" else str(_TYPE_ARCHETYPES.get(enemy_type, "bruiser"))
	_spawn_pos = global_position
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
	var skin := get_node_or_null("Skin")
	if skin != null:
		var anim_set := "femn" if enemy_type in ["witch", "shade"] else "masc"
		_CharAnim.attach(skin, self, anim_set)

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

	if _stun_left > 0.0:
		_stun_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _cast_left > 0.0:
		_tick_cast(delta)
		velocity.x = 0.0
		velocity.z = 0.0
	elif _slam_winding:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		match _state:
			State.PATROL: _do_patrol(delta)
			State.CHASE:  _do_chase(delta)
			State.ATTACK: _do_attack(delta)
			State.RETURN: _do_return(delta)
		if _arch == "heavy" and (_state == State.CHASE or _state == State.ATTACK):
			_tick_slam(delta)

	# Knockback rides on top of whatever the state set, then decays fast.
	velocity.x += _knockback.x
	velocity.z += _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)

	move_and_slide()

## TB turn: move toward player, check OA, attack if in range, then end turn.
const OA_TRIGGER_RANGE := 2.0  # metres — proximity that grants OA opportunity

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
	if _leash_exceeded():
		_start_return(); return
	_target = _acquire_target()
	if _target == null:
		_state = State.PATROL; return
	if _arch == "skirmisher":
		_do_chase_skirmisher(delta)
		return
	if _arch == "support":
		_do_chase_support(delta)
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
	if _leash_exceeded():
		_start_return(); return
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
	_CharAnim.oneshot(self, "attack", MELEE_CLIP_SPEED, 0.8)
	_MeleeAttacker.lunge(self, _target.global_position)
	_Vfx.slash_arc(get_tree().current_scene, global_position,
		_target.global_position, Color(1.0, 0.55, 0.45))
	AudioManager.play_sfx("swing", -3.0)
	var tgt := _target
	get_tree().create_timer(MELEE_WINDUP).timeout.connect(_land_melee.bind(tgt))

## Contact frame of a basic swing. Interrupted by death or a stagger during
## the wind-up; whiffs (honestly, with a MISS) if the target stepped out of
## reach — that's the dodge.
func _land_melee(tgt: CharacterBody3D) -> void:
	if _dead or character == null or _stun_left > 0.0:
		return
	if tgt == null or not is_instance_valid(tgt):
		return
	if global_position.distance_to(tgt.global_position) > MELEE_DIST * 1.8:
		_DamageNumber.miss(get_tree().current_scene, tgt.global_position)
		print("[Combat] %s's swing whiffs — target moved" % character.display_name)
		return
	_resolve_attack_on(tgt)

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
	var crit: bool = d20 >= attacker.crit_threshold
	var dmg  := 0

	if hit:
		dmg = attacker.roll_damage(crit)
		_apply_party_damage(target_char, body, dmg, crit)
	else:
		_DamageNumber.miss(get_tree().current_scene, body.global_position)
		# Freeblade: a whiffed swing opens a riposte window.
		if target_char == GameState.sarro and GameState.sarro.subclass_key == "freeblade":
			GameState.sarro.riposte_until_ms = Time.get_ticks_msec() + 3000
			_DamageNumber.spawn(get_tree().current_scene,
				body.global_position + Vector3(0, 2.2, 0), "Riposte!", Color(1.0, 0.85, 0.4))

	var enemy_name: String = character.display_name
	var target_name: String = target_char.display_name
	if hit:
		print("[Combat] %s hits %s for %d (d20=%d+%d vs AC%d)" % [enemy_name, target_name, dmg, d20, atk_mod, target_ac])
	else:
		print("[Combat] %s misses %s (d20=%d+%d vs AC%d)" % [enemy_name, target_name, d20, atk_mod, target_ac])

## Damage + feedback for a party member taking a hit from this enemy.
func _apply_party_damage(target_char, body: Node3D, dmg: int, crit: bool) -> void:
	var near_sarro := false
	if target_char == GameState.liris:
		for p in get_tree().get_nodes_in_group("players"):
			if p is Node3D and body.global_position.distance_to((p as Node3D).global_position) <= 6.0:
				near_sarro = true
	dmg = CharacterProgression.modify_party_damage(dmg, target_char, "melee", crit, near_sarro)
	target_char.stats.current_hp = max(0, target_char.stats.current_hp - dmg)
	if target_char.stats.current_hp > 0:
		_CharAnim.oneshot(body, "hit", 1.5, 0.7)  # brisk flinch — combat stays fluid
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

# ── Support (Mending Litany) ──────────────────────────────────────────────────

## Support chase: hold a band behind the front line and channel the litany on
## a timer. The cast is interruptible — Shield Bash is the counterplay; the
## other answer is killing the healer first.
func _do_chase_support(delta: float) -> void:
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > CHASE_DIST:
		_state = State.PATROL; _target = null; return
	var dir := to_target.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)

	if dist < SUPPORT_MIN:        # crowded — back away
		velocity.x = -dir.x * SPEED * 0.8
		velocity.z = -dir.z * SPEED * 0.8
	elif dist <= SUPPORT_MAX:     # in the band — hold
		velocity.x = 0.0
		velocity.z = 0.0
	else:                         # keep up with the fight
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED

	_support_timer -= delta
	if _support_timer <= 0.0 and not is_casting() and _invuln_timer <= 0.0:
		_support_timer = SUPPORT_PERIOD
		start_cast("Mending Litany", SUPPORT_CAST)
		if not cast_finished.is_connected(_on_support_cast):
			cast_finished.connect(_on_support_cast)

func _on_support_cast(label: String) -> void:
	if label != "Mending Litany" or _dead or character == null:
		return
	var healed := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is EnemyController or e == self:
			continue
		var ec := e as EnemyController
		if ec.character == null or ec._dead:
			continue
		if global_position.distance_to(ec.global_position) > SUPPORT_RANGE:
			continue
		var amount: int = _Dice.roll(8) + _Dice.roll(8) + 4
		ec.character.stats.current_hp = mini(ec.character.stats.max_hp,
			ec.character.stats.current_hp + amount)
		ec.hp_changed.emit(ec.character.stats.current_hp, ec.character.stats.max_hp)
		_DamageNumber.spawn(get_tree().current_scene,
			ec.global_position + Vector3(0, 2.0, 0), "+%d" % amount, Color(0.5, 1.0, 0.6))
		healed += 1
	print("[Combat] %s's Mending Litany heals %d allies" % [character.display_name, healed])

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
	# Danger Sense (Between-Scout) stretches telegraphs aimed at the party.
	var t = _Telegraph.show_circle(get_tree().current_scene,
		tgt.global_position, SLAM_RADIUS,
		SLAM_WINDUP * CharacterProgression.telegraph_scale())
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

# ── Casting / channeling (A4) ─────────────────────────────────────────────────

## Begin a visible cast. The enemy roots in place showing a text bar; after
## `secs`, `cast_finished` fires — unless Shield Bash lands first, in which
## case `cast_interrupted` fires and the enemy eats a stun (the punish
## window). One cast at a time.
func start_cast(label: String, secs: float) -> void:
	if _dead or _cast_left > 0.0:
		return
	_cast_label = label
	_cast_total = maxf(0.1, secs)
	_cast_left = _cast_total
	_cast_bar = Label3D.new()
	_cast_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cast_bar.position = Vector3(0, 2.6, 0)
	_cast_bar.font_size = 40
	_cast_bar.pixel_size = 0.004
	_cast_bar.modulate = Color(1.0, 0.75, 0.3)
	add_child(_cast_bar)
	# Prayer-loop channel under the cast bar; a mid-cast hit react (stun /
	# Shield Bash) simply plays over it — the interruption reads itself.
	_CharAnim.oneshot(self, "cast_loop")
	AudioManager.play_sfx("telegraph", -4.0)

func is_casting() -> bool:
	return _cast_left > 0.0

func is_stunned() -> bool:
	return _stun_left > 0.0

## Cancel the current cast (Shield Bash). Applies the punish-window stun.
func interrupt_cast(stun_secs: float = 2.5) -> void:
	if _cast_left <= 0.0:
		return
	var label := _cast_label
	_end_cast()
	_stun_left = stun_secs
	cast_interrupted.emit(label)

func stun(secs: float) -> void:
	_stun_left = maxf(_stun_left, secs)

func _tick_cast(delta: float) -> void:
	_cast_left -= delta
	var frac := 1.0 - _cast_left / _cast_total
	if _cast_bar != null:
		var filled := int(round(frac * 10.0))
		_cast_bar.text = "%s\n%s%s" % [_cast_label,
			"▰".repeat(filled), "▱".repeat(10 - filled)]
	if _cast_left <= 0.0:
		var label := _cast_label
		_end_cast()
		cast_finished.emit(label)

func _end_cast() -> void:
	_cast_left = 0.0
	_cast_label = ""
	if _cast_bar != null:
		_cast_bar.queue_free()
		_cast_bar = null

# ── Damage intake / death ─────────────────────────────────────────────────────

func receive_damage(amount: int, from: Vector3 = Vector3.INF) -> void:
	if character == null or _invuln_timer > 0.0 or _dead:
		return
	guiding_bolt_active = false  # consumed on hit regardless of outcome
	character.stats.current_hp = max(0, character.stats.current_hp - amount)
	hp_changed.emit(character.stats.current_hp, character.stats.max_hp)
	if character.stats.current_hp > 0:
		_CharAnim.oneshot(self, "hit", 1.5, 0.7)  # brisk flinch — combat stays fluid
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
	_Vfx.death_dissolve(get_tree().current_scene, global_position)
	_slam_winding = false
	_end_cast()
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	GameState.grant_xp(xp_value)
	AudioManager.play_sfx("death")
	if loot_preset != "":
		_spawn_loot()
	if loot_table_key != "":
		_spawn_loot_bag()
	died.emit()
	# Real death animation where the clip loaded; the tween fall stays as
	# the fallback for skinless bodies (rigs, pillars).
	var animated := _CharAnim.oneshot(self, "death")
	_Juice.death_collapse(self, animated)

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

func _spawn_loot_bag() -> void:
	var bag: Area3D = _LootBag.new()
	bag.loot_table_key = loot_table_key
	bag.loot_seed      = loot_seed if loot_seed != 0 else hash(str(global_position))
	bag.position       = global_position + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3))
	get_tree().current_scene.add_child(bag)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and _state == State.PATROL and not _ambush_hidden:
		alerted(body as CharacterBody3D)
		_alert_pack(body as CharacterBody3D)

func _on_body_exited(body: Node3D) -> void:
	if body == _target and _state != State.ATTACK:
		_target = null
		_state  = State.PATROL

## Enter chase (from an aggro trigger, a packmate's call, or an ambush).
func alerted(body: CharacterBody3D) -> void:
	if _dead or _ambush_hidden or _state == State.CHASE or _state == State.ATTACK:
		return
	_target = body
	_state = State.CHASE
	# Gather all living combatants and hand off to CombatManager.
	if not CombatManager.in_combat:
		var combatants: Array = []
		for p in get_tree().get_nodes_in_group("players"):
			combatants.append(p)
		for e in get_tree().get_nodes_in_group("enemies"):
			combatants.append(e)
		CombatManager.enter_combat(combatants)

## Pulling one guard pulls everyone sharing this pack_id.
func _alert_pack(body: CharacterBody3D) -> void:
	if pack_id == "":
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is EnemyController and (e as EnemyController).pack_id == pack_id:
			(e as EnemyController).alerted(body)

# ── Leashing ──────────────────────────────────────────────────────────────────

func _leash_exceeded() -> bool:
	return global_position.distance_to(_spawn_pos) > leash_radius

func _start_return() -> void:
	_state = State.RETURN
	_target = null

## Walk home ignoring everything; heal to full on arrival. Prevents dragging
## a camp apart one enemy at a time and makes camps re-attemptable.
func _do_return(delta: float) -> void:
	var to_home := _spawn_pos - global_position
	to_home.y = 0.0
	if to_home.length() < 0.8:
		if character != null:
			character.stats.current_hp = character.stats.max_hp
			hp_changed.emit(character.stats.current_hp, character.stats.max_hp)
		_state = State.PATROL
		return
	var dir := to_home.normalized()
	velocity.x = dir.x * SPEED * 0.9
	velocity.z = dir.z * SPEED * 0.9
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)

# ── Ambush (used by AmbushTrigger) ────────────────────────────────────────────

## Vanish until an AmbushTrigger fires: invisible, unclickable, no AI. Stays
## in the "enemies" group so the level still assigns its character sheet.
func ambush_hide() -> void:
	_ambush_hidden = true
	visible = false
	collision_layer = 0
	set_physics_process(false)

func ambush_activate(body: CharacterBody3D) -> void:
	if not _ambush_hidden or _dead:
		return
	_ambush_hidden = false
	visible = true
	collision_layer = 2
	set_physics_process(true)
	_Juice.impact_burst(get_tree().current_scene, global_position, Color(0.7, 0.4, 1.0))
	AudioManager.play_sfx("telegraph", -2.0, 0.2)
	alerted(body)
	# Gatewatch (Vigilance): the ambush springs — into a prepared guard.
	if GameState.sarro != null and GameState.sarro.subclass_key == "gatewatch":
		stun(1.5)
