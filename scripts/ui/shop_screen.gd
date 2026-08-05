## Shop overlay — lists items for purchase by price.
## Instantiated by ShopNPC when the player interacts.
extends CanvasLayer

signal closed

var _catalog: Array = []
var _gold_label: Label
var _status_label: Label

func _ready() -> void:
	layer = 210
	_catalog = _default_catalog()
	_build_ui()
	GameState.gold_changed.connect(_on_gold_changed)

func _default_catalog() -> Array:
	return [
		{name="Healing Potion",        type="consumable", heal=10, roll_heal=true,
		 buy_price=50,  sell_price=25, color=[0.45, 1.0, 0.55], description="Restores 2d4+2 HP"},
		{name="Greater Healing Potion",type="consumable", heal=0,  roll_heal=false,
		 buy_price=150, sell_price=75, color=[0.3, 0.9, 0.4],  description="Restores 4d4+4 HP (use from bag)"},
		{name="Antitoxin",             type="consumable", heal=0,  roll_heal=false,
		 buy_price=50,  sell_price=20, color=[0.7, 1.0, 0.7],  description="Neutralises one poison dose"},
		{name="Torch",                 type="consumable", heal=0,  roll_heal=false,
		 buy_price=5,   sell_price=2,  color=[1.0, 0.7, 0.3],  description="Burns for 1 hour"},
	]

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -280
	panel.offset_top    = -230
	panel.offset_right  =  280
	panel.offset_bottom =  230
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.07, 0.12, 0.97)
	style.border_color = Color(0.55, 0.45, 0.25)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	# Title row
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "General Store  —  Tamori"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(_close)
	title_row.add_child(close_btn)

	outer.add_child(HSeparator.new())

	# Item list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 220)
	outer.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	for item in _catalog:
		_add_row(vbox, item)

	outer.add_child(HSeparator.new())

	# Footer
	var footer := HBoxContainer.new()
	outer.add_child(footer)
	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % GameState.gold
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_gold_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	footer.add_child(_status_label)

func _add_row(parent: VBoxContainer, item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = item.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	var col = item.color
	name_lbl.add_theme_color_override("font_color", Color(col[0], col[1], col[2]))
	row.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%dg" % item.buy_price
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	price_lbl.custom_minimum_size.x = 48
	row.add_child(price_lbl)

	var btn := Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size.x = 58
	btn.pressed.connect(_buy.bind(item))
	row.add_child(btn)

func _buy(item: Dictionary) -> void:
	var price: int = item.buy_price
	if GameState.gold < price:
		_flash("Not enough gold!")
		return
	GameState.add_gold(-price)
	var entry := item.duplicate()
	entry["quantity"] = 1
	GameState.add_item(entry)
	_flash("Bought %s!" % item.name)

func _flash(msg: String) -> void:
	if _status_label == null:
		return
	_status_label.text = msg
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(_status_label):
			_status_label.text = "")

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
