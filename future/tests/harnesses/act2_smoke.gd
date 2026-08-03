## Headless smoke test for the Act 2 thickening pass: A2 encounter
## primitives (ambush / pack aggro / leash), the Extractor Engine fight
## spine, and the new split scenes + dialogues.
## Run: godot --headless res://future/tests/harnesses/act2_smoke.tscn
extends Node

const _TelegraphScript = preload("res://scripts/combat/telegraph.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_run()

func _run() -> void:
	await _test_rig_scene()
	await _test_vault_scene()
	_test_dialogues()

	if _failures.is_empty():
		print("ACT2 SMOKE: ALL PASS")
	else:
		for f in _failures:
			print("ACT2 SMOKE FAIL: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)

# ── reach_rig: primitives + Engine ────────────────────────────────────────────

func _test_rig_scene() -> void:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/reach_rig.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.sarro.stats.max_hp = 900
	GameState.sarro.stats.current_hp = 900
	GameState.liris.stats.max_hp = 900
	GameState.liris.stats.current_hp = 900
	var player: CharacterBody3D = level.get_node("Characters/Sarro")
	var liris: CharacterBody3D = level.get_node("Characters/Liris")

	# ambushers hidden at load
	var ag1: EnemyController = level.get_node("Enemies/AmbushGuard1")
	_check(not ag1.visible and ag1.collision_layer == 0, "ambushers hidden at load")

	# crossing the trigger springs them, alerted
	player.global_position = level.get_node("Level/RigAmbush").global_position
	liris.global_position = player.global_position + Vector3(1, 0, 1)
	var sprung := await _wait_until(func(): return ag1.visible, 3.0)
	_check(sprung and ag1._state != EnemyController.State.PATROL,
		"ambush springs and alerts on trigger")

	# pack aggro: waking one rig_camp member wakes the others
	var g1: EnemyController = level.get_node("Enemies/RigGuard1")
	var enf1: EnemyController = level.get_node("Enemies/Enforcer1")
	g1.alerted(player)
	g1._alert_pack(player)
	_check(enf1._state == EnemyController.State.CHASE, "pack aggro pulls the camp")

	# leash: a chaser dragged past its leash returns home and heals
	var g2: EnemyController = level.get_node("Enemies/RigGuard2")
	g2.character.stats.current_hp = 5
	g2._state = EnemyController.State.CHASE
	g2._target = player
	g2.global_position = g2._spawn_pos + Vector3(25, 0, 0)
	player.global_position = g2.global_position + Vector3(2, 0, 0)
	liris.global_position = player.global_position + Vector3(1, 0, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(g2._state == EnemyController.State.RETURN, "over-leash chaser turns home")
	g2.global_position = g2._spawn_pos + Vector3(1.5, 0, 0)
	var healed := await _wait_until(func():
		return g2.character.stats.current_hp == g2.character.stats.max_hp, 4.0)
	_check(healed, "returned enemy heals to full")

	# Engine: engage → Harvest Beam telegraphs
	var engine: EnemyController = level.get_node("Enemies/Engine")
	player.global_position = engine.global_position + Vector3(4, 0, 4)
	liris.global_position = player.global_position + Vector3(1, 0, 1)
	var beams := await _wait_until(func():
		return _find_script_node(_TelegraphScript) != null, 12.0)
	_check(beams, "Harvest Beam telegraphs appear after engage")

	# phase 1 consumes a pillar
	engine._invuln_timer = 0.0
	engine.character.stats.current_hp = int(engine.character.stats.max_hp * 0.55)
	engine.receive_damage(1)
	await get_tree().process_frame
	_check(_alive_pillars(level) == 2, "phase 1 consumes one pillar")

	# phase 2 consumes the rest; siphon zones spawn
	engine._invuln_timer = 0.0
	engine.character.stats.current_hp = int(engine.character.stats.max_hp * 0.28)
	engine.receive_damage(1)
	await get_tree().process_frame
	_check(_alive_pillars(level) == 0, "phase 2 consumes remaining pillars")
	level._fire_siphon_zones()
	await get_tree().process_frame
	_check(_find_script_node(_TelegraphScript) != null, "siphon zones telegraph")

	# killing the Engine opens the way
	engine._invuln_timer = 0.0
	engine.receive_damage(99999)
	await get_tree().create_timer(0.3).timeout
	_check(GameState.has_flag("reach_rig_done"), "Engine death sets reach_rig_done")

	level.queue_free()
	await get_tree().process_frame

func _alive_pillars(level: Node) -> int:
	var n := 0
	for name in ["Pillar1", "Pillar2", "Pillar3"]:
		var p = level.get_node_or_null("Enemies/" + name)
		if p != null and p.is_in_group("enemies"):
			n += 1
	return n

# ── kaveth_vault: lurker shades ───────────────────────────────────────────────

func _test_vault_scene() -> void:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/kaveth_vault.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var shade: EnemyController = level.get_node("Enemies/Shade1")
	_check(not shade.visible, "vault shades lie hidden at load")
	_check(level.get_node_or_null("Level/WakingTear") != null, "Waking Tear beat lives in the vault")
	level.queue_free()
	await get_tree().process_frame

func _test_dialogues() -> void:
	_check(load("res://dialogue/extractor_deal.dialogue") != null, "extractor_deal.dialogue compiles")
	_check(load("res://dialogue/sarro_portal.dialogue") != null, "sarro_portal.dialogue compiles")

# ── helpers ───────────────────────────────────────────────────────────────────

func _wait_until(cond: Callable, secs: float) -> bool:
	var waited := 0.0
	while waited < secs:
		if cond.call():
			return true
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	return cond.call()

func _find_script_node(script: Script, root: Node = null) -> Node:
	if root == null:
		root = get_tree().root
	if root.get_script() == script:
		return root
	for child in root.get_children():
		var found := _find_script_node(script, child)
		if found != null:
			return found
	return null

func _check(cond: bool, label: String) -> void:
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures.append(label)
