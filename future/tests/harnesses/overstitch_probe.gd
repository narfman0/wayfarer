## Visual probe for the overstitch/scar system: applies two overstitches on
## a plane (scar tissue + veil pulse + OVERSTITCH feedback), screenshots
## mid-pulse and settled, then reloads scar spawning from the persisted
## count to prove re-entry re-grows them.
## Run: xvfb-run godot --rendering-driver vulkan \
##        res://future/tests/harnesses/overstitch_probe.tscn
extends Node

func _ready() -> void:
	GameState.flags.erase("scars_tamori")
	GameState.flags.erase("scars_total")
	var level = load("res://scenes/world/tamori.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout

	var p: Node3D = level.get_node("Characters/Sarro")
	level._apply_overstitch(p.global_position + Vector3(2.5, 0, 1.0))
	await get_tree().create_timer(0.25).timeout  # mid veil pulse
	await _shot("res://.screenshots/overstitch_pulse.png")
	level._apply_overstitch(p.global_position + Vector3(-2.0, 0, 3.0))
	await get_tree().create_timer(1.6).timeout   # settled: two scars visible
	await _shot("res://.screenshots/overstitch_scars.png")

	print("scar count tamori: ", GameState.scar_count("tamori"))
	print("OVERSTITCH PROBE: done")
	GameState.flags.erase("scars_tamori")
	GameState.flags.erase("scars_total")
	GameState.flags.erase("has_overstitched")
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
