## Tamori — first area Sarro visits. Adds the opening dialogue on top of the
## standard level base.
class_name TamoriScene
extends WayfarerLevel

@export var start_dialogue: String = "tamori_tavern"
## Set true in the editor to skip opening dialogue for movement/combat testing.
@export var skip_opening_dialogue: bool = false

func _on_level_ready() -> void:
	_add_dungeon_portal()
	if skip_opening_dialogue or GameState.has_flag("opening_done"):
		_player.set_control_enabled(true)
	else:
		_start_opening_dialogue()

## Spawn a veil portal near the village shrine that leads to a dungeon run.
func _add_dungeon_portal() -> void:
	var portal_script = load("res://scripts/world/portal.gd")
	if portal_script == null:
		return
	var portal := Node3D.new()
	portal.name = "DungeonPortal"
	portal.set_script(portal_script)
	portal.set("display_name", "The Rift Below")
	portal.set("spawn_id",       "dungeon_return")
	portal.set("target_plane",   "dungeon_run")
	portal.set("target_spawn_id", "dungeon_entry")
	# Place near west edge of the village, away from existing portal.
	portal.position = Vector3(-8.0, 0.0, 4.0)
	get_node("Level").add_child(portal)

func _start_opening_dialogue() -> void:
	_player.set_control_enabled(false)
	await get_tree().process_frame
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/tamori_tavern.dialogue"),
		start_dialogue
	)
	await DialogueManager.dialogue_ended
	_player.set_control_enabled(true)
	GameState.set_flag("opening_done")
