## Procedural Synty MeadowForest scenery, generated at level load so all planes
## get a consistent pass with no per-scene authoring.
##
## Three layers, all COLLISION-FREE (parented under a "Scenery" node the level's
## prop-collision pass ignores), so none of it blocks movement or click-to-move:
##   1. a non-walkable backdrop ring of hills/cliffs just outside the arena,
##   2. dense ground-cover + grass via MultiMesh (this is the "ground texture" —
##      the MeadowForest pack ships no tiling ground bitmap, only alpha cards),
##   3. sparse bushes + rocks as plain instances.
##
## Placement is seeded from the plane id, so a scene looks identical each load
## and distinct from its neighbours. Scatter avoids points passed in `avoid`
## (props, characters) so nothing grows inside the well or on an NPC.
class_name Scenery
extends RefCounted

const _FBX := "res://assets/meshes/POLYGON_NatureBiomes_MeadowForest_SourceFiles_v2/Meadow_Source_Files/FBX/"

# Big silhouette meshes ringing the arena (non-walkable backdrop).
const _BACKDROP := [
	"SM_Env_Background_Hill_01",
	"SM_Env_Ground_Cliff_Large_01", "SM_Env_Ground_Cliff_Large_02",
	"SM_Env_Rock_Cliff_01", "SM_Env_Rock_Cliff_02", "SM_Env_Rock_Cliff_03",
]
# Flat patches that lie on the ground and read as texture (dense → MultiMesh).
const _GROUNDCOVER := [
	"SM_Env_Ground_Cover_01", "SM_Env_Ground_Cover_02", "SM_Env_Ground_Cover_03",
	"SM_Env_Rock_Ground_01", "SM_Env_Rock_Ground_02",
]
# Grass tufts (dense → MultiMesh).
const _GRASS := [
	"SM_Env_Grass_Med_Clump_01", "SM_Env_Grass_Med_Clump_02", "SM_Env_Grass_Med_Clump_03",
	"SM_Env_Grass_Tall_Clump_01", "SM_Env_Grass_Tall_Clump_02",
	"SM_Env_Grass_Short_Clump_01", "SM_Env_Grass_Short_Clump_02",
]
const _BUSHES := ["SM_Env_Bush_01", "SM_Env_Bush_02", "SM_Env_Bush_03", "SM_Env_Grass_Bush_01"]
const _ROCKS := [
	"SM_Env_Rock_01", "SM_Env_Rock_02", "SM_Env_Rock_03", "SM_Env_Rock_04",
	"SM_Env_Rock_05", "SM_Env_Rock_06", "SM_Env_Rock_Small_01",
	"SM_Env_Rock_Small_Pile_01", "SM_Env_Rock_Small_Pile_02",
]

static var _mesh_cache: Dictionary = {}  # gltf path → {mesh, mat}

## Populate `level` with scenery. `ground_mi` sizes the arena from its mesh AABB;
## `avoid` are world positions to keep scatter clear of; `seed_str` seeds layout.
static func generate(level: Node3D, ground_mi: MeshInstance3D, avoid: PackedVector3Array, seed_str: String) -> void:
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	level.add_child(scenery)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_str)

	var hx := 20.0
	var hz := 20.0
	if ground_mi != null and ground_mi.mesh != null:
		var ab := ground_mi.mesh.get_aabb()
		hx = ab.size.x * 0.5
		hz = ab.size.z * 0.5

	_backdrop(scenery, rng, maxf(hx, hz))
	_multimesh_scatter(scenery, rng, hx, hz, avoid, _GROUNDCOVER, 20, 0.8, 1.7, 1.5)
	_multimesh_scatter(scenery, rng, hx, hz, avoid, _GRASS, 30, 0.7, 1.4, 0.7)
	_instance_scatter(scenery, rng, hx, hz, avoid, _BUSHES, 14, 0.8, 1.5, 2.5)
	_instance_scatter(scenery, rng, hx, hz, avoid, _ROCKS, 20, 0.5, 1.4, 1.8)

# ── Layers ────────────────────────────────────────────────────────────────────

static func _backdrop(parent: Node3D, rng: RandomNumberGenerator, radius: float) -> void:
	for i in 16:
		var ps := _load_scene(_BACKDROP[rng.randi() % _BACKDROP.size()])
		if ps == null:
			continue
		var ang := TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		var r := radius + rng.randf_range(3.0, 11.0)
		var inst: Node3D = ps.instantiate()
		parent.add_child(inst)
		inst.position = Vector3(cos(ang) * r, rng.randf_range(-1.5, 0.0), sin(ang) * r)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(1.4, 3.0)
		inst.scale = Vector3(s, s, s)

static func _multimesh_scatter(parent: Node3D, rng: RandomNumberGenerator, hx: float, hz: float,
		avoid: PackedVector3Array, names: Array, per_variant: int,
		smin: float, smax: float, clear: float) -> void:
	for name in names:
		var data := _mesh_for(_FBX + name + ".gltf")
		if data["mesh"] == null:
			continue
		var xforms: Array[Transform3D] = []
		var attempts := 0
		while xforms.size() < per_variant and attempts < per_variant * 6:
			attempts += 1
			var pos := _rand_ground(rng, hx, hz)
			if _too_close(pos, avoid, clear):
				continue
			var s := rng.randf_range(smin, smax)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
			xforms.append(Transform3D(basis, pos))
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data["mesh"]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if data["mat"] != null:
			mmi.material_override = data["mat"]
		parent.add_child(mmi)

static func _instance_scatter(parent: Node3D, rng: RandomNumberGenerator, hx: float, hz: float,
		avoid: PackedVector3Array, names: Array, count: int,
		smin: float, smax: float, clear: float) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 6:
		attempts += 1
		var pos := _rand_ground(rng, hx, hz)
		if _too_close(pos, avoid, clear):
			continue
		var ps := _load_scene(names[rng.randi() % names.size()])
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		parent.add_child(inst)
		inst.position = pos
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(smin, smax)
		inst.scale = Vector3(s, s, s)
		placed += 1

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _rand_ground(rng: RandomNumberGenerator, hx: float, hz: float) -> Vector3:
	return Vector3(rng.randf_range(-hx + 2.0, hx - 2.0), 0.0, rng.randf_range(-hz + 2.0, hz - 2.0))

static func _too_close(pos: Vector3, avoid: PackedVector3Array, dist: float) -> bool:
	var d2 := dist * dist
	for a in avoid:
		var dx := pos.x - a.x
		var dz := pos.z - a.z
		if dx * dx + dz * dz < d2:
			return true
	return false

static func _load_scene(name: String) -> PackedScene:
	return load(_FBX + name + ".gltf") as PackedScene

## Pull the (mesh, material) out of a Synty gltf for MultiMesh use, cached.
static func _mesh_for(path: String) -> Dictionary:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var out := {"mesh": null, "mat": null}
	var ps := load(path) as PackedScene
	if ps != null:
		var inst := ps.instantiate()
		var mis: Array = inst.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var mi: MeshInstance3D = mis[0]
			out["mesh"] = mi.mesh
			out["mat"] = mi.get_active_material(0)
		inst.free()
	_mesh_cache[path] = out
	return out
