## Visual probe for the action bar polish: forces every slot state at once —
## active cooldowns (drain + countdown), a spent rest resource, a primed
## strike, group separators — and screenshots the bar.
## Run: xvfb-run godot --rendering-driver vulkan \
##        res://future/tests/harnesses/skillbar_probe.tscn
extends Node

func _ready() -> void:
	var level = load("res://scenes/world/tamori_anchor.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout

	var c = GameState.sarro
	c.second_wind_used = true       # spent-until-rest → gray + "spent"
	c.heavy_strike_primed = true    # primed → "primed" label
	c.shove_cd = 4.5                # mid-cooldown → drain + countdown
	c.grapple_cd = 11.0             # nearly full drain
	c.flavor_cd = 1.4               # sub-3s → decimal countdown
	await get_tree().create_timer(0.4).timeout
	await _shot("res://.screenshots/skillbar_states.png")
	print("SKILLBAR PROBE: done")
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
