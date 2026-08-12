extends SceneTree
func _init() -> void:
	for p in [
		"res://assets/meshes/POLYGON_Fantasy_Characters_SourceFiles_v3/Source_Files/Characters/SK_Character_Male_Peasant_01.gltf",
		"res://assets/meshes/POLYGON_Dark_Fantasy_SourceFiles_v3/SourceFiles/FBX/Characters/Unreal_Characters/SK_Chr_Skeleton_01.gltf",
	]:
		var scene = load(p)
		if scene == null:
			print("LOAD FAIL: ", p); continue
		var inst: Node = scene.instantiate()
		print("=== ", p.get_file())
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			var aabb := mi.mesh.get_aabb() if mi.mesh != null else AABB()
			print("  mesh %s aabb size=%s  node_scale=%s" % [mi.name, aabb.size, mi.scale])
		for sk: Skeleton3D in inst.find_children("*", "Skeleton3D", true, false):
			print("  skeleton bones=%d root_rest=%s" % [sk.get_bone_count(), sk.get_bone_rest(0).origin])
		inst.free()
	quit(0)
