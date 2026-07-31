## Placeholder enemy — simple 3-state machine: Patrol → Chase → Attack.
## No Beehave yet. Wired to SRD Combatant in task 8.
class_name EnemyController
extends CharacterBody3D

const _Dice           = preload("res://vendor/godot-srd-addon/addons/srd/dice.gd")
const _CharacterStats = preload("res://vendor/godot-srd-addon/addons/srd/resources/character_stats.gd")

enum State { PATROL, CHASE, ATTACK }

const SPEED      := 3.0
const GRAVITY    := 9.8
const MELEE_DIST := 1.6   # metres — switch to Attack state
const CHASE_DIST := 12.0  # metres — give up chase beyond this

@export var patrol_points: Array[NodePath] = []
@export var aggro_radius: float = 6.0

## Filled by WayfarerCharacter factory in task 8. Nil = use defaults.
var character = null  # WayfarerCharacter

var _state: State = State.PATROL
var _patrol_idx: int = 0
var _target: CharacterBody3D = null
var _attack_timer: float = 0.0

## Emitted when this enemy takes damage (hp_current, hp_max).
signal hp_changed(current: int, max_hp: int)
## Emitted when dead.
signal died

func _ready() -> void:
	add_to_group("enemies")
	var aggro_area := Area3D.new()
	var shape_node := CollisionShape3D.new()
	var sphere     := SphereShape3D.new()
	sphere.radius  = aggro_radius
	shape_node.shape = sphere
	aggro_area.add_child(shape_node)
	aggro_area.collision_layer = 0
	aggro_area.collision_mask  = 1  # detect layer 1 (player)
	add_child(aggro_area)
	aggro_area.body_entered.connect(_on_body_entered)
	aggro_area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match _state:
		State.PATROL: _do_patrol(delta)
		State.CHASE:  _do_chase(delta)
		State.ATTACK: _do_attack(delta)

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
	if _target == null:
		_state = State.PATROL; return
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

func _do_attack(delta: float) -> void:
	if _target == null:
		_state = State.PATROL; return
	var dist := global_position.distance_to(_target.global_position)
	if dist > MELEE_DIST + 0.5:
		_state = State.CHASE; return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = 1.5
		_fire_attack()

func _fire_attack() -> void:
	if character == null or _target == null:
		return
	var target_char = null
	if _target.has_method("get") and GameState.sarro != null:
		target_char = GameState.sarro

	var attacker = character.make_combatant()
	var defender_stats = target_char.stats if target_char != null else _CharacterStats.new()

	var d20: int       = _Dice.roll_d20()
	var atk_mod: int   = attacker.attack_modifier()
	var total_atk: int = d20 + atk_mod
	var target_ac: int = defender_stats.armor_class

	var hit: bool  = total_atk >= target_ac
	var crit: bool = d20 == 20
	var dmg  := 0

	if hit and target_char != null:
		dmg = attacker.roll_damage(crit)
		target_char.stats.current_hp = max(0, target_char.stats.current_hp - dmg)
		if target_char.stats.current_hp <= 0:
			print("[Combat] Sarro is defeated!")

	if hit:
		print("[Combat] Bandit hits Sarro for %d (d20=%d+%d vs AC%d)" % [dmg, d20, atk_mod, target_ac])
	else:
		print("[Combat] Bandit misses Sarro (d20=%d+%d vs AC%d)" % [d20, atk_mod, target_ac])

func receive_damage(amount: int) -> void:
	if character == null:
		return
	character.stats.current_hp = max(0, character.stats.current_hp - amount)
	hp_changed.emit(character.stats.current_hp, character.stats.max_hp)
	if character.stats.current_hp <= 0:
		died.emit()
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and _state == State.PATROL:
		_target = body as CharacterBody3D
		_state  = State.CHASE

func _on_body_exited(body: Node3D) -> void:
	if body == _target and _state != State.ATTACK:
		_target = null
		_state  = State.PATROL
