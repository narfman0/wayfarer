## Autoload singleton — holds all persistent game state.
## Pure data bag: no project-type references so it parses cleanly before
## other scripts are registered. Scenes call set_party() to hydrate characters.
extends Node

const SaveManager = preload("res://scripts/system/save_manager.gd")

signal party_updated
signal plane_changed(plane_id: String)

var sarro = null  # WayfarerCharacter — set by scenes
var liris = null  # WayfarerCharacter — set by scenes

var current_plane: String = ""
var has_active_save: bool = false
var play_time_seconds: float = 0.0

## Raw save dict, populated by load_game(); scene hydrates from this.
var _raw_save: Dictionary = {}

func _ready() -> void:
	has_active_save = SaveManager.has_save(0)

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

## Persist current state. Requires set_party() called first.
func save_game(slot: int = 0) -> void:
	if sarro == null or liris == null:
		return
	SaveManager.save_game(slot, _serialize())
	has_active_save = true

## Load raw data from disk. Scenes call get_save_data() and hydrate characters.
func load_game(slot: int = 0) -> bool:
	var data: Dictionary = SaveManager.load_game(slot)
	if data.is_empty():
		return false
	_raw_save = data
	current_plane = data.get("current_plane", "tamori")
	play_time_seconds = data.get("play_time", 0.0)
	has_active_save = true
	return true

func get_save_data() -> Dictionary:
	return _raw_save

func travel_to(plane_id: String) -> void:
	current_plane = plane_id
	plane_changed.emit(plane_id)

func party() -> Array:
	var p := []
	if sarro != null: p.append(sarro)
	if liris != null: p.append(liris)
	return p

# ── Serialization ──────────────────────────────────────────────────────────────

func _serialize() -> Dictionary:
	return {
		"current_plane": current_plane,
		"play_time": play_time_seconds,
		"sarro": _serialize_char(sarro),
		"liris": _serialize_char(liris),
	}

func _serialize_char(c) -> Dictionary:
	if c == null:
		return {}
	return {
		"current_hp": c.stats.current_hp,
		"xp": c.stats.xp,
		"level": c.stats.level,
		"feat_names": c.feats.map(func(f): return f.feat_name),
	}
