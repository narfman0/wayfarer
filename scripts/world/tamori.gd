## Tamori — feudal Japanese-inspired plane. First area Sarro visits.
## Scene boots into the opening tavern cutscene.
class_name TamoriScene
extends Node2D

@export var start_dialogue: String = "tamori_tavern"

@onready var _player_node: Node2D = $Characters/Sarro
@onready var _liris_node: Node2D  = $Characters/Liris
@onready var _hud: Control        = $HUD

var _dialogue_started: bool = false

func _ready() -> void:
	_sync_party_to_scene()
	_start_opening_dialogue()

## Push any HP/state changes from GameState down to scene nodes.
func _sync_party_to_scene() -> void:
	if GameState.sarro == null or GameState.liris == null:
		push_error("TamoriScene: GameState has no party — call new_game() first.")
		return

## Show the dialogue balloon for the opening cutscene.
func _start_opening_dialogue() -> void:
	if _dialogue_started:
		return
	_dialogue_started = true
	# Disable player control while in dialogue
	set_process_input(false)
	await get_tree().process_frame
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/tamori_tavern.dialogue"),
		start_dialogue
	)
	var balloon := await DialogueManager.dialogue_ended
	set_process_input(true)
	_on_opening_finished()

func _on_opening_finished() -> void:
	# Auto-save after opening sequence
	GameState.save_game(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()

func _open_pause_menu() -> void:
	# Pause menu implemented as a separate scene pushed over this one
	get_tree().paused = true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		var node: Node = pause_scene.instantiate()
		add_child(node)
