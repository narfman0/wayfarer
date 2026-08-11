## Procedural flat-island terrain: a 0/1 tile map → flat top surface + craggy
## rocky underside. Each cell is IslandGrid.TILE_SIZE (2 m). Map values:
## 1 = island tile (solid, rendered, walkable), 0 = void (no geometry, not
## walkable). The whole top surface sits at y=0 (player ground level); every
## island edge bordering the void (or the grid boundary) grows a noise-displaced
## curtain of rock down to a ragged keel, closed by a bottom cap, so the level
## reads as a chunk of rock floating in the void.
## Call rebuild_from(map) to swap the island shape at runtime — collision is
## regenerated via create_trimesh_collision().
@tool
class_name TiledTerrain
extends Node3D

const _IslandGrid = preload("res://scripts/world/island_grid.gd")

const CELL  := _IslandGrid.TILE_SIZE          # metres per grid cell (2.0)
const COLS  := _IslandGrid.DEFAULT_GRID_SIZE  # 32
const ROWS  := _IslandGrid.DEFAULT_GRID_SIZE  # 32

## Underside curtain rings: y offset of each subdivision ring, from the rim
## (0, pinned to the flat top) down to the nominal keel depth. Spacing widens
## so the taper accelerates toward the bottom.
const SKIRT_RINGS := [0.0, -1.5, -3.5, -6.5]

## Default surface / skirt colours. Index 0 is unused (void), index 1 is the
## island top; kept as an array so set_palette() overrides (e.g. the dungeon's
## stone palette) can still index by tile value.
const PALETTE := [
	Color(0.14, 0.25, 0.12),  # 0  void (never drawn)
	Color(0.75, 0.70, 0.60),  # 1  island surface (sandy stone)
]

const SKIRT_DARKEN := 0.65  # underside rock is this much darker than the top

## Noise driving the rocky underside displacement. Seeded per level via
## set_noise_seed() or the inspector for variation between islands.
var _noise: FastNoiseLite = null

## Inspector-editable seed. Setting it in the editor re-runs _build() so the
## rocky underside updates live.
@export var noise_seed: int = 42:
	set(v):
		noise_seed = v
		if _noise != null:
			_noise.seed = v
			_build()

func set_noise_seed(s: int) -> void:
	noise_seed = s

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

	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 42  # levels can override via set_noise_seed(int)
		_noise.frequency = 0.18

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Underside built in its own SurfaceTool with smoothing disabled so
	# generate_normals() yields flat-shaded, faceted rock.
	var su := SurfaceTool.new()
	su.begin(Mesh.PRIMITIVE_TRIANGLES)
	su.set_smooth_group(-1)

	var half_w := COLS * CELL * 0.5  # 32.0
	var half_h := ROWS * CELL * 0.5  # 32.0

	var active: Array = active_map()
	var pal: Array = _palette_override if _palette_override.size() >= 2 else PALETTE

	var top_c: Color  = pal[1]
	var rock_c: Color = top_c.darkened(SKIRT_DARKEN).lerp(Color(0.25, 0.22, 0.20), 0.4)
	var cap_y: float  = SKIRT_RINGS[SKIRT_RINGS.size() - 1]

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

			# ── bottom cap (normal DOWN, at nominal keel depth) ──────────────
			_under_quad(su, Vector3(x0,cap_y,z0), Vector3(x1,cap_y,z0),
			                Vector3(x1,cap_y,z1), Vector3(x0,cap_y,z1), rock_c)

			# ── craggy curtains where a neighbour is void (off-grid counts) ──
			var void_n: bool = row == 0        or int(active[row-1][col]) <= 0
			var void_s: bool = row == ROWS - 1 or int(active[row+1][col]) <= 0
			var void_e: bool = col == COLS - 1 or int(active[row][col+1]) <= 0
			var void_w: bool = col == 0        or int(active[row][col-1]) <= 0

			if void_n:  # z− edge
				_curtain(su, Vector2(x1, z0), Vector2(x0, z0), rock_c)
			if void_s:  # z+ edge
				_curtain(su, Vector2(x0, z1), Vector2(x1, z1), rock_c)
			if void_e:  # x+ edge
				_curtain(su, Vector2(x1, z0), Vector2(x1, z1), rock_c)
			if void_w:  # x− edge
				_curtain(su, Vector2(x0, z1), Vector2(x0, z0), rock_c)

	var mesh := st.commit()
	su.generate_normals()
	su.commit(mesh)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.metallic = 0.0
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, mat)

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

## One boundary edge of the rim (a → b, left-to-right when viewed from outside
## the island): a curtain of noise-displaced rings from y=0 down to a ragged
## keel, plus a closing strip back to the rim at cap depth so the underside
## seams with the per-tile bottom caps.
func _curtain(su: SurfaceTool, a: Vector2, b: Vector2, color: Color) -> void:
	var last := SKIRT_RINGS.size() - 1
	for i in last:
		_under_quad(su, _rim_vert(a, i),        _rim_vert(b, i),
		                _rim_vert(b, i + 1),    _rim_vert(a, i + 1), color)
	var cap_y: float = SKIRT_RINGS[last]
	_under_quad(su, _rim_vert(a, last),         _rim_vert(b, last),
	                Vector3(b.x, cap_y, b.y),   Vector3(a.x, cap_y, a.y), color)

## Displaced position of a rim vertex at curtain ring `i`. Purely a function of
## the (x, z) rim position and ring index, so vertices shared between adjacent
## boundary edges (including corners) displace identically — no cracks.
func _rim_vert(p: Vector2, i: int) -> Vector3:
	if i == 0:
		return Vector3(p.x, 0.0, p.y)  # pinned: seams with the flat top
	var last := SKIRT_RINGS.size() - 1
	var ring_y: float = SKIRT_RINGS[i]
	# Outward = radially away from the island centre (the grid is origin-centred).
	var out := Vector3(p.x, 0.0, p.y).normalized()
	if not out.is_finite() or out.length_squared() < 0.5:
		out = Vector3.RIGHT
	# Horizontal bulge grows with depth, 0 → 0.8 m, modulated by noise.
	var t := float(i) / float(last)
	var h: float = 0.8 * t * (0.5 + 0.5 * _noise.get_noise_3d(p.x, ring_y, p.y))
	# Vertical jitter ±0.3 m per ring.
	var y: float = ring_y + 0.3 * _noise.get_noise_3d(p.x + 31.7, ring_y, p.y - 17.3)
	if i == last:
		# Ragged keel: extra downward-only jitter, kept at or below cap depth
		# so the closing strip and bottom caps stay watertight.
		y -= absf(_noise.get_noise_3d(p.x * 1.7, ring_y - 9.0, p.y * 1.7)) * 1.5
		y = minf(y, ring_y)
	return Vector3(p.x, y, p.y) + out * h

func _quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
		normal: Vector3, color: Color) -> void:
	for v: Vector3 in [v0, v1, v2, v0, v2, v3]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v)

## Underside quad: no explicit normals — generate_normals() flat-shades it.
func _under_quad(su: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3,
		v3: Vector3, color: Color) -> void:
	for v: Vector3 in [v0, v1, v2, v0, v2, v3]:
		su.set_color(color)
		su.add_vertex(v)
