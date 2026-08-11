## Procedural flat-island terrain: a 0/1 tile map → flat top surface + void skirt.
## Each cell is IslandGrid.TILE_SIZE (2 m). Map values: 1 = island tile (solid,
## rendered, walkable), 0 = void (no geometry, not walkable). The whole top
## surface sits at y=0 (player ground level); every island edge bordering the
## void (or the grid boundary) grows a single skirt quad down to SKIRT_Y so the
## level reads as a flat platform floating in the void.
## Call rebuild_from(map) to swap the island shape at runtime — collision is
## regenerated via create_trimesh_collision().
class_name TiledTerrain
extends Node3D

const _IslandGrid = preload("res://scripts/world/island_grid.gd")

const CELL  := _IslandGrid.TILE_SIZE          # metres per grid cell (2.0)
const COLS  := _IslandGrid.DEFAULT_GRID_SIZE  # 32
const ROWS  := _IslandGrid.DEFAULT_GRID_SIZE  # 32

## Skirt quads drop from the surface (y=0) to this world y — the island bottom.
const SKIRT_Y := -3.5

## Default surface / skirt colours. Index 0 is unused (void), index 1 is the
## island top; kept as an array so set_palette() overrides (e.g. the dungeon's
## stone palette) can still index by tile value.
const PALETTE := [
	Color(0.14, 0.25, 0.12),  # 0  void (never drawn)
	Color(0.75, 0.70, 0.60),  # 1  island surface (sandy stone)
]

const SKIRT_DARKEN := 0.45  # skirt faces are this much darker than the top

## Runtime palette override. When non-empty, used instead of PALETTE.
## Set via set_palette() before _build() / rebuild_from() is called.
var _palette_override: Array[Color] = []

func set_palette(p: Array[Color]) -> void:
	_palette_override = p

## Default island shape: full 32×32 square (all 1s). Levels override with
## irregular shapes via rebuild_from() — 1 = island tile, 0 = void.
var _default_map: Array = []

static func _full_square_map() -> Array:
	var m: Array = []
	for _r in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill(1)
		m.append(row)
	return m

## Optional runtime override — set before _ready() or call rebuild_from().
var _active_map: Array = []

func _ready() -> void:
	_build()

## Replace the map at runtime and regenerate geometry + collision.
## Call this from a level script's _on_level_ready() after setting _active_map.
func rebuild_from(new_map: Array) -> void:
	_active_map = new_map
	_build()

## The tile map currently driving the mesh — for pathfinding grids etc.
func active_map() -> Array:
	if _active_map.size() == ROWS:
		return _active_map
	if _default_map.is_empty():
		_default_map = _full_square_map()
	return _default_map

func _build() -> void:
	for c in get_children():
		c.queue_free()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_w := COLS * CELL * 0.5  # 32.0
	var half_h := ROWS * CELL * 0.5  # 32.0

	var active: Array = active_map()
	var pal: Array = _palette_override if _palette_override.size() >= 2 else PALETTE

	var top_c: Color   = pal[1]
	var skirt_c: Color = top_c.darkened(SKIRT_DARKEN)

	for row in ROWS:
		for col in COLS:
			if int(active[row][col]) <= 0:
				continue  # void — no geometry
			var x0 := col * CELL - half_w
			var z0 := row * CELL - half_h
			var x1 := x0 + CELL
			var z1 := z0 + CELL

			# ── top face (normal UP, y=0) ────────────────────────────────────
			_quad(st, Vector3(x0,0,z1), Vector3(x1,0,z1),
			          Vector3(x1,0,z0), Vector3(x0,0,z0), Vector3.UP, top_c)

			# ── skirt faces where a neighbour is void (off-grid counts) ──────
			var void_n: bool = row == 0        or int(active[row-1][col]) <= 0
			var void_s: bool = row == ROWS - 1 or int(active[row+1][col]) <= 0
			var void_e: bool = col == COLS - 1 or int(active[row][col+1]) <= 0
			var void_w: bool = col == 0        or int(active[row][col-1]) <= 0

			if void_n:  # z−, normal 0,0,−1
				_quad(st, Vector3(x1,0,z0), Vector3(x0,0,z0),
				          Vector3(x0,SKIRT_Y,z0), Vector3(x1,SKIRT_Y,z0),
				          Vector3(0,0,-1), skirt_c)
			if void_s:  # z+, normal 0,0,+1
				_quad(st, Vector3(x0,0,z1), Vector3(x1,0,z1),
				          Vector3(x1,SKIRT_Y,z1), Vector3(x0,SKIRT_Y,z1),
				          Vector3(0,0,1), skirt_c)
			if void_e:  # x+, normal +1,0,0
				_quad(st, Vector3(x1,0,z0), Vector3(x1,0,z1),
				          Vector3(x1,SKIRT_Y,z1), Vector3(x1,SKIRT_Y,z0),
				          Vector3(1,0,0), skirt_c)
			if void_w:  # x−, normal −1,0,0
				_quad(st, Vector3(x0,0,z1), Vector3(x0,0,z0),
				          Vector3(x0,SKIRT_Y,z0), Vector3(x0,SKIRT_Y,z1),
				          Vector3(-1,0,0), skirt_c)

	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)
	mi.create_trimesh_collision()

	# Ensure the auto-generated StaticBody is on the ground collision layer
	for child in mi.get_children():
		if child is StaticBody3D:
			child.collision_layer = 1
			child.collision_mask  = 0

func _quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
		normal: Vector3, color: Color) -> void:
	for v: Vector3 in [v0, v1, v2, v0, v2, v3]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v)
