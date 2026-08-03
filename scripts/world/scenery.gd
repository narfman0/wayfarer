## Procedural per-plane scenery, generated at level load so all planes get a
## consistent pass with no per-scene authoring.
##
## WHAT a plane looks like is data (RECIPES below, keyed by plane_id); HOW it
## is placed is the shared generator. A recipe is:
##   backdrop — {names, count, h_min, h_max}: non-walkable horizon ring of
##              hills/cliffs/silhouettes just outside the arena, each instance
##              scaled to a target world height,
##   layers   — [{names, count, smin, smax, clear}]: in-arena scatter, scale
##              range is a multiplier on the pack's authoring unit, `clear` is
##              the exclusion radius (m) around props,
##   ground_color — optional; tints the level's flat ground mesh.
## Mesh names are "pack:SM_Name" refs into the PACKS registry, which records
## each pack's folder, file extension, and authoring unit (see the unit-scale
## history note on PACKS before adding a pack).
##
## All layers are COLLISION-FREE (parented under a "Scenery" node the level's
## prop-collision pass ignores), so nothing blocks movement or click-to-move.
##
## Everything is a plain instance (not MultiMesh): headless has no rendering
## server, so MultiMesh instance transforms can't be read back for verification,
## and plain nodes keep the whole pass testable. Counts stay modest so the node
## total is graybox-reasonable.
##
## Placement is seeded from the plane id, so a scene looks identical each load
## and distinct from its neighbours. Scatter avoids `avoid` points (props) and
## keeps a wide bubble around `clear_centers` (characters) so nothing grows in a
## prop or crowds/hides the party.
class_name Scenery
extends RefCounted

## Radius (m) of clear ground kept around every character position.
const _CHAR_CLEAR := 3.0

# ── Pack registry ─────────────────────────────────────────────────────────────
# unit: authoring scale → metres. Verify against a known mesh height before
# adding a pack (load it, check the AABB) — wrong unit = 100x scenery.

# Every current cook (both the .gltf texture pipeline and the .glb batch)
# bakes the Synty cm→m unit and axis correction onto a child node (0.01 scale +
# 90° X), so scene roots are metre-scale Y-up and unit is 1.0 across the board.
# The field stays because pack cooks have disagreed before — the old meadow
# cook shipped raw centimetres, and the 0.01 that once compensated for it
# became a 100x-too-small bug when the pack was re-cooked with the correction
# baked in. Probe a known mesh height before trusting a new pack.
const PACKS := {
	"meadow": {
		"dir": "res://assets/meshes/POLYGON_NatureBiomes_MeadowForest_SourceFiles_v2/Meadow_Source_Files/FBX/",
		"ext": ".gltf",
		"unit": 1.0,
	},
	"egypt": {
		"dir": "res://assets/meshes/POLYGON_AncientEgypt_SourceFiles_v2/SourceFiles/FBX/",
		"ext": ".gltf",
		"unit": 1.0,
	},
	"scifi": {
		"dir": "res://assets/meshes/POLYGON_Scifi_Space_SourceFiles_v2/SourceFiles/FBX/",
		"ext": ".gltf",
		"unit": 1.0,
	},
	"western": {
		"dir": "res://assets/meshes/POLYGON_Western_Pack_Source_Files_v4/SourceFiles/FBX/",
		"ext": ".gltf",
		"unit": 1.0,
	},
	"proto": {
		"dir": "res://assets/meshes/POLYGON_Prototype_SourceFiles_v4/SourceFiles/FBX/",
		"ext": ".gltf",
		"unit": 1.0,
	},
}

# ── Meadow vocabulary (shared by several recipes) ─────────────────────────────

const _MEADOW_BACKDROP := [
	"meadow:SM_Env_Background_Hill_01",
	"meadow:SM_Env_Ground_Cliff_Large_01", "meadow:SM_Env_Ground_Cliff_Large_02",
	"meadow:SM_Env_Rock_Cliff_01", "meadow:SM_Env_Rock_Cliff_02", "meadow:SM_Env_Rock_Cliff_03",
]
# Only the low, flat cover patches — the Rock_Ground_* meshes are tall (~20m)
# rock formations, not ground cover, so they're excluded from in-arena scatter.
const _MEADOW_GROUNDCOVER := [
	"meadow:SM_Env_Ground_Cover_01", "meadow:SM_Env_Ground_Cover_02", "meadow:SM_Env_Ground_Cover_03",
]
const _MEADOW_GRASS := [
	"meadow:SM_Env_Grass_Med_Clump_01", "meadow:SM_Env_Grass_Med_Clump_02", "meadow:SM_Env_Grass_Med_Clump_03",
	"meadow:SM_Env_Grass_Tall_Clump_01", "meadow:SM_Env_Grass_Tall_Clump_02",
	"meadow:SM_Env_Grass_Short_Clump_01", "meadow:SM_Env_Grass_Short_Clump_02",
]
const _MEADOW_BUSHES := [
	"meadow:SM_Env_Bush_01", "meadow:SM_Env_Bush_02", "meadow:SM_Env_Bush_03",
	"meadow:SM_Env_Grass_Bush_01",
]
const _MEADOW_ROCKS := [
	"meadow:SM_Env_Rock_01", "meadow:SM_Env_Rock_02", "meadow:SM_Env_Rock_03",
	"meadow:SM_Env_Rock_04", "meadow:SM_Env_Rock_05", "meadow:SM_Env_Rock_06",
	"meadow:SM_Env_Rock_Small_01",
	"meadow:SM_Env_Rock_Small_Pile_01", "meadow:SM_Env_Rock_Small_Pile_02",
]

# ── Recipes ───────────────────────────────────────────────────────────────────

## The original all-planes look; also the fallback for any plane_id without an
## entry in RECIPES.
const _MEADOW_RECIPE := {
	"backdrop": {"names": _MEADOW_BACKDROP, "count": 16, "h_min": 12.0, "h_max": 22.0},
	"layers": [
		{"names": _MEADOW_GROUNDCOVER, "count": 40, "smin": 0.3, "smax": 0.8, "clear": 1.2},
		{"names": _MEADOW_GRASS, "count": 90, "smin": 0.5, "smax": 1.1, "clear": 0.7},
		{"names": _MEADOW_BUSHES, "count": 14, "smin": 0.5, "smax": 1.0, "clear": 2.0},
		{"names": _MEADOW_ROCKS, "count": 20, "smin": 0.25, "smax": 0.9, "clear": 1.5},
	],
}

# ── Per-plane vocabularies ────────────────────────────────────────────────────

const _SCIFI_CRATES := ["scifi:SM_Prop_Crate_01", "scifi:SM_Prop_Crate_02", "scifi:SM_Prop_Crate_Wide_01"]
const _SCIFI_HARDWARE := [
	"scifi:SM_Prop_Detail_Pipes_01", "scifi:SM_Prop_Detail_Pipes_02", "scifi:SM_Prop_Detail_Pipes_03",
	"scifi:SM_Prop_Wires_01", "scifi:SM_Prop_Wires_02", "scifi:SM_Prop_Wires_03",
	"scifi:SM_Prop_Wires_04", "scifi:SM_Prop_Wires_05",
]
const _SCIFI_DEBRIS := [
	"scifi:SM_Env_Rubble_Pile_01", "scifi:SM_Env_Rubble_Pile_02", "scifi:SM_Env_Debris_Pipe_01",
]
const _SCIFI_WRECKAGE := [
	"scifi:SM_Env_Debris_Shell_01", "scifi:SM_Env_Debris_Shell_02", "scifi:SM_Env_Debris_Shell_03",
	"scifi:SM_Env_Debris_Structure_01", "scifi:SM_Env_Debris_Structure_02", "scifi:SM_Env_Debris_Structure_03",
]

const _EGYPT_STATUES := [
	"egypt:Props/SM_Prop_Statue_01", "egypt:Props/SM_Prop_Statue_02", "egypt:Props/SM_Prop_Statue_03",
	"egypt:Props/SM_Prop_Statue_04", "egypt:Props/SM_Prop_Statue_05", "egypt:Props/SM_Prop_Statue_06",
	"egypt:Props/SM_Prop_Statue_Damaged_01",
]
const _EGYPT_PILLARS := [
	"egypt:Buildings/SM_Bld_Pillar_Ornate_01", "egypt:Buildings/SM_Bld_Pillar_Ornate_02",
	"egypt:Buildings/SM_Bld_Pillar_Ornate_Damaged_01", "egypt:Buildings/SM_Bld_Pillar_Ornate_Damaged_02",
]
const _EGYPT_RUBBLE := [
	"egypt:Props/SM_Prop_Limestone_Rubble_01", "egypt:Props/SM_Prop_Limestone_Rubble_02",
	"egypt:Props/SM_Prop_Limestone_Rubble_03", "egypt:Props/SM_Prop_Limestone_Block_01",
	"egypt:Props/SM_Prop_Limestone_Block_02",
]
const _EGYPT_DEAD_BUSHES := [
	"egypt:Environment/SM_Env_Bush_Dead_01", "egypt:Environment/SM_Env_Bush_Dead_02",
	"egypt:Environment/SM_Env_Bush_Dead_03", "egypt:Environment/SM_Env_Bush_Dead_04",
]
const _EGYPT_GARDEN_TREES := [
	"egypt:Environment/SM_Env_Tree_Palm_01", "egypt:Environment/SM_Env_Tree_Palm_02",
	"egypt:Environment/SM_Env_Tree_Palm_03", "egypt:Environment/SM_Env_Tree_01",
	"egypt:Environment/SM_Env_Tree_02",
]
const _EGYPT_FLOWERS := [
	"egypt:Environment/SM_Env_Flowers_01", "egypt:Environment/SM_Env_Flowers_02",
	"egypt:Environment/SM_Env_Flowers_03", "egypt:Environment/SM_Env_Flowers_04",
	"egypt:Environment/SM_Env_Flowers_05", "egypt:Environment/SM_Env_Flowers_06",
]
const _EGYPT_BUSHES := [
	"egypt:Environment/SM_Env_Bush_01", "egypt:Environment/SM_Env_Bush_02",
	"egypt:Environment/SM_Env_Bush_Group_01", "egypt:Environment/SM_Env_Bush_Group_02",
	"egypt:Environment/SM_Env_Bush_Group_03",
]
const _EGYPT_VESSELS := [
	"egypt:Props/SM_Prop_Vase_01", "egypt:Props/SM_Prop_Vase_02", "egypt:Props/SM_Prop_Vase_03",
	"egypt:Props/SM_Prop_Plinth_01", "egypt:Props/SM_Prop_Plinth_02",
]
# Slim monumental silhouettes only — the pyramid blocks are ~2:1 wide and at
# ring distance their footprint reaches the camera.
const _EGYPT_BACKDROP := [
	"egypt:Environment/SM_Env_Rock_Wall_01", "egypt:Environment/SM_Env_Rock_Wall_02",
	"egypt:Buildings/SM_Bld_Pillar_Ornate_Large_01", "egypt:Buildings/SM_Bld_Pillar_Ornate_Large_02",
	"egypt:Buildings/SM_Bld_Archway_Ornate_01",
]

const _WESTERN_CLIFFS := [
	"western:SM_Env_Cliff_Straight_01", "western:SM_Env_Cliff_Straight_02",
	"western:SM_Env_Cliff_Curve_01", "western:SM_Env_Cliff_Curve_02", "western:SM_Env_Cliff_Cap_01",
]
const _WESTERN_CARGO := [
	"western:SM_Prop_Barrel_01", "western:SM_Prop_Barrel_02", "western:SM_Prop_Barrel_Half_01",
	"western:SM_Prop_Crate_01",
	"western:SM_Prop_Wood_Pile_01", "western:SM_Prop_Wood_Pile_02", "western:SM_Prop_Wood_Pile_03",
]
const _WESTERN_ROCKS := [
	"western:SM_Env_Rock_01", "western:SM_Env_Rock_02", "western:SM_Env_Rock_Round_01",
	"western:SM_Env_Rock_Round_02", "western:SM_Env_Rocks_01", "western:SM_Env_Rocks_02",
]
const _WESTERN_GRASS := ["western:SM_Env_Grass_01", "western:SM_Env_Grass_02", "western:SM_Env_Grass_03"]
const _WESTERN_LANTERNS := ["western:SM_Prop_Lantern_01", "western:SM_Prop_Lantern_02"]

const _PROTO_BACKDROP := [
	"proto:SM_Generic_Mountains_Soft_01", "proto:SM_Generic_Mountains_Grass_01",
	"proto:SM_Generic_Cloud_01", "proto:SM_Generic_Cloud_02", "proto:SM_Generic_Cloud_03",
]
const _PROTO_PRIMITIVES := [
	"proto:SM_Primitive_Cube_01", "proto:SM_Primitive_Cube_02", "proto:SM_Primitive_Cube_03",
	"proto:SM_Primitive_Sphere_01", "proto:SM_Primitive_Sphere_02",
	"proto:SM_Primitive_Cone_01", "proto:SM_Primitive_Cone_02",
	"proto:SM_Primitive_Cylander_01", "proto:SM_Primitive_Cylander_02",
]
const _PROTO_TREES := [
	"proto:SM_Prop_Tree_Square_01", "proto:SM_Prop_Tree_Square_02",
	"proto:SM_Prop_Tree_Round_01", "proto:SM_Prop_Tree_Round_02", "proto:SM_Prop_Tree_Pine_01",
]
const _PROTO_ROCKS := ["proto:SM_Generic_Small_Rocks_01", "proto:SM_Generic_Small_Rocks_02"]

const _SCIFI_ASTEROIDS := [
	"scifi:SM_Env_Asteroid_01", "scifi:SM_Env_Asteroid_02", "scifi:SM_Env_Asteroid_03",
	"scifi:SM_Env_Asteroid_04", "scifi:SM_Env_Asteroid_05",
]

## plane_id → recipe. Planes without an entry get the meadow fallback — the
## Tamori planes keep it on purpose: the meadow IS their identity.
const RECIPES := {
	# Big empty grassland scarred by extraction: sparser meadow growth, with
	# industrial litter accumulating between the tufts.
	"reach": {
		"ground_color": Color(0.35, 0.36, 0.28),
		"backdrop": {"names": _MEADOW_BACKDROP, "count": 14, "h_min": 10.0, "h_max": 18.0},
		"layers": [
			{"names": _MEADOW_GROUNDCOVER, "count": 24, "smin": 0.3, "smax": 0.7, "clear": 1.2},
			{"names": _MEADOW_GRASS, "count": 50, "smin": 0.4, "smax": 0.9, "clear": 0.7},
			{"names": _SCIFI_CRATES, "count": 10, "smin": 0.9, "smax": 1.1, "clear": 1.5},
			{"names": _SCIFI_HARDWARE, "count": 12, "smin": 0.8, "smax": 1.1, "clear": 1.5},
			{"names": _SCIFI_DEBRIS, "count": 8, "smin": 0.8, "smax": 1.2, "clear": 2.0},
		],
	},
	# Monumental ruins at night, built around the Veil: oversized statues and
	# pillars, limestone rubble, everything organic long dead.
	"kaveth": {
		"ground_color": Color(0.22, 0.2, 0.26),
		"backdrop": {"names": _EGYPT_BACKDROP, "count": 14, "h_min": 14.0, "h_max": 24.0},
		"layers": [
			{"names": _EGYPT_STATUES, "count": 8, "smin": 1.2, "smax": 2.0, "clear": 2.0},
			{"names": _EGYPT_PILLARS, "count": 10, "smin": 1.0, "smax": 1.5, "clear": 2.0},
			{"names": _EGYPT_RUBBLE, "count": 16, "smin": 0.8, "smax": 1.3, "clear": 1.2},
			{"names": _EGYPT_VESSELS, "count": 8, "smin": 0.9, "smax": 1.2, "clear": 1.0},
			{"names": _EGYPT_DEAD_BUSHES, "count": 14, "smin": 0.8, "smax": 1.2, "clear": 0.8},
		],
	},
	# Frontier port: salt-bleached cargo among sea-cliff rocks and dry tufts.
	"verath": {
		"ground_color": Color(0.45, 0.42, 0.36),
		"backdrop": {"names": _WESTERN_CLIFFS, "count": 14, "h_min": 10.0, "h_max": 16.0},
		"layers": [
			{"names": _WESTERN_CARGO, "count": 14, "smin": 0.9, "smax": 1.1, "clear": 1.2},
			{"names": _WESTERN_ROCKS, "count": 14, "smin": 0.7, "smax": 1.2, "clear": 1.2},
			{"names": _WESTERN_GRASS, "count": 26, "smin": 0.8, "smax": 1.2, "clear": 0.7},
			{"names": _WESTERN_LANTERNS, "count": 4, "smin": 1.0, "smax": 1.0, "clear": 2.0},
		],
	},
	# Abstract non-place: graybox AS aesthetic — primitives and placeholder
	# trees scattered like an unfinished thought, clouds parked at eye level.
	"between": {
		"ground_color": Color(0.5, 0.5, 0.55),
		"backdrop": {"names": _PROTO_BACKDROP, "count": 12, "h_min": 8.0, "h_max": 16.0},
		"layers": [
			{"names": _PROTO_PRIMITIVES, "count": 18, "smin": 0.6, "smax": 1.6, "clear": 1.5},
			{"names": _PROTO_TREES, "count": 8, "smin": 0.8, "smax": 1.2, "clear": 2.0},
			{"names": _PROTO_ROCKS, "count": 10, "smin": 0.8, "smax": 1.2, "clear": 1.0},
		],
	},
	# Settled golden-hour gardens: the only plane with no enemies, so it gets
	# the densest growth — palms, flowers, kept vessels.
	"ashan": {
		"ground_color": Color(0.5, 0.52, 0.3),
		"backdrop": {"names": _MEADOW_BACKDROP, "count": 14, "h_min": 10.0, "h_max": 16.0},
		"layers": [
			{"names": _EGYPT_GARDEN_TREES, "count": 10, "smin": 0.7, "smax": 1.0, "clear": 2.5},
			{"names": _EGYPT_FLOWERS, "count": 30, "smin": 0.9, "smax": 1.3, "clear": 0.6},
			{"names": _EGYPT_BUSHES, "count": 14, "smin": 0.8, "smax": 1.2, "clear": 1.0},
			{"names": _MEADOW_GRASS, "count": 40, "smin": 0.5, "smax": 1.0, "clear": 0.7},
			{"names": _EGYPT_VESSELS, "count": 8, "smin": 0.9, "smax": 1.1, "clear": 1.0},
		],
	},
	# Cael's apparatus mid-operation: wreckage and torn structure under an
	# asteroid horizon; the plane is coming apart at the seams.
	"convergence": {
		"ground_color": Color(0.24, 0.18, 0.3),
		"backdrop": {"names": _SCIFI_ASTEROIDS, "count": 12, "h_min": 14.0, "h_max": 24.0},
		"layers": [
			{"names": _SCIFI_WRECKAGE, "count": 12, "smin": 0.8, "smax": 1.2, "clear": 2.0},
			{"names": _PROTO_PRIMITIVES, "count": 10, "smin": 0.6, "smax": 1.4, "clear": 1.5},
			{"names": _SCIFI_HARDWARE, "count": 10, "smin": 0.8, "smax": 1.1, "clear": 1.5},
			{"names": _SCIFI_DEBRIS, "count": 10, "smin": 0.8, "smax": 1.2, "clear": 1.5},
		],
	},
}

# ── Generator ─────────────────────────────────────────────────────────────────

## Populate `level` with scenery for `plane_id` (also the layout seed).
## `ground_mi` sizes the arena from its mesh AABB; `avoid` are prop positions
## to keep scatter clear of; `clear_centers` are character positions kept clear
## by a wider radius.
## Split scenes share their plane's recipe (layouts still differ — the seed
## is the full plane_id).
const _RECIPE_ALIASES := {
	"reach_rig": "reach",
	"kaveth_vault": "kaveth",
	"verath_seawall": "verath",
}

static func generate(level: Node3D, ground_mi: MeshInstance3D, avoid: PackedVector3Array,
		clear_centers: PackedVector3Array, plane_id: String) -> void:
	var recipe: Dictionary = RECIPES.get(_RECIPE_ALIASES.get(plane_id, plane_id), _MEADOW_RECIPE)
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	level.add_child(scenery)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(plane_id)

	var hx := 20.0
	var hz := 20.0
	if ground_mi != null and ground_mi.mesh != null:
		var ab := ground_mi.mesh.get_aabb()
		hx = ab.size.x * 0.5
		hz = ab.size.z * 0.5

	if recipe.has("ground_color") and ground_mi != null:
		_tint_ground(ground_mi, recipe["ground_color"])
	if recipe.has("backdrop"):
		_backdrop(scenery, rng, maxf(hx, hz), recipe["backdrop"], clear_centers)
	for layer in recipe.get("layers", []):
		_scatter(scenery, rng, hx, hz, avoid, clear_centers, layer)

# ── Layers ────────────────────────────────────────────────────────────────────

# Widest a backdrop piece may get. Height-only normalization explodes
# wide-flat meshes (Background_Hill is 17 m wide but 1.9 m tall — scaling it
# to a 17 m TALL target makes a 150 m monster that swallows the arena, camera
# included), so the footprint caps the scale.
const _BACKDROP_MAX_W := 32.0

# Backdrop meshes vary wildly in raw size and proportion, so scale each toward
# a target world height — clamped by footprint — for a consistent horizon ring.
static func _backdrop(parent: Node3D, rng: RandomNumberGenerator, radius: float,
		spec: Dictionary, clear_centers: PackedVector3Array) -> void:
	var names: Array = spec["names"]
	var count: int = spec["count"]
	for i in count:
		var ps := _load_scene(names[rng.randi() % names.size()])
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		parent.add_child(inst)
		var ang := TAU * i / count + rng.randf_range(-0.12, 0.12)
		var r := radius + rng.randf_range(6.0, 14.0)
		var y := rng.randf_range(-1.5, 0.0)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var target_h := rng.randf_range(spec["h_min"], spec["h_max"])
		var ab := _world_aabb(inst)
		var s := minf(target_h / maxf(0.01, ab.size.y),
			_BACKDROP_MAX_W / maxf(0.01, maxf(ab.size.x, ab.size.z)))
		inst.scale = Vector3(s, s, s)
		# Pieces near a spawn point can engulf the party — or the CAMERA,
		# which orbits ~16 m up-and-back from the player and pokes past the
		# arena edge when a spawn sits in a corner (the Anchor Tear). Slide
		# the piece outward along its ray until its footprint clears every
		# character position by the camera boom. Deterministic — no extra RNG.
		var footprint_r: float = maxf(ab.size.x, ab.size.z) * s * 0.5
		var pos := Vector3(cos(ang) * r, y, sin(ang) * r)
		for _try in 8:
			if not _too_close(pos, clear_centers, footprint_r + 16.0):
				break
			r += 5.0
			pos = Vector3(cos(ang) * r, y, sin(ang) * r)
		inst.position = pos

## World-space AABB of an instance's first mesh at unit root scale. The mesh
## AABB is transformed through every node below the root — the .glb cook bakes
## its unit/axis correction (0.01 scale, 90° X) on a child node, so the raw
## AABB alone is centimetre Z-up garbage for those packs.
static func _world_aabb(inst: Node3D) -> AABB:
	var mis: Array = inst.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty() or (mis[0] as MeshInstance3D).mesh == null:
		return AABB(Vector3.ZERO, Vector3(100.0, 100.0, 100.0))
	var mi := mis[0] as MeshInstance3D
	var xf := mi.transform
	var n: Node = mi.get_parent()
	while n != null and n != inst and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf * mi.mesh.get_aabb()

static func _world_height(inst: Node3D) -> float:
	return maxf(0.01, _world_aabb(inst).size.y)

static func _scatter(parent: Node3D, rng: RandomNumberGenerator, hx: float, hz: float,
		avoid: PackedVector3Array, clear_centers: PackedVector3Array,
		layer: Dictionary) -> void:
	var names: Array = layer["names"]
	var count: int = layer["count"]
	var clear: float = layer["clear"]
	var placed := 0
	var attempts := 0
	var cap := count * 8
	while placed < count and attempts < cap:
		attempts += 1
		var pos := _rand_ground(rng, hx, hz)
		if _too_close(pos, avoid, clear) or _too_close(pos, clear_centers, _CHAR_CLEAR):
			continue
		var ref: String = names[rng.randi() % names.size()]
		var ps := _load_scene(ref)
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		parent.add_child(inst)
		inst.position = pos
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var s: float = rng.randf_range(layer["smin"], layer["smax"]) * _pack_unit(ref)
		inst.scale = Vector3(s, s, s)
		placed += 1

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _tint_ground(ground_mi: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	ground_mi.material_override = mat

static func _rand_ground(rng: RandomNumberGenerator, hx: float, hz: float) -> Vector3:
	return Vector3(rng.randf_range(-hx + 2.0, hx - 2.0), 0.0, rng.randf_range(-hz + 2.0, hz - 2.0))

static func _too_close(pos: Vector3, points: PackedVector3Array, dist: float) -> bool:
	var d2 := dist * dist
	for a in points:
		var dx := pos.x - a.x
		var dz := pos.z - a.z
		if dx * dx + dz * dz < d2:
			return true
	return false

## Resolve a "pack:SM_Name" ref via the PACKS registry.
static func _load_scene(ref: String) -> PackedScene:
	var parts := ref.split(":")
	var pack: Dictionary = PACKS[parts[0]]
	return load(str(pack["dir"], parts[1], pack["ext"])) as PackedScene

static func _pack_unit(ref: String) -> float:
	return PACKS[ref.split(":")[0]]["unit"]
