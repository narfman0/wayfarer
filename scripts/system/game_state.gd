## Autoload singleton — holds all persistent game state.
## Pure data bag: no project-type references so it parses cleanly before
## other scripts are registered. Scenes call set_party() to hydrate characters.
extends Node

signal party_updated
signal plane_changed(plane_id: String)

var sarro = null  # WayfarerCharacter — set by scenes
var liris = null  # WayfarerCharacter — set by scenes

var current_plane: String = ""
var play_time_seconds: float = 0.0

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
