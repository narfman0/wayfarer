## Third-person player controller for Sarro.
## WASD/left-stick moves relative to the camera's horizontal facing.
## Companion (Liris) follows automatically via CompanionFollow.
class_name PlayerController
extends CharacterBody3D

const SPEED      := 5.0   # m/s walk
const SPRINT_MUL := 1.8
const GRAVITY    := 9.8

## Set by TamoriScene after ready so the controller knows which camera to use.
@export var camera_pivot: Node3D

var _enabled: bool = true

func _physics_process(delta: float) -> void:
	if not _enabled:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir := _read_input()
	if input_dir.length_squared() > 0.01:
		var cam_basis := _camera_flat_basis()
		var move_dir  := (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		var speed     := SPEED * (SPRINT_MUL if Input.is_action_pressed("sprint") else 1.0)
		velocity.x    = move_dir.x * speed
		velocity.z    = move_dir.z * speed
		# Rotate character to face movement direction
		rotation.y    = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), 12.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)

	move_and_slide()

func set_control_enabled(v: bool) -> void:
	_enabled = v
	if not v:
		velocity = Vector3.ZERO

func _read_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _camera_flat_basis() -> Basis:
	if camera_pivot == null:
		return Basis.IDENTITY
	var cam_basis := camera_pivot.global_transform.basis
	# Flatten — ignore pitch so vertical camera angle doesn't tilt movement
	var fwd := Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	return Basis(right, Vector3.UP, fwd)
