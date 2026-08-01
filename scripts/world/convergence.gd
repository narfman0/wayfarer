## The Convergence — final act arena. Cael's defeat ends the intervention
## and the game (storyline beats 3.7–3.9). v1 ships the fight resolution
## (`cael_fought`); the conviction-gated peaceful path comes with dialogue.
class_name ConvergenceScene
extends WayfarerLevel

func _on_enemy_died(ec) -> void:
	super._on_enemy_died(ec)
	if ec.enemy_type == "cael":
		_victory.call_deferred()

func _victory() -> void:
	GameState.set_flag("cael_fought")
	GameState.set_flag("game_won")
	GameState.save_game()
	_player.set_control_enabled(true)
	await get_tree().create_timer(1.2).timeout

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 16)
	dim.add_child(box)

	var title := Label.new()
	title.text = "The stitching stops."
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "He calls it off. His team obeys on trust.\nNot victors — done. In Tamori, the eastern water clears.\n\nWAYFARER"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var hours := int(GameState.play_time_seconds) / 3600
	var minutes := (int(GameState.play_time_seconds) % 3600) / 60
	var stats_line := Label.new()
	stats_line.text = "%s — Level %d (%d XP) — %dh %02dm" % [
		GameState.sarro.display_name, GameState.sarro.stats.level,
		GameState.sarro.stats.xp, hours, minutes]
	stats_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats_line)

	var cont := Button.new()
	cont.text = "Continue"
	cont.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(cont)

	var keep := Button.new()
	keep.text = "Stay a While"
	keep.pressed.connect(layer.queue_free)
	box.add_child(keep)
