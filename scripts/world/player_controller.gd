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

# TB combat: position where movement began this click (for distance accounting).
var _tb_move_start: Vector3 = Vector3.INF
var _attack_mode: bool = false

# Visual move-range ring shown during TB player turn.
var _move_ring: MeshInstance3D = null

func _ready() -> void:
	add_to_group("players")
	_build_move_ring()

func _physics_process(delta: float) -> void:
	if not _enabled:
		return

	# In TB mode, block movement when it is not the player's turn.
	if CombatManager.tb_mode and not CombatManager.is_player_turn():
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)
		velocity.y -= GRAVITY * delta if not is_on_floor() else 0.0
		move_and_slide()
		_update_move_ring()
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
	_update_move_ring()

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

## Called by CombatHUD Attack button to enter click-target-enemy mode.
func enter_attack_mode() -> void:
	_attack_mode = true

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
		# TB: account for the distance actually walked.
		if CombatManager.tb_mode and _tb_move_start != Vector3.INF:
			var walked: float = _tb_move_start.distance_to(global_position)
			CombatManager.spend_movement(self, walked)
			_tb_move_start = Vector3.INF
		_click_target = Vector3.INF
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# TB: refuse to move if no movement budget left.
	if CombatManager.tb_mode and CombatManager.is_player_turn():
		var left: float = CombatManager.movement_left(self)
		if left <= 0.01:
			_click_target = Vector3.INF
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
			if _attack_mode and CombatManager.tb_mode and CombatManager.is_player_turn():
				# Attack mode: spend action, let existing melee logic resolve.
				_attack_mode = false
				if CombatManager.has_action(self):
					CombatManager.spend_action(self)
			_click_target = collider.global_position
		else:
			_attack_mode = false
			target_enemy = null
			# TB: record move start for distance tracking.
			if CombatManager.tb_mode and CombatManager.is_player_turn():
				_tb_move_start = global_position
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

func _build_move_ring() -> void:
	_move_ring = MeshInstance3D.new()
	_move_ring.name = "MoveRing"
	var mesh := CylinderMesh.new()
	mesh.top_radius    = 0.0
	mesh.bottom_radius = 0.0
	mesh.height        = 0.04
	_move_ring.mesh    = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color         = Color(0.3, 0.7, 1.0, 0.45)
	mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode         = BaseMaterial3D.SHADING_MODE_UNSHADED
	_move_ring.material_override = mat
	_move_ring.position.y    = 0.05
	_move_ring.visible       = false
	add_child(_move_ring)

func _update_move_ring() -> void:
	if _move_ring == null:
		return
	var show := CombatManager.tb_mode and CombatManager.is_player_turn()
	_move_ring.visible = show
	if show:
		var r: float = CombatManager.movement_left(self)
		if r < 0.05:
			_move_ring.visible = false
			return
		var mesh := _move_ring.mesh as CylinderMesh
		mesh.top_radius    = r
		mesh.bottom_radius = r - 0.18
