## Third-person player controller for Sarro.
## Primary: left-click on ground to move (Diablo-style).
## Secondary: WASD/left-stick for direct movement.
class_name PlayerController
extends CharacterBody3D

const SPEED      := 5.0

## Build-choice speed multiplier (Mobile feat, Skirmisher style) — set by the
## level after party sync.
var speed_mult: float = 1.0
const SPRINT_MUL := 1.8
const GRAVITY    := 9.8
const ARRIVE_DIST := 0.35  # metres — stop threshold for click-to-move

## Raycast mask for click targeting: ground (layer 1) + enemies (layer 2).
const CLICK_MASK := 3

@export var camera_pivot: Node3D

## Currently targeted enemy node — set by scene when player clicks an enemy.
var target_enemy: Node3D = null

var _enabled: bool = true
var _click_target: Vector3 = Vector3.INF  # INF = no active click destination

func _physics_process(delta: float) -> void:
	if not _enabled:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# WASD / stick input takes priority over click-to-move
	var stick := _read_input()
	if stick.length_squared() > 0.01:
		_click_target = Vector3.INF
		target_enemy = null
		_move_by_input(stick, delta)
	elif _click_target != Vector3.INF:
		_move_toward_click(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)

	move_and_slide()

func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(event.position)

func set_control_enabled(v: bool) -> void:
	_enabled = v
	if not v:
		velocity = Vector3.ZERO
		_click_target = Vector3.INF

# ── Private ──────────────────────────────────────────────────────────────────

func _read_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _move_by_input(stick: Vector2, delta: float) -> void:
	var cam_basis := _camera_flat_basis()
	var dir       := (cam_basis * Vector3(stick.x, 0.0, stick.y)).normalized()
	var speed     := SPEED * speed_mult * (SPRINT_MUL if Input.is_action_pressed("sprint") else 1.0)
	velocity.x    = dir.x * speed
	velocity.z    = dir.z * speed
	rotation.y    = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)

func _move_toward_click(delta: float) -> void:
	var flat_pos := Vector3(global_position.x, 0.0, global_position.z)
	var flat_tgt := Vector3(_click_target.x, 0.0, _click_target.z)
	var dist     := flat_pos.distance_to(flat_tgt)
	if dist <= ARRIVE_DIST:
		_click_target = Vector3.INF
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir    := (flat_tgt - flat_pos).normalized()
	velocity.x = dir.x * SPEED * speed_mult
	velocity.z = dir.z * SPEED * speed_mult
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)

func _handle_left_click(screen_pos: Vector2) -> void:
	var cam := _get_camera()
	if cam == null:
		return

	var space := get_world_3d().direct_space_state
	var ray_origin := cam.project_ray_origin(screen_pos)
	var ray_end    := ray_origin + cam.project_ray_normal(screen_pos) * 200.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, CLICK_MASK, [get_rid()])
	var hit   := space.intersect_ray(query)
	if hit:
		# If we hit a node with an "enemy" group tag, target it instead
		var collider = hit.get("collider")
		if collider != null and collider.is_in_group("enemies"):
			target_enemy = collider
			_click_target = collider.global_position
		else:
			target_enemy = null
			_click_target = hit["position"]

func _get_camera() -> Camera3D:
	if camera_pivot == null:
		return get_viewport().get_camera_3d()
	var cam := camera_pivot.get_node_or_null("Camera3D") as Camera3D
	return cam if cam != null else get_viewport().get_camera_3d()

func _camera_flat_basis() -> Basis:
	var cam := _get_camera()
	if cam == null:
		return Basis.IDENTITY
	var fwd   := Vector3(cam.global_transform.basis.z.x, 0.0, cam.global_transform.basis.z.z).normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	return Basis(right, Vector3.UP, fwd)
