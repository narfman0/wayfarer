## Visual probe for boss ability projection (task: impact shapes + phase
## drama). Loads the Anchor Tear, walks the fight to each projected moment,
## and screenshots:
##   1. Anchor Surge — violet ring on the rig + crisp cast bar
##   2. phase transition — veil pulse / flash / sun dim (timing-lucky shot)
##   3. Completing the Anchor — arena-wide violet fill
##   4. boss melee wind-up — impact cone aimed at the player
## Run: xvfb-run godot --rendering-driver vulkan \
##        res://future/tests/harnesses/boss_projection_probe.tscn
extends Node

var _level: Node

func _ready() -> void:
	_level = load("res://scenes/world/tamori_anchor.tscn").instantiate()
	add_child(_level)
	await get_tree().process_frame
	GameState.sarro.stats.max_hp = 900
	GameState.sarro.stats.current_hp = 900
	GameState.liris.stats.max_hp = 900
	GameState.liris.stats.current_hp = 900
	_run()

func _run() -> void:
	var boss: EnemyController = _level.get_node("Enemies/AnchorWarden")
	var player: CharacterBody3D = _level.get_node("Characters/Sarro")
	_level.get_node("Characters/Liris").global_position = \
		boss.global_position + Vector3(4, 0, 4)

	# 1. engage and wait for Anchor Surge (first at ~12 s)
	player.global_position = boss.global_position + Vector3(2.5, 0, 2.5)
	await _wait_until(func(): return boss.is_casting(), 17.0)
	await get_tree().create_timer(1.6).timeout  # let the ring fill read
	await _shot("res://.screenshots/boss_proj_surge.png")

	# 2. boss melee wind-up cone: stand in reach, catch the cone frame
	var cone_seen := false
	for i in 40:
		player.global_position = boss.global_position + Vector3(1.2, 0, 0.6)
		if _has_cone():
			cone_seen = true
			break
		await get_tree().create_timer(0.25).timeout
	if cone_seen:
		await _shot("res://.screenshots/boss_proj_melee_cone.png")
	else:
		print("WARN: no melee cone caught (boss may have been casting)")

	# 3. phases are sequential: cross 60% first, then 30% → completion channel
	await _wait_until(func(): return not boss.is_casting(), 10.0)
	boss._invuln_timer = 0.0
	boss.character.stats.current_hp = int(boss.character.stats.max_hp * 0.62)
	boss.receive_damage(5)
	await get_tree().create_timer(0.4).timeout  # mid phase-drama (veil pulse, dim)
	await _shot("res://.screenshots/boss_proj_phase_drama.png")
	await _wait_until(func(): return not boss.is_casting(), 10.0)
	boss._invuln_timer = 0.0
	boss.character.stats.current_hp = int(boss.character.stats.max_hp * 0.31)
	boss.receive_damage(5)
	var channeling := await _wait_until(func():
		return boss.is_casting(), 8.0)
	if not channeling:
		print("WARN: completion channel never started")
	await get_tree().create_timer(6.0).timeout  # let the 15 m fill creep out
	await _shot("res://.screenshots/boss_proj_completion.png")

	print("BOSS PROJECTION PROBE: done")
	get_tree().quit()

func _has_cone() -> bool:
	# Telegraphs parent to the tree's current scene (this probe's root).
	return _find_cone(self) != null

func _find_cone(root: Node) -> Node:
	if root is Telegraph and root.shape == Telegraph.Shape.CONE:
		return root
	for c in root.get_children():
		var found := _find_cone(c)
		if found != null:
			return found
	return null

func _wait_until(pred: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if pred.call():
			return true
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	return pred.call()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
