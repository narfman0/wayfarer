## Companion AI — Liris follows Sarro at a fixed offset, stopping when close.
class_name CompanionFollow
extends CharacterBody3D

const SPEED       := 5.2  # slightly faster than player so she catches up
const STOP_DIST   := 1.6  # metres — personal space bubble
const GRAVITY     := 9.8

@export var follow_target: CharacterBody3D

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if follow_target == null:
		move_and_slide()
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

	move_and_slide()
