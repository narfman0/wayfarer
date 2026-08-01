## Autoload singleton — holds all persistent game state and owns save/load.
## Scenes call set_party() after character creation; load_game() rebuilds the
## party from disk and stages world state (position) for the scene to apply.
extends Node

const SaveManager = preload("res://scripts/system/save_manager.gd")
const _Factory    = preload("res://scripts/characters/character_factory.gd")

const SAVE_VERSION := 2

signal party_updated
signal plane_changed(plane_id: String)
signal game_saved

var sarro = null  # WayfarerCharacter — set by scenes
var liris = null  # WayfarerCharacter — set by scenes

var current_plane: String = ""
var play_time_seconds: float = 0.0

## Story flags — written by dialogue mutations (`do GameState.set_flag("x")`)
## and triggers; read by dialogue conditions and portal gates. Persisted.
var flags: Dictionary = {}

## Staged by load_game(); the world scene applies and clears it on entry.
var pending_player_pos = null  # Vector3 or null

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

# ── Story flags ──────────────────────────────────────────────────────────────

func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value

func get_flag(flag_name: String, default: Variant = null) -> Variant:
	return flags.get(flag_name, default)

func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))

# ── Save / load ──────────────────────────────────────────────────────────────

func has_save(slot: int = 0) -> bool:
	return SaveManager.has_save(slot)

## Persist the party and world state. Returns false if there is nothing to save.
func save_game(slot: int = 0) -> bool:
	if sarro == null or liris == null:
		return false
	var data := {
		"version": SAVE_VERSION,
		"current_plane": current_plane,
		"play_time": play_time_seconds,
		"flags": flags,
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
	var pp = data.get("player_pos")
	if pp is Array and pp.size() == 3:
		pending_player_pos = Vector3(pp[0], pp[1], pp[2])
	party_updated.emit()
	return true

func _player_position():  # Vector3 or null
	var players := get_tree().get_nodes_in_group("players")
	return players[0].global_position if players.size() > 0 else null
