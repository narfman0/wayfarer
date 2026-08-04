## Procedural tilemap terrain: integer height grid → mesh + collision.
## Each cell is CELL×CELL metres. Height steps are STEP metres.
## Height 1 = y=0 (player ground level). Heights 2/3 are raised, 0 is sunken.
## Wall faces are generated between adjacent cells at different heights.
## Call _build() from _ready() — collision is created via create_trimesh_collision().
class_name TiledTerrain
extends Node3D

const CELL  := 4.0   # metres per grid cell
const STEP  := 2.0   # metres per height level (height 1 → y=0, height 2 → y=2, etc.)
const COLS  := 20
const ROWS  := 20

## Flat colours per height level: 0=sunken, 1=grass, 2=earth, 3=stone
const PALETTE := [
	Color(0.14, 0.25, 0.12),  # 0  sunken / shadow
	Color(0.27, 0.49, 0.20),  # 1  main grass
	Color(0.40, 0.35, 0.22),  # 2  raised earth
	Color(0.50, 0.46, 0.36),  # 3  rocky hilltop
]
const WALL_DARKEN := 0.30  # wall faces are this much darker than the top

## 20×20 height map for Tamori. Row 0 = north (z=−40), row 19 = south (z=+36).
## Col 0 = west (x=−40), col 19 = east (x=+36).
## Centre village (rows 7–12, cols 1–18) is all height-1 ground.
## Portal is at col 19, row 10 (height 1 → y=0). NPCs unchanged.
const MAP: Array = [
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # row 0  z=−40 north hills
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # row 1
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # row 2
	[2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,2],  # row 3
	[2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,2],  # row 4
	[2,2,2,2,2,3,3,3,3,3,3,3,3,2,2,2,2,2,2,2],  # row 5
	[2,2,2,2,2,2,2,2,2,3,3,2,2,2,2,2,2,2,2,2],  # row 6
	[2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2],  # row 7  village north edge
	[2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2],  # row 8
	[2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2],  # row 9
	[2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],  # row 10 portal at col 19
	[2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2],  # row 11
	[2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2],  # row 12
	[2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2],  # row 13
	[2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2],  # row 14
	[2,2,2,2,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2],  # row 15
	[2,2,2,2,2,2,1,1,1,1,1,2,2,2,2,2,2,2,2,2],  # row 16
	[2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2],  # row 17
	[3,3,3,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3],  # row 18
	[3,3,3,3,3,3,2,2,2,2,2,2,2,3,3,3,3,3,3,3],  # row 19 south hills
]

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_w := COLS * CELL * 0.5  # 40.0
	var half_h := ROWS * CELL * 0.5  # 40.0

	for row in ROWS:
		for col in COLS:
			var h: int    = MAP[row][col]
			var x0 := col * CELL - half_w
			var z0 := row * CELL - half_h
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			var y  := (h - 1) * STEP  # height 1 → y=0

			var top_c: Color  = PALETTE[h]
			var wall_c: Color = top_c.darkened(WALL_DARKEN)

			# ── top face (normal UP) ─────────────────────────────────────────
			_quad(st, Vector3(x0,y,z1), Vector3(x1,y,z1),
			          Vector3(x1,y,z0), Vector3(x0,y,z0), Vector3.UP, top_c)

			# ── wall faces (one section per height step) ─────────────────────
			var nh_n: int = MAP[row-1][col] if row > 0        else 0
			var nh_s: int = MAP[row+1][col] if row < ROWS - 1 else 0
			var nh_e: int = MAP[row][col+1] if col < COLS - 1 else 0
			var nh_w: int = MAP[row][col-1] if col > 0        else 0

			# North wall (z−, normal 0,0,−1)
			if h > nh_n:
				for s in range(nh_n, h):
					var yl := (s - 1) * STEP
					var yu := s * STEP
					_quad(st, Vector3(x1,yu,z0), Vector3(x0,yu,z0),
					          Vector3(x0,yl,z0), Vector3(x1,yl,z0),
					          Vector3(0,0,-1), wall_c)

			# South wall (z+, normal 0,0,+1)
			if h > nh_s:
				for s in range(nh_s, h):
					var yl := (s - 1) * STEP
					var yu := s * STEP
					_quad(st, Vector3(x0,yu,z1), Vector3(x1,yu,z1),
					          Vector3(x1,yl,z1), Vector3(x0,yl,z1),
					          Vector3(0,0,1), wall_c)

			# East wall (x+, normal +1,0,0)
			if h > nh_e:
				for s in range(nh_e, h):
					var yl := (s - 1) * STEP
					var yu := s * STEP
					_quad(st, Vector3(x1,yu,z0), Vector3(x1,yu,z1),
					          Vector3(x1,yl,z1), Vector3(x1,yl,z0),
					          Vector3(1,0,0), wall_c)

			# West wall (x−, normal −1,0,0)
			if h > nh_w:
				for s in range(nh_w, h):
					var yl := (s - 1) * STEP
					var yu := s * STEP
					_quad(st, Vector3(x0,yu,z1), Vector3(x0,yu,z0),
					          Vector3(x0,yl,z0), Vector3(x0,yl,z1),
					          Vector3(-1,0,0), wall_c)

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
