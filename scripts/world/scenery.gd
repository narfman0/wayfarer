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
## each pack's folder, file extension, and authoring unit — packs disagree on
## all three (MeadowForest is authored in centimetres; a grass clump is ~91
## units tall — see _raw asset lesson in git history).
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

const PACKS := {
	"meadow": {
		"dir": "res://assets/meshes/POLYGON_NatureBiomes_MeadowForest_SourceFiles_v2/Meadow_Source_Files/FBX/",
		"ext": ".gltf",
		"unit": 0.01,
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

## plane_id → recipe. Planes without an entry get the meadow fallback.
const RECIPES := {}

# ── Generator ─────────────────────────────────────────────────────────────────

## Populate `level` with scenery for `plane_id` (also the layout seed).
## `ground_mi` sizes the arena from its mesh AABB; `avoid` are prop positions
## to keep scatter clear of; `clear_centers` are character positions kept clear
## by a wider radius.
static func generate(level: Node3D, ground_mi: MeshInstance3D, avoid: PackedVector3Array,
		clear_centers: PackedVector3Array, plane_id: String) -> void:
	var recipe: Dictionary = RECIPES.get(plane_id, _MEADOW_RECIPE)
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
		_backdrop(scenery, rng, maxf(hx, hz), recipe["backdrop"])
	for layer in recipe.get("layers", []):
		_scatter(scenery, rng, hx, hz, avoid, clear_centers, layer)

# ── Layers ────────────────────────────────────────────────────────────────────

# Backdrop meshes vary wildly in raw size (hills ~9m, cliffs ~40m at unit
# scale), so scale each to a target world height instead of a fixed multiplier,
# giving a consistent horizon ring.
static func _backdrop(parent: Node3D, rng: RandomNumberGenerator, radius: float,
		spec: Dictionary) -> void:
	var names: Array = spec["names"]
	var count: int = spec["count"]
	for i in count:
		var ps := _load_scene(names[rng.randi() % names.size()])
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		parent.add_child(inst)
		var ang := TAU * i / count + rng.randf_range(-0.12, 0.12)
		var r := radius + rng.randf_range(3.0, 11.0)
		inst.position = Vector3(cos(ang) * r, rng.randf_range(-1.5, 0.0), sin(ang) * r)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var target_h := rng.randf_range(spec["h_min"], spec["h_max"])
		var s := target_h / _raw_height(inst)
		inst.scale = Vector3(s, s, s)

## World-space height of an instance's first mesh at unit node scale.
static func _raw_height(inst: Node3D) -> float:
	var mis: Array = inst.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty() or (mis[0] as MeshInstance3D).mesh == null:
		return 100.0
	return maxf(0.01, (mis[0] as MeshInstance3D).mesh.get_aabb().size.y)

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
