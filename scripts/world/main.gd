## Bootstrap scene — routes to main menu or resumes the active save.
extends Node

const SaveManager = preload("res://scripts/system/save_manager.gd")

func _ready() -> void:
	if SaveManager.has_save(0) and _auto_resume():
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

func _auto_resume() -> bool:
	# Future: add a setting for "resume on launch". For now, always go to menu.
	return false
