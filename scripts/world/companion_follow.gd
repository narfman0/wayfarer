## Companion AI — Liris follows Sarro at a fixed offset, and joins the fight
## when enemies come near, swinging with her own MeleeAttacker.
class_name CompanionFollow
extends CharacterBody3D

const SPEED       := 5.2  # slightly faster than player so she catches up
const STOP_DIST   := 1.6  # metres — personal space bubble
const GRAVITY     := 9.8
const ENGAGE_DIST := 7.0  # metres — join combat when an enemy is this close
const MELEE_DIST  := 1.5

@export var follow_target: CharacterBody3D

## MeleeAttacker wired by the level (character = GameState.liris).
var attacker = null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var enemy = _nearest_enemy()
	if enemy != null:
		_engage(enemy, delta)
	else:
		if attacker != null:
			attacker.stop()
		_follow(delta)

	move_and_slide()

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
