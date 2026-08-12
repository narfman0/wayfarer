## Visual gallery: loads every plane, lets it render a moment, then saves a
## screenshot per plane to res://.screenshots/ (inside the project — the
## flatpak sandbox can't write anywhere else). Needs a display; run under
## Xvfb with the Forward+ renderer — the Compatibility renderer silently
## drops SSAO/SSIL/SDFGI/volumetrics, so opengl3 screenshots lie:
##   xvfb-run -a godot --rendering-driver vulkan \
##       res://future/tests/harnesses/plane_gallery.tscn
extends Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	_run()

func _run() -> void:
	for plane_id: String in SceneManager.LEVELS:
		GameState.sarro = null
		GameState.liris = null
		var level: Node3D = (load(SceneManager.LEVELS[plane_id]) as PackedScene).instantiate()
		add_child(level)
		# let particles preprocess, tweens settle, and a few frames render
		for i in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://.screenshots/%s.png" % plane_id)
		print("shot: ", plane_id)
		level.queue_free()
		await get_tree().process_frame
	print("GALLERY DONE")
	get_tree().quit(0)
