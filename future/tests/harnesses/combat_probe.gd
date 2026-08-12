## Diagnostic: reproduce "player runs away on enemy click" and "battle VFX
## at origin". Loads reach, moves a fight far from origin, simulates clicks
## through the real raycast, and inventories VFX node positions mid-fight.
extends Node

func _ready() -> void:
	_run()

func _run() -> void:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/reach.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.sarro.stats.max_hp = 900
	GameState.sarro.stats.current_hp = 900
	var player: CharacterBody3D = level.get_node("Characters/Sarro")
	var guard: CharacterBody3D = level.get_node("Enemies/PenGuard1")

	# Stage the fight well away from origin.
	player.global_position = Vector3(14, 0.1, -12)
	guard.global_position = Vector3(16, 0.1, -14)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 1) simulated click on the guard via the real ray
	var cam: Camera3D = level.get_node("CameraPivot/Camera3D")
	var screen := cam.unproject_position(guard.global_position + Vector3(0, 0.9, 0))
	player._handle_left_click(screen)
	await get_tree().physics_frame
	print("CLICK: target_enemy=%s  click_target=%s  waypoints=%s" % [
		player.target_enemy, player._click_target, player._waypoints])
	# what did the ray actually hit?
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		cam.project_ray_origin(screen),
		cam.project_ray_origin(screen) + cam.project_ray_normal(screen) * 200.0,
		player.CLICK_MASK, [player.get_rid()])
	var hit := space.intersect_ray(q)
	if hit:
		print("RAY HIT: %s at %s" % [hit["collider"], hit["position"]])

	# 1b) targeting UX: widget + outline right after the click, identified after 4s
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://.screenshots/targeting_fresh.png")
	var skin := guard.get_node_or_null("Skin")
	if skin != null:
		var outlined := false
		for mi: MeshInstance3D in skin.find_children("*", "MeshInstance3D", true, false):
			if mi.material_overlay != null:
				outlined = true
		print("OUTLINE applied: ", outlined)
	await get_tree().create_timer(4.5).timeout
	get_viewport().get_texture().get_image().save_png("res://.screenshots/targeting_identified.png")
	print("IDENTIFIED meta: ", guard.get_meta("wayfarer_identified", false))

	# 2) run the fight a few seconds, then inventory VFX positions
	guard.alerted(player)
	for i in 240:
		await get_tree().process_frame
	print("player at ", player.global_position, "  guard at ",
		guard.global_position if is_instance_valid(guard) else "dead")
	for n in get_tree().root.find_children("*", "Label3D", true, false):
		print("LABEL3D '%s' at %s" % [n.text, n.global_position])
	for n in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		if n.one_shot:
			print("BURST at %s (emitting=%s)" % [n.global_position, n.emitting])
	for n in get_tree().root.find_children("*", "OmniLight3D", true, false):
		print("LIGHT at %s energy=%.2f" % [n.global_position, n.light_energy])
	print("PROBE DONE")
	get_tree().quit(0)
