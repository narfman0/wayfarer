## Dungeon rift portal: interacting opens a challenge-rating select (rift
## difficulty, D&D-flavored) before travel. The chosen tier lands in
## GameState flag "dungeon_cr_tier"; DungeonRun budgets each room's
## encounter from party level × tier.
class_name RiftPortal
extends VeilPortal

const _TIERS := [
	["easy",   "Faint Rift",    "CR ~½× level — a stroll with teeth."],
	["fair",   "Open Rift",     "CR ~1× level — a fair fight."],
	["hard",   "Churning Rift", "CR ~1.5× level — bring everything."],
	["deadly", "Screaming Rift", "CR ~2× level — the Veil is hungry."],
]

var _menu: CanvasLayer = null

func _try_travel() -> void:
	if required_flag != "" and not GameState.has_flag(required_flag):
		super._try_travel()
		return
	if _menu != null:
		return
	_open_tier_menu()

func _open_tier_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 90
	add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	dim.add_child(box)

	var title := Label.new()
	title.text = "The rift churns. How deep do you cut?"
	title.add_theme_font_size_override("font_size", 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	for tier in _TIERS:
		var btn := Button.new()
		btn.text = "%s — %s" % [tier[1], tier[2]]
		btn.pressed.connect(_on_tier_picked.bind(str(tier[0])))
		box.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Step back"
	cancel.pressed.connect(_close_menu)
	box.add_child(cancel)

func _on_tier_picked(tier: String) -> void:
	GameState.set_flag("dungeon_cr_tier", tier)
	_close_menu()
	AudioManager.play_sfx("portal")
	SceneManager.change_level(target_plane, target_spawn_id)

func _close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
