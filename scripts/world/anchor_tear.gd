## The Anchor Tear — Act 1 finale arena. Killing the Warped Anchor Warden
## stills the tear and completes the act (storyline beat 1.5).
class_name AnchorTearScene
extends WayfarerLevel

func _on_enemy_died(ec) -> void:
	super._on_enemy_died(ec)
	if ec.enemy_type == "anchor_warden":
		_victory.call_deferred()

func _victory() -> void:
	GameState.set_flag("act1_done")
	GameState.save_game()
	_player.set_control_enabled(true)
	await get_tree().create_timer(1.2).timeout

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 16)
	dim.add_child(box)

	var title := Label.new()
	title.text = "The Anchor Tear stills."
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "The eastern water will clear by morning.\nAct 1 — Debt: complete."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var stats_line := Label.new()
	stats_line.text = "%s — Level %d (%d XP)" % [
		GameState.sarro.display_name, GameState.sarro.stats.level, GameState.sarro.stats.xp]
	stats_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats_line)

	var cont := Button.new()
	cont.text = "Continue"
	cont.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(cont)

	var keep := Button.new()
	keep.text = "Keep Exploring"
	keep.pressed.connect(layer.queue_free)
	box.add_child(keep)
