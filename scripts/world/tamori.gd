## Tamori — feudal Japanese-inspired plane. First area Sarro visits.
## Scene boots into the opening tavern cutscene, then hands control to the player.
class_name TamoriScene
extends Node3D

@export var start_dialogue: String = "tamori_tavern"

@onready var _player:    PlayerController = $Characters/Sarro
@onready var _companion: CompanionFollow  = $Characters/Liris
@onready var _cam_pivot: Node3D           = $CameraPivot
@onready var _hud:       Control          = $HUD

func _ready() -> void:
	_player.camera_pivot = _cam_pivot
	_companion.follow_target = _player
	_sync_party_to_scene()
	_start_opening_dialogue()

func _sync_party_to_scene() -> void:
	if GameState.sarro == null or GameState.liris == null:
		push_error("TamoriScene: GameState has no party — call new_game() first.")

func _start_opening_dialogue() -> void:
	_player.set_control_enabled(false)
	await get_tree().process_frame
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/tamori_tavern.dialogue"),
		start_dialogue
	)
	await DialogueManager.dialogue_ended
	_player.set_control_enabled(true)
	_on_opening_finished()

func _on_opening_finished() -> void:
	GameState.save_game(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()

func _open_pause_menu() -> void:
	get_tree().paused = true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		add_child(pause_scene.instantiate())
