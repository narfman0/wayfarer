@tool
extends EditorScenePostImport

## Synty POLYGON source glTFs ship every LOD level (and separate Branches LODs)
## as sibling mesh nodes rather than via the MSFT_lod extension. Godot has no
## way to know these are alternates, so it imports and renders all of them
## stacked on top of each other — the low-poly LOD3 crossboard billboard ends
## up as two vertical planes bisecting the full-detail mesh, with overlapping
## canopy/trunk LODs producing z-fighting and muddy colors.
##
## This post-import step keeps only the *_LOD0 nodes (full detail) and drops
## LOD1+. Godot's own `meshes/generate_lods=true` then produces real LODs.

func _post_import(scene: Node) -> Object:
	_strip(scene)
	return scene


func _strip(node: Node) -> void:
	# Iterate over a copy so freeing children mid-loop is safe.
	for child in node.get_children():
		if _is_superseded_lod(child.name):
			node.remove_child(child)
			child.free()
		else:
			_strip(child)


## True for _LOD1 / _LOD2 / _LOD3 …, false for _LOD0 and non-LOD names.
func _is_superseded_lod(node_name: String) -> bool:
	var idx := node_name.find("_LOD")
	if idx == -1:
		return false
	var suffix := node_name.substr(idx + 4)
	return suffix.is_valid_int() and suffix.to_int() != 0
