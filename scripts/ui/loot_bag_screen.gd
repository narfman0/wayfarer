## UI overlay for searching a loot bag dropped in the world.
## Shows gold + items; player can Take individual items or Take All.
extends CanvasLayer

signal closed

## Mutable mirror of the bag's current contents — edits here also sync back
## to `source_bag` so the bag stays accurate after partial looting.
var gold_amount: int = 0
var items: Array     = []
var source_bag: Node = null

var _gold_lbl: Label
var _items_vbox: VBoxContainer

func _ready() -> void:
	layer = 205
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -255
	panel.offset_top    = -240
	panel.offset_right  =  255
	panel.offset_bottom =  240
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	# ── Title ──────────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "Loot Bag"
	var fnt := UITheme._load_font("res://assets/fonts/Cinzel-Regular.ttf")
	if fnt != null:
		title.add_theme_font_override("font", fnt)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var leave_x := Button.new()
	leave_x.text = "Leave"
	leave_x.pressed.connect(_close)
	title_row.add_child(leave_x)

	outer.add_child(HSeparator.new())

	# ── Gold ──────────────────────────────────────────────────────────────────
	var gold_row := HBoxContainer.new()
	outer.add_child(gold_row)
	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 15)
	_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(_gold_lbl)
	var take_gold := Button.new()
	take_gold.text = "Take Gold"
	take_gold.custom_minimum_size.x = 88
	take_gold.pressed.connect(_take_gold)
	gold_row.add_child(take_gold)

	outer.add_child(HSeparator.new())

	# ── Items ─────────────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 175)
	outer.add_child(scroll)
	_items_vbox = VBoxContainer.new()
	_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_vbox)

	outer.add_child(HSeparator.new())

	# ── Bottom buttons ────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	outer.add_child(btn_row)

	var take_all := Button.new()
	take_all.text = "Take All"
	take_all.custom_minimum_size = Vector2(120, 36)
	take_all.pressed.connect(_take_all)
	btn_row.add_child(take_all)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(100, 36)
	leave_btn.pressed.connect(_close)
	btn_row.add_child(leave_btn)

func _refresh() -> void:
	if _gold_lbl != null:
		_gold_lbl.text = "Gold: %d" % gold_amount if gold_amount > 0 else "Gold: —"
	if _items_vbox == null:
		return
	for c in _items_vbox.get_children():
		c.queue_free()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "  (nothing else)"
		empty.add_theme_color_override("font_color", Color(0.42, 0.42, 0.48))
		_items_vbox.add_child(empty)
		return
	for item in items:
		_add_item_row(item)

func _add_item_row(item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_items_vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s  ×%d" % [item.get("name", "?"), item.get("quantity", 1)]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	var col = item.get("color", [1.0, 1.0, 1.0])
	lbl.add_theme_color_override("font_color", Color(col[0], col[1], col[2]))
	row.add_child(lbl)

	var desc := Label.new()
	desc.text = item.get("description", "")
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.48, 0.48, 0.53))
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc)

	var take_btn := Button.new()
	take_btn.text = "Take"
	take_btn.custom_minimum_size.x = 58
	take_btn.pressed.connect(_take_one_item.bind(item))
	row.add_child(take_btn)

func _take_gold() -> void:
	if gold_amount <= 0:
		return
	GameState.add_gold(gold_amount)
	gold_amount = 0
	_sync_to_bag()
	_refresh()

func _take_one_item(item: Dictionary) -> void:
	var idx := items.find(item)
	if idx == -1:
		return
	GameState.add_item(item.duplicate())
	items.remove_at(idx)
	_sync_to_bag()
	_refresh()

func _take_all() -> void:
	if gold_amount > 0:
		GameState.add_gold(gold_amount)
		gold_amount = 0
	for item in items.duplicate():
		GameState.add_item(item.duplicate())
	items.clear()
	_sync_to_bag()
	_close()

func _sync_to_bag() -> void:
	if source_bag != null and is_instance_valid(source_bag):
		source_bag.gold_amount = gold_amount
		source_bag.items       = items.duplicate(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
