class_name MainMenu
extends Control

@onready var _continue_btn:  Button = $Layout/Continue
@onready var _new_game_btn:  Button = $Layout/NewGame
@onready var _quit_btn:      Button = $Layout/Quit
@onready var _version_label: Label  = $VersionLabel
@onready var _title_label:   Label  = $Layout/Title

func _ready() -> void:
	theme = UITheme.theme
	_style_title()
	_version_label.text = ProjectSettings.get_setting("application/config/version", "")
	_continue_btn.disabled = not GameState.has_save()
	_continue_btn.pressed.connect(_on_continue)
	_new_game_btn.pressed.connect(_on_new_game)
	_quit_btn.pressed.connect(_on_quit)

func _style_title() -> void:
	if _title_label == null:
		return
	var fnt := UITheme._load_font("res://assets/fonts/Cinzel-Regular.ttf")
	if fnt != null:
		_title_label.add_theme_font_override("font", fnt)
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)

func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file(SceneManager.level_scene_for(GameState.current_plane))

func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")

func _on_quit() -> void:
	get_tree().quit()
