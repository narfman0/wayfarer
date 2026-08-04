## Headless smoke test for the Act 3 pass: the support archetype, Ashan's
## living villagers, the Cael fight spine (both resolutions), Action Surge,
## and the ending dialogues.
## Run: godot --headless res://future/tests/harnesses/act3_smoke.tscn
extends Node

const _TelegraphScript = preload("res://scripts/combat/telegraph.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_run()

func _run() -> void:
	await _test_approach()
	await _test_ashan()
	await _test_cael_combat_path()
	await _test_cael_dialogue_path()
	_check(load("res://dialogue/cael_resolution.dialogue") != null, "cael_resolution.dialogue compiles")
	_check(load("res://dialogue/final_portal.dialogue") != null, "final_portal.dialogue compiles")

	if _failures.is_empty():
		print("ACT3 SMOKE: ALL PASS")
	else:
		for f in _failures:
			print("ACT3 SMOKE FAIL: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)

# ── convergence_approach: support archetype ───────────────────────────────────

func _test_approach() -> void:
	var level := await _load_level("res://scenes/world/convergence_approach.tscn")
	var player: CharacterBody3D = level.get_node("Characters/Sarro")
	var chor: EnemyController = level.get_node("Enemies/Chorister1")
	var zealot: EnemyController = level.get_node("Enemies/Zealot1")

	_check(chor._arch == "support", "chorister uses the support archetype")
	GameState.sarro.stats.max_hp = 900
	GameState.sarro.stats.current_hp = 900
	GameState.liris.stats.max_hp = 900
	GameState.liris.stats.current_hp = 900

	# wound a packmate, pin it beside the healer, aggro the support, and wait
	# for the litany to land. Liris's attacker is neutralized so she can't
	# kill the 10 HP patient before the heal fires.
	level._companion.attacker.character = null
	zealot.character.stats.current_hp = 10
	zealot.global_position = chor.global_position + Vector3(1.2, 0, 0)
	zealot.stun(30.0)
	player.global_position = chor.global_position + Vector3(5, 0, 0)
	level.get_node("Characters/Liris").global_position = player.global_position + Vector3(1, 0, 1)
	chor.alerted(player)
	var cast_seen := await _wait_until(func(): return chor.is_casting(), 8.0)
	_check(cast_seen, "support channels Mending Litany in combat")
	var healed := await _wait_until(func():
		return zealot.character.stats.current_hp > 10, 6.0)
	_check(healed, "Mending Litany heals the wounded packmate")

	# Action Surge doubles Sarro's swing rate (debug parties auto-resolve
	# to Freeblade, whose Surge Mastery runs on a cooldown instead of
	# once-per-rest)
	GameState.sarro.action_surge_used = false
	GameState.sarro.action_surge_cd = 0.0
	level._use_action_surge()
	var surge_spent: bool = GameState.sarro.action_surge_used \
		or GameState.sarro.action_surge_cd > 0.0
	_check(is_equal_approx(level._attacker.rate_scale, 0.5) and surge_spent,
		"Action Surge halves the attack interval and spends its resource")

	level.queue_free()
	await get_tree().process_frame

# ── ashan: lived-in, combat-free ──────────────────────────────────────────────

func _test_ashan() -> void:
	var level := await _load_level("res://scenes/world/ashan.tscn")
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "ashan has zero enemies")
	var walkers := 0
	for npc in [level.get_node_or_null("Level/Amma"), level.get_node_or_null("Level/Toma"),
			level.get_node_or_null("Level/Old_Vess"), level.get_node_or_null("Level/Mirei")]:
		if npc != null:
			walkers += 1
	_check(walkers == 4, "ashan has four villagers (%d found)" % walkers)
	var amma = level.get_node("Level/Amma")
	var start: Vector3 = amma.global_position
	var moved := await _wait_until(func():
		return amma.global_position.distance_to(start) > 0.5, 8.0)
	_check(moved, "villagers stroll between waypoints")
	level.queue_free()
	await get_tree().process_frame

# ── Cael: low-conviction combat path ──────────────────────────────────────────

func _test_cael_combat_path() -> void:
	var level := await _load_level("res://scenes/world/convergence.tscn")
	GameState.flags["conviction"] = 0
	GameState.sarro.stats.max_hp = 2000
	GameState.sarro.stats.current_hp = 2000
	GameState.liris.stats.max_hp = 2000
	GameState.liris.stats.current_hp = 2000
	var cael: EnemyController = level.get_node("Enemies/Cael")
	var player: CharacterBody3D = level.get_node("Characters/Sarro")
	player.global_position = cael.global_position + Vector3(4, 0, 4)
	level.get_node("Characters/Liris").global_position = player.global_position + Vector3(1, 0, 1)

	var kit := await _wait_until(func():
		return _find_script_node(_TelegraphScript) != null, 10.0)
	_check(kit, "Cael's phase-1 kit telegraphs")

	cael._invuln_timer = 0.0
	cael.character.stats.current_hp = int(cael.character.stats.max_hp * 0.55)
	cael.receive_damage(1)
	await get_tree().process_frame
	_check(level._phase == 1, "60% starts phase 2 (collapse points arm)")

	cael._invuln_timer = 0.0
	cael.character.stats.current_hp = int(cael.character.stats.max_hp * 0.25)
	cael.receive_damage(1)
	await get_tree().process_frame
	_check(level._collapse_mode, "low conviction: 30% enters full collapse mode")

	cael._invuln_timer = 0.0
	cael.receive_damage(99999)
	await get_tree().create_timer(0.4).timeout
	_check(GameState.has_flag("cael_fought") and GameState.has_flag("game_won"),
		"killing Cael sets the combat ending")

	level.queue_free()
	await get_tree().process_frame

# ── Cael: high-conviction dialogue path ───────────────────────────────────────

func _test_cael_dialogue_path() -> void:
	var level := await _load_level("res://scenes/world/convergence.tscn")
	GameState.flags["conviction"] = 3
	GameState.flags.erase("cael_fought")
	GameState.flags.erase("game_won")
	var cael: EnemyController = level.get_node("Enemies/Cael")
	cael._invuln_timer = 0.0
	cael.character.stats.current_hp = int(cael.character.stats.max_hp * 0.55)
	cael.receive_damage(1)  # phase transitions advance one threshold per hit
	await get_tree().process_frame
	cael._invuln_timer = 0.0
	cael.character.stats.current_hp = int(cael.character.stats.max_hp * 0.25)
	cael.receive_damage(1)
	await get_tree().create_timer(0.4).timeout
	_check(level._over and not cael.is_in_group("enemies"),
		"high conviction: phase 3 becomes dialogue — Cael subdued, not dead")
	_check(not GameState.has_flag("cael_fought"), "dialogue path does not mark him fought")
	level.queue_free()
	await get_tree().process_frame

# ── helpers ───────────────────────────────────────────────────────────────────

func _load_level(path: String) -> Node3D:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load(path) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	return level

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
