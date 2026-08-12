## Headless smoke test for the pivot systems: real-time CombatManager
## (aggro entry, membership, combat-end detection), LootTable determinism
## + loot bag drops, gold/inventory, and the AStarGrid2D click-path
## plumbing.
## Run: godot --headless res://future/tests/harnesses/systems_smoke.tscn
extends Node

const _LootTable = preload("res://scripts/items/loot_table.gd")
const _IslandGrid = preload("res://scripts/world/island_grid.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_run()

func _run() -> void:
	_test_loot_and_gold()
	await _test_rt_combat()
	await _test_pathfinding()
	await _test_dungeon_enemies()

	if _failures.is_empty():
		print("SYSTEMS SMOKE: ALL PASS")
	else:
		for f in _failures:
			print("SYSTEMS SMOKE FAIL: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)

# ── Loot / gold / inventory ───────────────────────────────────────────────────

func _test_loot_and_gold() -> void:
	var a: Dictionary = _LootTable.roll(_seeded_rng(1234), "dungeon_basic")
	var b: Dictionary = _LootTable.roll(_seeded_rng(1234), "dungeon_basic")
	_check(str(a) == str(b), "loot rolls are seed-deterministic")
	_check(a.has("gold") and a.has("items"), "loot roll returns gold + items")

	GameState.gold = 0
	GameState.add_gold(75)
	_check(GameState.gold == 75, "add_gold accumulates")
	GameState.inventory.clear()
	GameState.add_item({"name": "Healing Draught", "kind": "consumable"})
	GameState.add_item({"name": "Healing Draught", "kind": "consumable"})
	_check(GameState.has_item("Healing Draught"), "inventory stores items")

# ── Real-time combat ──────────────────────────────────────────────────────────

func _test_rt_combat() -> void:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/reach.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.sarro.stats.max_hp = 900
	GameState.sarro.stats.current_hp = 900
	GameState.liris.stats.max_hp = 900
	GameState.liris.stats.current_hp = 900
	var player: CharacterBody3D = level.get_node("Characters/Sarro")
	var guard: EnemyController = level.get_node("Enemies/RoadGuard1")

	# aggro starts combat and registers members
	guard.alerted(player)
	await get_tree().process_frame
	_check(CombatManager.in_combat, "aggro enters combat")
	_check(CombatManager._queue.has(guard), "aggroed enemy joins the encounter")
	_check((guard.collision_mask & 8) != 0 and (guard.collision_mask & 16) != 0,
		"enemies collide with props and barriers")

	# killing the last enemy ends combat via the RT round poll
	for e in level.get_node("Enemies").get_children():
		if e is EnemyController and e.character != null:
			e.receive_damage(99999)
	CombatManager._check_combat_end()
	await get_tree().process_frame
	_check(not CombatManager.in_combat, "combat ends when all enemies fall")

	level.queue_free()
	await get_tree().process_frame

# ── Pathfinding ───────────────────────────────────────────────────────────────

## Pathfinding rides the dungeon's TiledTerrain (the only island level).
func _test_pathfinding() -> void:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/dungeon_run.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var player = level.get_node("Characters/Sarro")
	_check(player.has_method("rebuild_pathfinding"), "player exposes pathfinding rebuild")
	var terrain = level.get_node_or_null("Level/TiledTerrain")
	_check(terrain != null, "dungeon has TiledTerrain")
	if terrain != null and player.has_method("_plan_path"):
		# find two adjacent carved tiles and path between them
		var map: Array = terrain.active_map()
		var found := false
		for y in map.size():
			var row: Array = map[y]
			for x in row.size() - 1:
				if int(row[x]) > 0 and int(row[x + 1]) > 0:
					player.global_position = _IslandGrid.tile_to_world(Vector2i(x, y))
					var path: Array = player._plan_path(
						_IslandGrid.tile_to_world(Vector2i(x + 1, y)))
					_check(path.size() >= 1,
						"a walkable click yields a path (%d waypoints)" % path.size())
					found = true
					break
			if found:
				break
		_check(found, "dungeon map has adjacent carved tiles")
	level.queue_free()
	await get_tree().process_frame

# ── Dungeon: real enemies, CR-scaled groups ───────────────────────────────────

func _test_dungeon_enemies() -> void:
	GameState.flags["dungeon_cr_tier"] = "fair"
	var fair_cost := await _dungeon_total_cost()
	_check(fair_cost > 0.0, "fair rift spawns encounter groups (cost %.1f)" % fair_cost)

	GameState.flags["dungeon_cr_tier"] = "deadly"
	var deadly_cost := await _dungeon_total_cost()
	_check(deadly_cost > fair_cost,
		"deadly rift outweighs fair (%.1f > %.1f)" % [deadly_cost, fair_cost])
	GameState.flags.erase("dungeon_cr_tier")

## Load a dungeon run and return the summed roster cost of its spawns,
## while asserting every spawn is a REAL enemy (sheet + skin + wiring).
func _dungeon_total_cost() -> float:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/dungeon_run.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var total := 0.0
	var all_real := true
	var any_skin := false
	for e in level.get_node("Enemies").get_children():
		if not e is EnemyController:
			continue
		var ec := e as EnemyController
		if ec.character == null or ec.xp_value <= 0 or ec.loot_table_key == "":
			all_real = false
		if ec.get_node_or_null("Skin") != null:
			any_skin = true
		total += float(level.ROSTER.get(ec.enemy_type, {"cost": 1.0})["cost"])
	_check(all_real, "every dungeon enemy has a character sheet, XP, and loot")
	_check(any_skin, "dungeon enemies have real skins (not blank capsules)")
	level.queue_free()
	await get_tree().process_frame
	return total

func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng

func _check(cond: bool, label: String) -> void:
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures.append(label)
