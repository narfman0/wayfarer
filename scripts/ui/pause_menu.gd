class_name PauseMenu
extends Control

@onready var _resume_btn: Button  = $Panel/VBox/Resume
@onready var _save_btn:   Button  = $Panel/VBox/Save
@onready var _menu_btn:   Button  = $Panel/VBox/MainMenu
@onready var _quit_btn:   Button  = $Panel/VBox/Quit

func _ready() -> void:
	_resume_btn.pressed.connect(_resume)
	_save_btn.pressed.connect(_save)
	_menu_btn.pressed.connect(_to_main_menu)
	_quit_btn.pressed.connect(_quit)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()

func _resume() -> void:
	get_tree().paused = false
	queue_free()

func _save() -> void:
	if GameState.save_game():
		_save_btn.text = "Saved!"
		_save_btn.disabled = true
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(_save_btn):
			_save_btn.text = "Save"
			_save_btn.disabled = false

func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _quit() -> void:
	get_tree().quit()
