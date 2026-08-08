## Full-screen inventory overlay: equipment slots, consumable bag, gold total.
## Opened from the pause menu or the I key.
extends CanvasLayer

signal closed

const _Dice = preload("res://addons/srd/dice.gd")

var _items_vbox: VBoxContainer
var _gold_label: Label

func _ready() -> void:
	layer = 200
	_build_ui()
	_refresh()
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.inventory_changed.connect(_refresh)

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -290
	panel.offset_top    = -300
	panel.offset_right  =  290
	panel.offset_bottom =  300
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	# ── Title row ──────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "Inventory"
	var fnt := UITheme._load_font("res://assets/fonts/Cinzel-Regular.ttf")
	if fnt != null:
		title.add_theme_font_override("font", fnt)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(_close)
	title_row.add_child(close_btn)

	outer.add_child(HSeparator.new())

	# ── Equipment ──────────────────────────────────────────────────────────────
	var equip_lbl := Label.new()
	equip_lbl.text = "Equipped"
	equip_lbl.add_theme_font_size_override("font_size", 14)
	equip_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	outer.add_child(equip_lbl)

	var equip_grid := GridContainer.new()
	equip_grid.columns = 2
	equip_grid.add_theme_constant_override("h_separation", 14)
	outer.add_child(equip_grid)
	_add_equip_row(equip_grid, "Weapon", _weapon_name())
	_add_equip_row(equip_grid, "Armor",  _armor_name())

	outer.add_child(HSeparator.new())

	# ── Bag ───────────────────────────────────────────────────────────────────
	var bag_lbl := Label.new()
	bag_lbl.text = "Bag"
	bag_lbl.add_theme_font_size_override("font_size", 14)
	bag_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	outer.add_child(bag_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 150)
	outer.add_child(scroll)

	_items_vbox = VBoxContainer.new()
	_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_vbox)

	outer.add_child(HSeparator.new())

	# ── Gold footer ───────────────────────────────────────────────────────────
	var footer := HBoxContainer.new()
	outer.add_child(footer)
	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % GameState.gold
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_gold_label)

func _add_equip_row(grid: GridContainer, slot: String, item_name: String) -> void:
	var slot_lbl := Label.new()
	slot_lbl.text = slot + ":"
	slot_lbl.add_theme_font_size_override("font_size", 13)
	slot_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	grid.add_child(slot_lbl)
	var item_lbl := Label.new()
	item_lbl.text = item_name
	item_lbl.add_theme_font_size_override("font_size", 13)
	grid.add_child(item_lbl)

func _weapon_name() -> String:
	var s = GameState.sarro
	if s == null or s.equipment == null:
		return "—"
	var w = s.equipment.get("main_hand") if s.equipment is Dictionary \
		else s.equipment.get("main_hand") if s.equipment.has_method("get") \
		else null
	if w == null and s.equipment != null:
		w = s.equipment.main_hand if "main_hand" in s.equipment else null
	if w == null:
		return "—"
	return str(w.get("weapon_name", w)) if w is Dictionary else str(w.weapon_name) if "weapon_name" in w else "?"

func _armor_name() -> String:
	var s = GameState.sarro
	if s == null or s.equipment == null:
		return "—"
	var a = null
	if "armor" in s.equipment:
		a = s.equipment.armor
	if a == null:
		return "—"
	return str(a.get("armor_name", a)) if a is Dictionary else str(a.armor_name) if "armor_name" in a else "?"

func _refresh() -> void:
	if _items_vbox == null:
		return
	for c in _items_vbox.get_children():
		c.queue_free()
	if GameState.inventory.is_empty():
		var empty := Label.new()
		empty.text = "  (empty bag)"
		empty.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		_items_vbox.add_child(empty)
		return
	for item in GameState.inventory:
		_add_item_row(item)

func _add_item_row(item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_items_vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s  ×%d" % [item.get("name", "?"), item.get("quantity", 1)]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	var col = item.get("color", [1.0, 1.0, 1.0])
	lbl.add_theme_color_override("font_color", Color(col[0], col[1], col[2]))
	row.add_child(lbl)

	var desc := Label.new()
	desc.text = item.get("description", "")
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc)

	if item.get("type") == "consumable":
		var use_btn := Button.new()
		use_btn.text = "Use"
		use_btn.custom_minimum_size.x = 58
		use_btn.add_theme_font_size_override("font_size", 12)
		use_btn.pressed.connect(_use_item.bind(item))
		row.add_child(use_btn)

func _use_item(item: Dictionary) -> void:
	var item_name: String = item.get("name", "")
	if not GameState.remove_item(item_name, 1):
		return
	var heal_base: int = item.get("heal", 0)
	if heal_base > 0 and GameState.sarro != null:
		var s = GameState.sarro
		var actual: int = heal_base
		if item.get("roll_heal", false):
			actual = _Dice.roll(4) + _Dice.roll(4) + 2
		s.stats.current_hp = mini(s.stats.max_hp, s.stats.current_hp + actual)
		print("[Item] %s: Sarro +%d HP" % [item_name, actual])
	_refresh()

func _on_gold_changed(amount: int) -> void:
	if _gold_label != null:
		_gold_label.text = "Gold: %d" % amount

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
