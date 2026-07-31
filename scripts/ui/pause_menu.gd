class_name PauseMenu
extends Control

@onready var _resume_btn: Button  = $Panel/VBox/Resume
@onready var _menu_btn:   Button  = $Panel/VBox/MainMenu
@onready var _quit_btn:   Button  = $Panel/VBox/Quit

func _ready() -> void:
	_resume_btn.pressed.connect(_resume)
	_menu_btn.pressed.connect(_to_main_menu)
	_quit_btn.pressed.connect(_quit)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()

func _resume() -> void:
	get_tree().paused = false
	queue_free()

func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _quit() -> void:
	get_tree().quit()
