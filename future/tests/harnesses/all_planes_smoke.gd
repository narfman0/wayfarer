## Headless smoke test for the biome/atmosphere pass: loads every plane in
## SceneManager.LEVELS and asserts that
##   1. the Scenery node generated and actually placed instances,
##   2. scattered scenery lands at sane world heights (catches unit-scale
##      disasters in both directions — the 100x-too-big AND the invisible
##      100x-too-small failure modes),
##   3. the AmbientMotes particle field spawned.
## Run: godot --headless res://future/tests/harnesses/all_planes_smoke.tscn
extends Node

const _Scenery = preload("res://scripts/world/scenery.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_run()

func _run() -> void:
	for plane_id: String in SceneManager.LEVELS:
		# Fresh debug party per plane: keeps every load on the no-autosave
		# path so this test can never touch the real save slot.
		GameState.sarro = null
		GameState.liris = null
		var level: Node3D = (load(SceneManager.LEVELS[plane_id]) as PackedScene).instantiate()
		add_child(level)
		await get_tree().process_frame
		await get_tree().process_frame
		_check_plane(plane_id, level)
		level.queue_free()
		await get_tree().process_frame

	if _failures.is_empty():
		print("ALL PLANES SMOKE: ALL PASS")
	else:
		for f in _failures:
			print("ALL PLANES SMOKE FAIL: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_plane(plane_id: String, level: Node3D) -> void:
	var scenery := level.get_node_or_null("Level/Scenery")
	_check(scenery != null and scenery.get_child_count() > 20,
		"%s: scenery generated (%d instances)" % [plane_id,
			scenery.get_child_count() if scenery != null else 0])
	if scenery != null:
		var min_h := 1e9
		var max_h := 0.0
		var measured := 0
		for inst in scenery.get_children():
			if not inst is Node3D:
				continue
			var h: float = _Scenery._world_height(inst) * (inst as Node3D).scale.y
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)
			measured += 1
		_check(measured > 0 and max_h < 45.0 and max_h > 1.0 and min_h > 0.02,
			"%s: scenery heights sane (min %.3f m, max %.1f m over %d)" %
				[plane_id, min_h, max_h, measured])
	_check(level.get_node_or_null("AmbientMotes") != null,
		"%s: ambient particle field present" % plane_id)

func _check(cond: bool, label: String) -> void:
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures.append(label)
