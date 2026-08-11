## Procedurally generated dungeon encounter — room+corridor layout.
## Each run carves 4-6 rooms of random sizes into a 32×32 void map: room
## floors and connecting corridors are island tiles (1), everything else is
## void (0) — so the dungeon reads as floating platforms joined by narrow
## walkways. Spawns 1-2 enemies per room (skipping the entry room) and places
## an exit portal in the final room.
class_name DungeonRun
extends WayfarerLevel

const _VeilPortal = preload("res://scripts/world/portal.gd")
const _EnemyController = preload("res://scripts/combat/enemy_controller.gd")
const _IslandGrid = preload("res://scripts/world/island_grid.gd")

## Grid dimensions and metres-per-tile from the shared island grid spec.
const _N: int = _IslandGrid.DEFAULT_GRID_SIZE      # 32
const _TILE: float = _IslandGrid.TILE_SIZE         # 2.0
## Room extents in tiles (was 3–6 on the old 20-wide map).
const _ROOM_MIN := 4
const _ROOM_MAX := 8

@export var exit_to: String = "tamori"
@export var exit_spawn: String = "dungeon_return"

## How many rooms to try to place (some may fail overlap check).
@export_range(3, 8) var target_rooms: int = 5
## Enemy type string from CharacterFactory.make_enemy().
@export var enemy_type: String = "bandit"

var _rng := RandomNumberGenerator.new()
var _rooms: Array = []        # each: {x, y, w, h}
var _dungeon_map: Array = []  # 32×32 ints: 1 = island tile, 0 = void
## Per-run seed captured after randomize(); drives deterministic loot per position.
var _dungeon_seed: int = 0
## Counter so each enemy gets a unique offset from the dungeon seed.
var _enemy_idx: int = 0

func _on_level_ready() -> void:
	_rng.randomize()
	_dungeon_seed = _rng.seed
	_generate_map()
	_apply_map_to_terrain()
	_spawn_enemies()
	_place_exit_portal()
	_place_player_at_entry()

# ── Map generation ────────────────────────────────────────────────────────────

func _generate_map() -> void:
	# Start with pure void; rooms and corridors carve island tiles into it.
	_dungeon_map = []
	for _r in _N:
		var row: Array = []
		row.resize(_N)
		row.fill(0)
		_dungeon_map.append(row)

	# Carve rooms.
	_rooms.clear()
	for _attempt_outer in target_rooms:
		_try_place_room()

	if _rooms.is_empty():
		# Fallback: single open room
		_rooms.append({x=8, y=8, w=16, h=16})

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
		var w: int = _rng.randi_range(_ROOM_MIN, _ROOM_MAX)
		var h: int = _rng.randi_range(_ROOM_MIN, _ROOM_MAX)
		# Keep a void margin between rooms and the grid rim (tiles 2.._N-3).
		var x: int = _rng.randi_range(2, _N - 3 - w)
		var y: int = _rng.randi_range(2, _N - 3 - h)
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
			if r >= 1 and r < _N - 1 and c >= 1 and c < _N - 1:
				_dungeon_map[r][c] = height

# ── Apply to terrain ──────────────────────────────────────────────────────────

func _apply_map_to_terrain() -> void:
	var terrain = get_node_or_null("Level/TiledTerrain")
	if terrain == null:
		return
	if terrain.has_method("set_palette"):
		var pal: Array[Color] = [
			Color(0.08, 0.07, 0.06),  # 0  void (never drawn)
			Color(0.28, 0.26, 0.23),  # 1  dungeon platform (dark stone)
		]
		terrain.set_palette(pal)
	if terrain.has_method("rebuild_from"):
		terrain.rebuild_from(_dungeon_map)
	# Refresh the player's click-to-walk grid for the generated layout.
	var player = get_node_or_null("Characters/Sarro")
	if player != null and player.has_method("rebuild_pathfinding"):
		player.rebuild_pathfinding(_dungeon_map)
	_scatter_dungeon_props()

## Room-centre tile coords → world position (grid centred on the origin).
func _room_center(rm) -> Vector3:
	return Vector3(
		(rm.x + rm.w * 0.5 - _N * 0.5) * _TILE, 0.0,
		(rm.y + rm.h * 0.5 - _N * 0.5) * _TILE)

# ── Dungeon prop decoration ───────────────────────────────────────────────────

const _DUNGEON_DIR := "res://assets/meshes/POLYGON_Fantasy_Kingdom_SourceFiles_v5/Source_Files/FBX/"

const _PILLAR_MESHES := [
	"SM_Bld_Castle_Pillar_Stone_01.gltf",
	"SM_Bld_Castle_Pillar_Stone_02.gltf",
	"SM_Bld_Castle_Pillar_Stone_Round_01.gltf",
]
const _RUBBLE_MESHES := [
	"SM_Bld_Castle_DestroyedWall_RubblePile_01.gltf",
	"SM_Bld_Castle_DestroyedWall_RubbleBlock_01.gltf",
]
const _CANDLE_MESH := "FX_Item_Candlestick_01.gltf"

func _scatter_dungeon_props() -> void:
	var props_node := get_node_or_null("Level/Props")
	if props_node == null:
		props_node = Node3D.new()
		props_node.name = "Props"
		get_node("Level").add_child(props_node)

	# Each room gets corner pillars and a candle; non-entry rooms get rubble.
	for i in _rooms.size():
		var rm = _rooms[i]
		var center := _room_center(rm)
		var cx: float = center.x
		var cz: float = center.z
		var hw: float = rm.w * _TILE * 0.5 - 0.5
		var hh: float = rm.h * _TILE * 0.5 - 0.5

		# Candle near the centre of every room.
		_place_prop(props_node, _DUNGEON_DIR + _CANDLE_MESH,
				Vector3(cx + 0.8, 0.0, cz + 0.8))

		# Pillars at room corners (inset one unit from wall).
		var pillar: String = _PILLAR_MESHES[i % _PILLAR_MESHES.size()]
		for dx in [-1.0, 1.0]:
			for dz in [-1.0, 1.0]:
				_place_prop(props_node, _DUNGEON_DIR + pillar,
						Vector3(cx + dx * (hw - 1.0), 0.0, cz + dz * (hh - 1.0)))

		# Rubble in non-entry combat rooms.
		if i > 0:
			var rubble: String = _RUBBLE_MESHES[i % _RUBBLE_MESHES.size()]
			_place_prop(props_node, _DUNGEON_DIR + rubble,
					Vector3(cx - hw * 0.4, 0.0, cz + hh * 0.3))

func _place_prop(parent: Node3D, path: String, pos: Vector3) -> void:
	if not FileAccess.file_exists(path + ".import"):
		return
	var ps = load(path) as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate()
	inst.position = pos
	parent.add_child(inst)

# ── Enemy spawning ────────────────────────────────────────────────────────────

func _spawn_enemies() -> void:
	# Skip entry room (index 0); spawn 1 enemy per remaining room.
	for i in range(1, _rooms.size()):
		var rm = _rooms[i]
		var center := _room_center(rm)
		_spawn_enemy_at(Vector3(center.x, 0.9, center.z))
		# Two enemies in the last room.
		if i == _rooms.size() - 1 and _rooms.size() > 2:
			_spawn_enemy_at(Vector3(center.x + 2.0, 0.9, center.z - 1.5))

func _spawn_enemy_at(pos: Vector3) -> void:
	var body := CharacterBody3D.new()
	body.name = "DungeonEnemy%d" % get_tree().get_nodes_in_group("enemies").size()
	body.collision_layer = 2
	body.collision_mask  = 1
	# Local, not global: the node is not in the tree yet, so global_position
	# errors out ("!is_inside_tree()"). Enemies/ sits at the origin so local ==
	# global, and setting it here means EnemyController._ready() captures the
	# right _spawn_pos when add_child() below puts it in the tree.
	body.position = pos
	body.add_to_group("enemies")

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.8; cap.radius = 0.35
	col.shape  = cap
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)

	var _skin_map := {
		"skeleton": "res://assets/meshes/POLYGON_Dark_Fantasy_SourceFiles_v3/SourceFiles/FBX/Characters/Unreal_Characters/SK_Chr_Skeleton_01.glb",
		"skeleton_armored": "res://assets/meshes/POLYGON_Dark_Fantasy_SourceFiles_v3/SourceFiles/FBX/Characters/Unreal_Characters/SK_Chr_Skeleton_HeavyArmor_01.glb",
		"skeleton_ranger": "res://assets/meshes/POLYGON_Dark_Fantasy_SourceFiles_v3/SourceFiles/FBX/Characters/Unreal_Characters/SK_Chr_Skeleton_Ranger_01.glb",
		"hunter": "res://assets/meshes/POLYGON_Dark_Fantasy_SourceFiles_v3/SourceFiles/FBX/Characters/Unreal_Characters/SK_Chr_Hunter_Male_01.glb",
	}
	var skin_path: String = _skin_map.get(enemy_type, _skin_map["skeleton"])
	var skin_scene = load(skin_path) if FileAccess.file_exists(skin_path + ".import") else null
	if skin_scene != null:
		var mi: Node3D = skin_scene.instantiate()
		mi.name = "Skin"
		mi.position = Vector3(0, 0, 0)
		body.add_child(mi)
	else:
		var mi := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.height = 1.8; mesh.radius = 0.35
		mi.mesh = mesh
		mi.position = Vector3(0, 0.9, 0)
		body.add_child(mi)

	# Attach EnemyController script.
	var script = load("res://scripts/combat/enemy_controller.gd")
	if script != null:
		body.set_script(script)
		body.enemy_type     = enemy_type
		body.loot_table_key = "dungeon_basic"
		# Each enemy gets a unique seed derived from the dungeon seed so the same
		# dungeon layout always produces the same loot (deterministic runs).
		body.loot_seed      = _dungeon_seed ^ (_enemy_idx * 0x9e3779b9)
		_enemy_idx         += 1

	get_node("Enemies").add_child(body)

# ── Exit portal ───────────────────────────────────────────────────────────────

func _place_exit_portal() -> void:
	if _rooms.is_empty():
		return
	var last = _rooms[-1]
	var center := _room_center(last)
	var px: float = center.x
	var pz: float = center.z

	var portal_script = load("res://scripts/world/portal.gd")
	if portal_script == null:
		return
	var portal := Node3D.new()
	portal.name = "ExitPortal"
	portal.set_script(portal_script)
	portal.position = Vector3(px, 0, pz)  # local — not in the tree yet; Level is at origin
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
	var center := _room_center(entry)
	var px: float = center.x
	var pz: float = center.z
	var player := get_node_or_null("Characters/Sarro")
	var companion := get_node_or_null("Characters/Liris")
	if player != null:
		player.global_position = Vector3(px, 0.9, pz)
	if companion != null:
		companion.global_position = Vector3(px - 1.5, 0.9, pz + 1.0)
