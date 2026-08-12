## Authoring aid: loads planes and screenshots each from a wide ortho framing
## so the WHOLE arena is visible (the gallery frames the party close-up).
## Pass planes via env: OVERVIEW_PLANES="tamori,ashan" (default: all).
##   xvfb-run -a godot --rendering-driver vulkan \
##       res://future/tests/harnesses/overview_shot.tscn
extends Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	_run()

func _run() -> void:
	var want := OS.get_environment("OVERVIEW_PLANES")
	var planes: Array = []
	for plane_id: String in SceneManager.LEVELS:
		if want.is_empty() or plane_id in want.split(","):
			planes.append(plane_id)
	for plane_id: String in planes:
		GameState.sarro = null
		GameState.liris = null
		var level: Node3D = (load(SceneManager.LEVELS[plane_id]) as PackedScene).instantiate()
		add_child(level)
		for i in 30:
			await get_tree().process_frame
		var cam: Camera3D = level.get_node_or_null("CameraPivot/Camera3D")
		if cam != null:
			var ground := level.get_node_or_null("Level/Ground/GroundMesh") as MeshInstance3D
			var half := 28.0
			if ground != null and ground.mesh != null:
				half = maxf(ground.mesh.get_aabb().size.x, ground.mesh.get_aabb().size.z) * 0.5
			cam.size = half * 2.2  # whole arena + margin
		for i in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(
			"res://.screenshots/overview_%s.png" % plane_id)
		print("overview: ", plane_id)
		level.queue_free()
		await get_tree().process_frame
	print("OVERVIEW DONE")
	get_tree().quit(0)
