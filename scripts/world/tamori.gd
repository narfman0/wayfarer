## Tamori — first area Sarro visits. Adds the opening dialogue on top of the
## standard level base.
class_name TamoriScene
extends WayfarerLevel

@export var start_dialogue: String = "tamori_tavern"
## Set true in the editor to skip opening dialogue for movement/combat testing.
@export var skip_opening_dialogue: bool = false

func _on_level_ready() -> void:
	if skip_opening_dialogue or GameState.has_flag("opening_done"):
		_player.set_control_enabled(true)
	else:
		_start_opening_dialogue()

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
