## Applies Synty atlas materials to imported GLB instances. The asset server
## cooks meshes only — colors come from each pack's atlas texture, which the
## meshes' UVs already map into.
##
## Editor workflow: drag any .glb from assets/meshes/ under Level/Props (or as
## a character "Skin") — apply_auto() textures it at runtime by detecting which
## pack the instance came from. It shows white in the editor viewport only.
class_name SyntySkin
extends RefCounted

## Pack-directory substring → atlas texture. Add a row when adopting a new pack.
const PACK_ATLASES := {
	"POLYGON_Fantasy_Kingdom": "res://assets/meshes/POLYGON_Fantasy_Kingdom_SourceFiles_v5/Source_Files/Textures/PolygonFantasyKingdom_Texture_01_A.png",
	"POLYGON_Fantasy_Characters": "res://assets/meshes/POLYGON_Fantasy_Characters_SourceFiles_v3/Source_Files/Textures/Polygon_Fantasy_Characters_Texture_01_A.png",
	"POLYGON_NatureBiomes_MeadowForest": "res://assets/meshes/POLYGON_NatureBiomes_MeadowForest_SourceFiles_v2/Meadow_Source_Files/Textures/PolygonNatureBiomes_Meadow_Texture_01_Saturated.png",
}

static var _cache: Dictionary = {}

## Texture a GLB instance using the atlas of whichever pack it was loaded from.
static func apply_auto(root: Node) -> void:
	var src := root.scene_file_path
	for key in PACK_ATLASES:
		if key in src:
			apply(root, PACK_ATLASES[key])
			return

## Texture every node in `container` that is a pack instance (e.g. Level/Props).
static func apply_auto_children(container: Node) -> void:
	for child in container.get_children():
		apply_auto(child)

static func apply(root: Node, texture_path: String) -> void:
	var mat: StandardMaterial3D = _cache.get(texture_path)
	if mat == null:
		var tex := load(texture_path) as Texture2D
		if tex == null:
			return
		mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 1.0
		_cache[texture_path] = mat
	if root is MeshInstance3D:
		root.material_override = mat
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
