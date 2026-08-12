## Visual gallery for the progression UI: screenshots every creation-wizard
## step and the rest-point level-up screen to res://.screenshots/ui_*.png.
## Needs a display:
##   xvfb-run -a godot --rendering-driver vulkan \
##       res://future/tests/harnesses/ui_gallery.tscn
extends Node

const _Progression = preload("res://scripts/characters/character_progression.gd")
const _Experience  = preload("res://addons/srd/systems/experience.gd")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	_run()

func _run() -> void:
	# wizard steps
	var wiz = (load("res://scenes/ui/character_creation.tscn") as PackedScene).instantiate()
	add_child(wiz)
	await get_tree().process_frame
	wiz._style_key = "defense"
	wiz._feat_key = "lucky"
	for i in wiz.STEP_TITLES.size():
		wiz._step = i
		wiz._rebuild()
		for f in 4:
			await get_tree().process_frame
		_shot("ui_creation_%d_%s" % [i + 1, str(wiz.STEP_TITLES[i]).to_lower().replace(" ", "_")])
	wiz.queue_free()
	await get_tree().process_frame

	# level-up screen at a rest point (reach, debug party pushed to 8)
	GameState.sarro = null
	GameState.liris = null
	var level: Node3D = (load("res://scenes/world/reach.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.sarro.stats.xp = 0
	GameState.grant_xp(_Experience.xp_for_level(8))
	level.get_node("Level/RestPoint")._rest()
	for f in 8:
		await get_tree().process_frame
	_shot("ui_levelup_asi")
	# advance one page (an ASI pick) to reach the second pending page
	var screen = _find_screen(get_tree().root)
	if screen != null:
		var btn = _first_button(screen)
		if btn != null:
			btn.pressed.emit()
		for f in 6:
			await get_tree().process_frame
		_shot("ui_levelup_next_page")

	# settings screen (over the level for the live-apply path)
	var settings: CanvasLayer = load("res://scripts/ui/settings_screen.gd").new()
	add_child(settings)
	for f in 4:
		await get_tree().process_frame
	_shot("ui_settings")
	settings.queue_free()
	print("UI GALLERY DONE")
	get_tree().quit(0)

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://.screenshots/%s.png" % name)
	print("shot: ", name)

func _find_screen(node: Node):
	if node.get_script() != null and node.get_script().get_global_name() == "LevelUpScreen":
		return node
	for child in node.get_children():
		var found = _find_screen(child)
		if found != null:
			return found
	return null

func _first_button(root: Node):
	if root is Button and not root is CheckBox and (root as Button).text != "Apply Split":
		return root
	for child in root.get_children():
		var found = _first_button(child)
		if found != null:
			return found
	return null
