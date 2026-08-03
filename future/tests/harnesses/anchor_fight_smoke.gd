## Headless smoke test for the Mender Anchor fight (D1). Loads the anchor
## arena and walks the fight's whole spine:
##   1. engaging the boss arms Anchor Surge (a visible cast within ~16 s),
##   2. Shield Bash interrupts the cast,
##   3. dropping the boss below 60% starts Veil Shards (line telegraphs),
##   4. below 30% she channels "Completing the Anchor" and the rig turns
##      vulnerable,
##   5. the boss cannot be killed (clamps at 1 HP),
##   6. breaking the rig ends the fight: boss subdued and untargetable,
##   7. the ritual dialogue resource parses.
## Run: godot --headless res://future/tests/harnesses/anchor_fight_smoke.tscn
extends Node

const _TelegraphScript = preload("res://scripts/combat/telegraph.gd")

var _level: Node
var _failures: Array[String] = []

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
	var rig: VeilRig = _level.get_node("Enemies/VeilRig")
	var player: CharacterBody3D = _level.get_node("Characters/Sarro")

	# 1. engage → Anchor Surge cast appears
	player.global_position = boss.global_position + Vector3(2.0, 0, 2.0)
	_level.get_node("Characters/Liris").global_position = player.global_position + Vector3(1, 0, 1)
	var cast_seen := await _wait_until(func(): return boss.is_casting(), 17.0)
	_check(cast_seen, "boss channels Anchor Surge after engage")

	# 2. Shield Bash interrupts it
	if cast_seen:
		player.global_position = boss.global_position + Vector3(1.2, 0, 0)
		player.target_enemy = boss
		GameState.sarro.shield_bash_cd = 0.0
		_level._use_shield_bash()
		_check(not boss.is_casting(), "Shield Bash interrupts the cast")

	# 3. below 60% → Veil Shards line telegraphs
	boss.character.stats.current_hp = int(boss.character.stats.max_hp * 0.62)
	boss.receive_damage(_past_invuln(boss, 5))
	var shards := await _wait_until(func(): return _find_script_node(_TelegraphScript) != null, 16.0)
	_check(shards, "Veil Shards telegraphs appear in phase 2")

	# 4. below 30% → completion channel + vulnerable rig
	await _wait_until(func(): return not boss.is_casting(), 8.0)  # let any surge finish
	boss._invuln_timer = 0.0
	boss.character.stats.current_hp = int(boss.character.stats.max_hp * 0.32)
	boss.receive_damage(5)
	var channeling := await _wait_until(func(): return boss.is_casting(), 6.0)
	_check(channeling, "boss channels rig completion in phase 3")
	_check(rig.vulnerable, "rig is vulnerable once Liris channels")

	# 5. boss is unkillable
	boss._invuln_timer = 0.0
	boss.receive_damage(99999)
	_check(is_instance_valid(boss) and boss.character.stats.current_hp >= 1
		and boss.is_in_group("enemies"), "boss clamps at 1 HP instead of dying")

	# 6. breaking the rig ends the fight
	rig.receive_damage(99999)
	await get_tree().create_timer(0.5).timeout
	_check(not boss.is_in_group("enemies"), "boss subdued and untargetable after rig breaks")

	# 7. the ritual dialogue parses
	var res = load("res://dialogue/warden_ritual.dialogue")
	_check(res != null, "warden_ritual.dialogue loads/compiles")

	if _failures.is_empty():
		print("ANCHOR FIGHT SMOKE: ALL PASS")
	else:
		for f in _failures:
			print("ANCHOR FIGHT SMOKE FAIL: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)

## Damage that respects the phase-transition invuln window by waiting it out.
func _past_invuln(boss: EnemyController, dmg: int) -> int:
	boss._invuln_timer = 0.0
	return dmg

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
