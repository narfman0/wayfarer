## Deterministic VFX gallery: stages every combat effect at fixed positions
## in the reach scene and screenshots them mid-flight.
##   xvfb-run -a godot --rendering-driver vulkan \
##       res://future/tests/harnesses/vfx_gallery.tscn
extends Node

const _Vfx = preload("res://scripts/combat/vfx.gd")
const _Juice = preload("res://scripts/combat/juice.gd")
const _Telegraph = preload("res://scripts/combat/telegraph.gd")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	_run()

func _run() -> void:
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/reach.tscn") as PackedScene).instantiate()
	add_child(level)
	for i in 20:
		await get_tree().process_frame
	# Stage around the party spawn so the gallery camera frames everything.
	var base: Vector3 = level.get_node("Characters/Sarro").global_position
	_Telegraph.show_circle(level, base + Vector3(8, 0, -4), 2.4, 1.4)
	_Vfx.death_dissolve(level, base + Vector3(6, 0, 4))
	_Vfx.heal_aura(level, base + Vector3(-3, 0, 3))
	for i in 8:
		await get_tree().process_frame
	_Vfx.slash_arc(level, base + Vector3(2, 0, -2), base + Vector3(4, 0, -2))
	_Vfx.slash_arc(level, base + Vector3(2, 0, 2), base + Vector3(4, 0, 3),
		Color(1.0, 0.7, 0.3), true)
	_Vfx.spell_bolt(level, base + Vector3(-4, 0, -3), base + Vector3(6, 0, -6))
	_Vfx.buff_flare(level, base + Vector3(0, 0, 0))
	_Juice.impact_burst(level, base + Vector3(5, 0, 0))
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://.screenshots/vfx_gallery.png")
	print("VFX GALLERY DONE")
	get_tree().quit(0)
