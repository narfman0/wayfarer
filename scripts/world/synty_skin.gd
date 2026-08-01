## Applies Synty atlas materials to imported GLB instances. The asset server
## cooks meshes only — colors come from each pack's atlas texture, which the
## meshes' UVs already map into.
class_name SyntySkin
extends RefCounted

static var _cache: Dictionary = {}

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
