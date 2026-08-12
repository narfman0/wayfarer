## Third-person player controller for Sarro.
## Primary: left-click on ground to move (Diablo-style).
## Secondary: WASD/left-stick for direct movement.
class_name PlayerController
extends CharacterBody3D

const _CharAnim = preload("res://scripts/world/character_animator.gd")
const _IslandGrid = preload("res://scripts/world/island_grid.gd")

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
var target_enemy: Node3D = null   # sticky selection: survives ground clicks
var hovered_enemy: Node3D = null  # whatever enemy is under the cursor right now

var _lmb_held := false
var _hold_timer := 0.0
var _hover_timer := 0.0
var _mouse_pos := Vector2.ZERO

# Forced-movement states (enemy shoves/grapples work on us too).
var _knockback := Vector3.ZERO
var _root_left := 0.0

func root(secs: float) -> void:
	_root_left = maxf(_root_left, secs)

func is_rooted() -> bool:
	return _root_left > 0.0

var _enabled: bool = true
var _click_target: Vector3 = Vector3.INF  # INF = no active click destination

# ── Click-to-walk pathfinding ────────────────────────────────────────────────
# AStarGrid2D over the level's IslandGrid tile map. The level (or dungeon
# generator) calls rebuild_pathfinding(map) whenever the terrain changes.
# There are no ramps, so a tile is only reachable across tiles of the SAME
# height — solidity is refreshed per click against the player's current
# height layer. When no path exists (or no map was provided) clicks fall back
# to the old straight-line steering.
var _astar: AStarGrid2D = null
var _terrain_map: Array = []              # rows of int heights (0 = void)
var _waypoints: Array[Vector3] = []       # remaining path corners → click target

func _ready() -> void:
	add_to_group("players")
	var skin := get_node_or_null("Skin")
	if skin != null:
		_CharAnim.attach(skin, self, "masc")

func _physics_process(delta: float) -> void:
	if not _enabled:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Hold-to-attack / drag-to-move: while LMB is held, keep re-issuing the
	# click under the cursor — chase a moving enemy, swing whenever in range.
	if _lmb_held:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_hold_timer = 0.14
			_handle_left_click(_mouse_pos)
	# Hover: cheap throttled ray so any enemy under the cursor shows info.
	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = 0.1
		hovered_enemy = _enemy_under_cursor()

	# Rooted (grappled): no voluntary movement, knockback still applies.
	if _root_left > 0.0:
		_root_left -= delta
		velocity.x = _knockback.x
		velocity.z = _knockback.z
		_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)
		move_and_slide()
		return

	# WASD / stick input takes priority over click-to-move
	var stick := _read_input()
	if stick.length_squared() > 0.01:
		_click_target = Vector3.INF
		_waypoints.clear()
		target_enemy = null
		_move_by_input(stick, delta)
	elif _click_target != Vector3.INF:
		_move_toward_click(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)

	velocity.x += _knockback.x
	velocity.z += _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_held = true
				_hold_timer = 0.14
				_handle_left_click(event.position)
			else:
				_lmb_held = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			target_enemy = null  # explicit deselect

func set_control_enabled(v: bool) -> void:
	_enabled = v
	if not v:
		velocity = Vector3.ZERO
		_click_target = Vector3.INF
		_waypoints.clear()

## (Re)build the pathfinding grid from a terrain height map (rows of ints).
## Call after terrain generation/regeneration — e.g. DungeonRun's map carve.
func rebuild_pathfinding(map: Array) -> void:
	_terrain_map = map
	_waypoints.clear()
	if map.is_empty():
		_astar = null
		return
	var rows: int = map.size()
	var cols: int = map[0].size()
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, cols, rows)
	_astar.cell_size = Vector2(_IslandGrid.TILE_SIZE, _IslandGrid.TILE_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()

## Mark tiles solid for the given walk height: void tiles and any tile at a
## different height are impassable (no ramps exist between height layers).
func _refresh_astar_solidity(walk_height: int) -> void:
	var rows: int = _terrain_map.size()
	for r in rows:
		for c in _terrain_map[r].size():
			var h: int = _terrain_map[r][c]
			_astar.set_point_solid(Vector2i(c, r), h <= 0 or h != walk_height)

## Compute tile-path waypoints from the player to `dest`, or [] when
## pathfinding can't help (no grid, off-grid click, unreachable target).
func _plan_path(dest: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _astar == null:
		return out
	var grid_size: int = _terrain_map.size()
	var from := _IslandGrid.world_to_tile(global_position, grid_size)
	var to   := _IslandGrid.world_to_tile(dest, grid_size)
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to) or from == to:
		return out
	var walk_height: int = _terrain_map[from.y][from.x]
	if walk_height <= 0:
		return out
	_refresh_astar_solidity(walk_height)
	if _astar.is_point_solid(to):
		return out
	var tiles := _astar.get_id_path(from, to)
	if tiles.size() < 2:
		return out
	# Skip the tile we're standing on; the caller appends the exact click pos.
	for i in range(1, tiles.size()):
		out.append(_IslandGrid.tile_to_world(tiles[i], walk_height, grid_size))
	return out

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
	# Steer toward the next path waypoint when one exists; the final leg (and
	# any pathless click) steers straight at the click position itself.
	var waypoint: Vector3 = _waypoints[0] if not _waypoints.is_empty() else _click_target
	var flat_pos := Vector3(global_position.x, 0.0, global_position.z)
	var flat_tgt := Vector3(waypoint.x, 0.0, waypoint.z)
	var dist     := flat_pos.distance_to(flat_tgt)
	if not _waypoints.is_empty():
		if dist <= ARRIVE_DIST * 2.0:  # corners don't need pinpoint arrival
			_waypoints.pop_front()
		_steer_toward(flat_pos, flat_tgt, delta)
		return
	if dist <= ARRIVE_DIST:
		_click_target = Vector3.INF
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_steer_toward(flat_pos, flat_tgt, delta)

func _steer_toward(flat_pos: Vector3, flat_tgt: Vector3, delta: float) -> void:
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
			_waypoints = _plan_path(_click_target)
		else:
			# Sticky selection: a ground click MOVES without deselecting —
			# right-click (or target death) clears the selection.
			_click_target = hit["position"]
			_waypoints = _plan_path(_click_target)

## The enemy under the mouse cursor, or null. Same mask as clicks, so the
## invisible walls never eat a hover either.
func _enemy_under_cursor() -> Node3D:
	var cam := _get_camera()
	if cam == null:
		return null
	var space := get_world_3d().direct_space_state
	var origin := cam.project_ray_origin(_mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin,
		origin + cam.project_ray_normal(_mouse_pos) * 200.0, CLICK_MASK, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit and hit.get("collider") != null and hit["collider"].is_in_group("enemies"):
		return hit["collider"]
	return null

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


