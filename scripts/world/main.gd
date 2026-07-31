## Bootstrap scene — routes to the main menu.
extends Node

func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
