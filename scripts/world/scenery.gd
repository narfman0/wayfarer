## Procedural Synty MeadowForest scenery, generated at level load so all planes
## get a consistent pass with no per-scene authoring.
##
## Three layers, all COLLISION-FREE (parented under a "Scenery" node the level's
## prop-collision pass ignores), so none of it blocks movement or click-to-move:
##   1. a non-walkable backdrop ring of hills/cliffs just outside the arena,
##   2. dense ground-cover + grass scattered on the ground (this is the "ground
##      texture" — the MeadowForest pack ships no tiling ground bitmap),
##   3. sparse bushes + rocks.
##
## NOTE: this pack is authored in centimetres (a grass clump mesh is ~91 units
## tall) with no import-time correction, unlike the metre-scale Fantasy Kingdom
## props already in the scenes. Every instance is therefore scaled by _UNIT to
## bring it into world metres — without it, foliage renders ~100x too big and
## buries the characters.
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

const _FBX := "res://assets/meshes/POLYGON_NatureBiomes_MeadowForest_SourceFiles_v2/Meadow_Source_Files/FBX/"

## Centimetres → metres. All scale ranges below are multipliers on top of this,
## chosen against each mesh's real height (grass ~91u, bush ~243u, hill ~934u)
## so world sizes land in sensible metre ranges.
const _UNIT := 0.01

## Radius (m) of clear ground kept around every character position.
const _CHAR_CLEAR := 3.0

const _BACKDROP := [
	"SM_Env_Background_Hill_01",
	"SM_Env_Ground_Cliff_Large_01", "SM_Env_Ground_Cliff_Large_02",
	"SM_Env_Rock_Cliff_01", "SM_Env_Rock_Cliff_02", "SM_Env_Rock_Cliff_03",
]
# Only the low, flat cover patches — the Rock_Ground_* meshes are tall (~20m)
# rock formations, not ground cover, so they're excluded from in-arena scatter.
const _GROUNDCOVER := [
	"SM_Env_Ground_Cover_01", "SM_Env_Ground_Cover_02", "SM_Env_Ground_Cover_03",
]
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

## Populate `level` with scenery. `ground_mi` sizes the arena from its mesh AABB;
## `avoid` are prop positions to keep scatter clear of; `clear_centers` are
## character positions kept clear by a wider radius; `seed_str` seeds layout.
static func generate(level: Node3D, ground_mi: MeshInstance3D, avoid: PackedVector3Array,
		clear_centers: PackedVector3Array, seed_str: String) -> void:
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
	_scatter(scenery, rng, hx, hz, avoid, clear_centers, _GROUNDCOVER, 40, 0.3, 0.8, 1.2)
	_scatter(scenery, rng, hx, hz, avoid, clear_centers, _GRASS, 90, 0.5, 1.1, 0.7)
	_scatter(scenery, rng, hx, hz, avoid, clear_centers, _BUSHES, 14, 0.5, 1.0, 2.0)
	_scatter(scenery, rng, hx, hz, avoid, clear_centers, _ROCKS, 20, 0.25, 0.9, 1.5)

# ── Layers ────────────────────────────────────────────────────────────────────

# Backdrop meshes vary wildly in raw size (hills ~9m, cliffs ~40m at unit
# scale), so scale each to a target world height instead of a fixed multiplier,
# giving a consistent horizon ring.
static func _backdrop(parent: Node3D, rng: RandomNumberGenerator, radius: float) -> void:
	for i in 16:
		var ps := _load_scene(_BACKDROP[rng.randi() % _BACKDROP.size()])
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		parent.add_child(inst)
		var ang := TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		var r := radius + rng.randf_range(3.0, 11.0)
		inst.position = Vector3(cos(ang) * r, rng.randf_range(-1.5, 0.0), sin(ang) * r)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var target_h := rng.randf_range(12.0, 22.0)
		var s := target_h / _raw_height(inst)
		inst.scale = Vector3(s, s, s)

## World-space height of an instance's first mesh at unit node scale (metres,
## accounting for this pack's centimetre authoring).
static func _raw_height(inst: Node3D) -> float:
	var mis: Array = inst.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty() or (mis[0] as MeshInstance3D).mesh == null:
		return 100.0
	return maxf(0.01, (mis[0] as MeshInstance3D).mesh.get_aabb().size.y)

static func _scatter(parent: Node3D, rng: RandomNumberGenerator, hx: float, hz: float,
		avoid: PackedVector3Array, clear_centers: PackedVector3Array, names: Array,
		count: int, smin: float, smax: float, clear: float) -> void:
	var placed := 0
	var attempts := 0
	var cap := count * 8
	while placed < count and attempts < cap:
		attempts += 1
		var pos := _rand_ground(rng, hx, hz)
		if _too_close(pos, avoid, clear) or _too_close(pos, clear_centers, _CHAR_CLEAR):
			continue
		var ps := _load_scene(names[rng.randi() % names.size()])
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		parent.add_child(inst)
		inst.position = pos
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(smin, smax) * _UNIT
		inst.scale = Vector3(s, s, s)
		placed += 1

# ── Helpers ───────────────────────────────────────────────────────────────────

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

static func _load_scene(name: String) -> PackedScene:
	return load(_FBX + name + ".gltf") as PackedScene
