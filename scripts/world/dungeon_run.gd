## Procedurally generated dungeon encounter — room+corridor BSP layout.
## Each run carves 4-6 rooms of random sizes into a 20×20 stone MAP,
## connects them with L-shaped corridors, spawns 1-2 enemies per room
## (skipping the entry room), and places an exit portal in the final room.
class_name DungeonRun
extends WayfarerLevel

const _VeilPortal = preload("res://scripts/world/portal.gd")
const _EnemyController = preload("res://scripts/combat/enemy_controller.gd")

@export var plane_id: String = "dungeon_run"
@export var exit_to: String = "tamori"
@export var exit_spawn: String = "dungeon_return"

## How many rooms to try to place (some may fail overlap check).
@export_range(3, 8) var target_rooms: int = 5
## Enemy type string from CharacterFactory.make_enemy().
@export var enemy_type: String = "bandit"

var _rng := RandomNumberGenerator.new()
var _rooms: Array = []        # each: {x, y, w, h}
var _dungeon_map: Array = []  # 20×20 int heights

func _on_level_ready() -> void:
	_rng.randomize()
	_generate_map()
	_apply_map_to_terrain()
	_spawn_enemies()
	_place_exit_portal()
	_place_player_at_entry()

# ── Map generation ────────────────────────────────────────────────────────────

func _generate_map() -> void:
	# Fill everything with height-2 stone walls.
	_dungeon_map = []
	for _r in 20:
		var row: Array = []
		for _c in 20:
			row.append(2)
		_dungeon_map.append(row)

	# Carve rooms.
	_rooms.clear()
	for _attempt_outer in target_rooms:
		_try_place_room()

	if _rooms.is_empty():
		# Fallback: single open room
		_rooms.append({x=4, y=4, w=12, h=12})

	# Sort rooms left-to-right so entry/exit are predictable.
	_rooms.sort_custom(func(a, b): return a.x < b.x)

	# Carve room floors.
	for rm in _rooms:
		_carve_rect(rm.x, rm.y, rm.w, rm.h, 1)

	# Connect rooms with L-shaped corridors.
	for i in range(1, _rooms.size()):
		var a = _rooms[i - 1]
		var b = _rooms[i]
		var ax: int = a.x + a.w / 2
		var ay: int = a.y + a.h / 2
		var bx: int = b.x + b.w / 2
		var by_: int = b.y + b.h / 2
		# Horizontal leg then vertical leg.
		var cx: int = ax
		var step_x: int = 1 if bx > cx else -1
		while cx != bx:
			_dungeon_map[ay][cx] = 1
			cx += step_x
		var cy: int = ay
		var step_y: int = 1 if by_ > cy else -1
		while cy != by_:
			_dungeon_map[cy][bx] = 1
			cy += step_y

func _try_place_room() -> void:
	for _attempt in 30:
		var w: int = _rng.randi_range(3, 6)
		var h: int = _rng.randi_range(3, 6)
		var x: int = _rng.randi_range(1, 19 - w)
		var y: int = _rng.randi_range(1, 19 - h)
		var overlap := false
		for rm in _rooms:
			if x < rm.x + rm.w + 1 and x + w > rm.x - 1 \
					and y < rm.y + rm.h + 1 and y + h > rm.y - 1:
				overlap = true
				break
		if not overlap:
			_rooms.append({x=x, y=y, w=w, h=h})
			return

func _carve_rect(rx: int, ry: int, rw: int, rh: int, height: int) -> void:
	for r in range(ry, ry + rh):
		for c in range(rx, rx + rw):
			if r >= 0 and r < 20 and c >= 0 and c < 20:
				_dungeon_map[r][c] = height

# ── Apply to terrain ──────────────────────────────────────────────────────────

func _apply_map_to_terrain() -> void:
	var terrain = get_node_or_null("Level/TiledTerrain")
	if terrain != null and terrain.has_method("rebuild_from"):
		terrain.rebuild_from(_dungeon_map)

# ── Enemy spawning ────────────────────────────────────────────────────────────

func _spawn_enemies() -> void:
	# Skip entry room (index 0); spawn 1 enemy per remaining room.
	for i in range(1, _rooms.size()):
		var rm = _rooms[i]
		var cx: float = (rm.x + rm.w * 0.5 - 10.0) * 4.0
		var cz: float = (rm.y + rm.h * 0.5 - 10.0) * 4.0
		_spawn_enemy_at(Vector3(cx, 0.9, cz))
		# Two enemies in the last room.
		if i == _rooms.size() - 1 and _rooms.size() > 2:
			_spawn_enemy_at(Vector3(cx + 2.0, 0.9, cz - 1.5))

func _spawn_enemy_at(pos: Vector3) -> void:
	var body := CharacterBody3D.new()
	body.name = "DungeonEnemy%d" % get_tree().get_nodes_in_group("enemies").size()
	body.collision_layer = 2
	body.collision_mask  = 1
	body.global_position = pos
	body.add_to_group("enemies")

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.8; cap.radius = 0.35
	col.shape  = cap
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)

	# Placeholder mesh (magenta capsule — swappable for a character skin later).
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = 1.8; mesh.radius = 0.35
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.6)
	mi.material_override = mat
	mi.position = Vector3(0, 0.9, 0)
	body.add_child(mi)

	# Attach EnemyController script.
	var script = load("res://scripts/combat/enemy_controller.gd")
	if script != null:
		body.set_script(script)
		body.enemy_type = enemy_type
		body.gold_min   = 5
		body.gold_max   = 18

	get_node("Enemies").add_child(body)

# ── Exit portal ───────────────────────────────────────────────────────────────

func _place_exit_portal() -> void:
	if _rooms.is_empty():
		return
	var last = _rooms[-1]
	var px: float = (last.x + last.w * 0.5 - 10.0) * 4.0
	var pz: float = (last.y + last.h * 0.5 - 10.0) * 4.0

	var portal_script = load("res://scripts/world/portal.gd")
	if portal_script == null:
		return
	var portal := Node3D.new()
	portal.name = "ExitPortal"
	portal.set_script(portal_script)
	portal.global_position = Vector3(px, 0, pz)
	portal.set("display_name", "Exit Dungeon")
	portal.set("target_plane", exit_to)
	portal.set("target_spawn_id", exit_spawn)
	portal.set("spawn_id", "dungeon_entry")
	get_node("Level").add_child(portal)

# ── Player entry ─────────────────────────────────────────────────────────────

func _place_player_at_entry() -> void:
	if _rooms.is_empty():
		return
	var entry = _rooms[0]
	var px: float = (entry.x + entry.w * 0.5 - 10.0) * 4.0
	var pz: float = (entry.y + entry.h * 0.5 - 10.0) * 4.0
	var player := get_node_or_null("Characters/Sarro")
	var companion := get_node_or_null("Characters/Liris")
	if player != null:
		player.global_position = Vector3(px, 0.9, pz)
	if companion != null:
		companion.global_position = Vector3(px - 1.5, 0.9, pz + 1.0)

# ── Dungeon palette override (stone colours) ──────────────────────────────────
# Hack: patch terrain palette before _apply_map_to_terrain if TiledTerrain
# ever exposes a mutable PALETTE. For now the default grass/earth works and
# the stone heights (2) read as raised earth — close enough until we skin it.
