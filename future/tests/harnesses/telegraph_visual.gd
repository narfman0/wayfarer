## Visual check for telegraph shapes: spawns all four on a gray ground with an
## overhead camera, screenshots mid-fill and at full fill, then quits.
## Run: xvfb-run godot res://future/tests/harnesses/telegraph_visual.tscn
extends Node3D

const _Telegraph = preload("res://scripts/combat/telegraph.gd")

func _ready() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.32)
	plane.material = mat
	ground.mesh = plane
	add_child(ground)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	add_child(light)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 18, 12)
	cam.rotation_degrees = Vector3(-55, 0, 0)
	cam.current = true
	add_child(cam)

	_Telegraph.show_circle(self, Vector3(-6, 0, -4), 2.5, 3.0)
	_Telegraph.show_line(self, Vector3(-1, 0, 1), Vector3(0, 0, -1), 8.0, 1.5, 3.0)
	_Telegraph.show_cone(self, Vector3(3, 0, 2), Vector3(1, 0, -1), 6.0, 60.0, 3.0)
	_Telegraph.show_donut(self, Vector3(8, 0, -4), 1.5, 3.5, 3.0)
	# The tint grammar: cyan soak, green hold, violet channel.
	_Telegraph.show_circle(self, Vector3(-10, 0, 4), 2.0, 3.0, _Telegraph.TINT_SOAK)
	_Telegraph.show_circle(self, Vector3(-14, 0, -2), 2.0, 3.0, _Telegraph.TINT_HOLD)
	_Telegraph.show_circle(self, Vector3(12, 0, 2), 2.6, 3.0, _Telegraph.TINT_VEIL)

	await get_tree().create_timer(1.5).timeout
	await _shot("res://future/tests/harnesses/telegraph_midfill.png")
	await get_tree().create_timer(1.4).timeout
	await _shot("res://future/tests/harnesses/telegraph_full.png")
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
