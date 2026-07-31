class_name MainMenu
extends Control

@onready var _new_game_btn: Button = $Layout/NewGame
@onready var _quit_btn:     Button = $Layout/Quit
@onready var _version_label: Label = $VersionLabel

func _ready() -> void:
	_version_label.text = ProjectSettings.get_setting("application/config/version", "")
	_new_game_btn.pressed.connect(_on_new_game)
	_quit_btn.pressed.connect(_on_quit)

func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")

func _on_quit() -> void:
	get_tree().quit()
