## Autoload singleton — holds all persistent game state and owns save/load.
## Scenes call set_party() after character creation; load_game() rebuilds the
## party from disk and stages world state (position) for the scene to apply.
extends Node

const SaveManager = preload("res://scripts/system/save_manager.gd")
const _Factory    = preload("res://scripts/characters/character_factory.gd")
const _Experience = preload("res://addons/srd/systems/experience.gd")
const _LevelUp    = preload("res://addons/srd/systems/level_up.gd")

const SAVE_VERSION := 5  # 5: gold + inventory

signal party_updated
signal plane_changed(plane_id: String)
signal game_saved
signal xp_gained(amount: int)
signal leveled_up(new_level: int)
signal gold_changed(amount: int)
signal inventory_changed

var sarro = null  # WayfarerCharacter — set by scenes
var liris = null  # WayfarerCharacter — set by scenes

var current_plane: String = ""
var play_time_seconds: float = 0.0

var gold: int = 0
## Array of Dictionaries: {name, type, quantity, heal, roll_heal, color, description, buy_price, sell_price}
var inventory: Array = []

## Story flags — written by dialogue mutations (`do GameState.set_flag("x")`)
## and triggers; read by dialogue conditions and portal gates. Persisted.
var flags: Dictionary = {}

## Staged by load_game(); the world scene applies and clears it on entry.
var pending_player_pos = null  # Vector3 or null

## Set by WayfarerLevel when it spawns a fallback debug party (scene run in
## isolation) — all saving is suppressed so tests never touch the real slot.
var debug_session := false

func _process(delta: float) -> void:
	if current_plane != "":
		play_time_seconds += delta

## Called by scenes after creating characters.
func set_party(sarro_char, liris_char, plane: String = "tamori") -> void:
	sarro = sarro_char
	liris = liris_char
	current_plane = plane
	play_time_seconds = 0.0
	party_updated.emit()

func travel_to(plane_id: String) -> void:
	current_plane = plane_id
	plane_changed.emit(plane_id)

func party() -> Array:
	var p := []
	if sarro != null: p.append(sarro)
	if liris != null: p.append(liris)
	return p

# ── Experience ───────────────────────────────────────────────────────────────

## Grant XP to the whole party (kills, quests — any XP-worthy event calls
## this; dialogue can use `do GameState.grant_xp(25)`). Applies SRD level-ups
## as thresholds are crossed.
func grant_xp(amount: int) -> void:
	if amount <= 0:
		return
	var any_level := 0
	for c in party():
		c.stats.xp += amount
		var target: int = _Experience.level_for_xp(c.stats.xp)
		while c.stats.level < target and c.stats.level < 20:
			_LevelUp.level_up(c.stats, c.class_data, c.energy_slots)
			c.stats.current_hp = c.stats.max_hp  # level-up refills HP
			any_level = c.stats.level
	xp_gained.emit(amount)
	if any_level > 0:
		leveled_up.emit(any_level)

# ── Story flags ──────────────────────────────────────────────────────────────

func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value

func get_flag(flag_name: String, default: Variant = null) -> Variant:
	return flags.get(flag_name, default)

func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))

## Overstitch scars — the world remembers forced casts. Counts live in flags
## (so they persist with the save and dialogue can read them: "scars_tamori",
## "scars_total", "has_overstitched"). Enemies on scarred planes resist
## damage — see EnemyController.SCAR_RESIST_CAP.
func add_scar(plane: String) -> void:
	flags["scars_" + plane] = scar_count(plane) + 1
	flags["scars_total"] = int(flags.get("scars_total", 0)) + 1
	flags["has_overstitched"] = true

func scar_count(plane: String) -> int:
	return int(flags.get("scars_" + plane, 0))

## Liris's conviction score — adjusted by dialogue choices
## (`do GameState.add_conviction(1)`), read by Act 3 gates. Persisted in flags.
func add_conviction(amount: int) -> void:
	flags["conviction"] = conviction() + amount

func conviction() -> int:
	return int(flags.get("conviction", 0))

# ── Gold / Inventory ─────────────────────────────────────────────────────────

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)

## Adds an item to the inventory, stacking consumables by name.
func add_item(item: Dictionary) -> void:
	if item.get("type") == "consumable":
		for existing in inventory:
			if existing.get("name") == item.get("name"):
				existing["quantity"] = existing.get("quantity", 1) + item.get("quantity", 1)
				inventory_changed.emit()
				return
	var entry := item.duplicate()
	if not entry.has("quantity"):
		entry["quantity"] = 1
	inventory.append(entry)
	inventory_changed.emit()

## Removes `qty` of `item_name`. Returns false if insufficient quantity.
func remove_item(item_name: String, qty: int = 1) -> bool:
	for i in range(inventory.size() - 1, -1, -1):
		var it: Dictionary = inventory[i]
		if it.get("name") == item_name:
			var cur: int = it.get("quantity", 1)
			if cur < qty:
				return false
			if cur == qty:
				inventory.remove_at(i)
			else:
				it["quantity"] = cur - qty
			inventory_changed.emit()
			return true
	return false

func has_item(item_name: String) -> bool:
	for it in inventory:
		if it.get("name") == item_name:
			return it.get("quantity", 0) > 0
	return false

# ── Save / load ──────────────────────────────────────────────────────────────

func has_save(slot: int = 0) -> bool:
	return SaveManager.has_save(slot)

## Persist the party and world state. Returns false if there is nothing to save.
func save_game(slot: int = 0) -> bool:
	if sarro == null or liris == null or debug_session:
		return false
	var data := {
		"version": SAVE_VERSION,
		"current_plane": current_plane,
		"play_time": play_time_seconds,
		"flags": flags,
		"gold": gold,
		"inventory": inventory.duplicate(true),
		"sarro": _Factory.to_save_dict(sarro),
		"liris": _Factory.to_save_dict(liris),
	}
	var pos = _player_position()  # Vector3 or null
	if pos != null:
		data["player_pos"] = [pos.x, pos.y, pos.z]
	if not SaveManager.save_game(slot, data):
		return false
	game_saved.emit()
	return true

## Rebuild the party from disk. Returns false on missing/corrupt save.
func load_game(slot: int = 0) -> bool:
	var data: Dictionary = SaveManager.load_game(slot)
	if data.is_empty() or not data.has("sarro"):
		return false
	sarro = _Factory.make_from_save(data["sarro"])
	liris = _Factory.make_from_save(data["liris"]) if data.has("liris") else _Factory.make_liris()
	current_plane = str(data.get("current_plane", "tamori"))
	play_time_seconds = float(data.get("play_time", 0.0))
	flags = data.get("flags", {})
	gold = int(data.get("gold", 0))
	inventory = data.get("inventory", []).duplicate(true)
	var pp = data.get("player_pos")
	if pp is Array and pp.size() == 3:
		pending_player_pos = Vector3(pp[0], pp[1], pp[2])
	party_updated.emit()
	return true

func _player_position():  # Vector3 or null
	var players := get_tree().get_nodes_in_group("players")
	return players[0].global_position if players.size() > 0 else null
