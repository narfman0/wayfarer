## Left-side party portrait panel. Click a card to select that character;
## the skill bar rebuilds for the selection.
class_name PartyPanel
extends VBoxContainer

signal character_selected(char)

const _PORTRAIT_COLORS: Dictionary = {
	"sarro": Color(0.3, 0.5, 0.7),
	"liris": Color(0.6, 0.3, 0.7),
}

var _cards: Array = []          # Array of { panel, hp_bar, char_ref, key }
var _selected_key: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left  = 8
	offset_right = 88
	offset_top   = -110
	offset_bottom = 110
	add_theme_constant_override("separation", 8)

	GameState.party_updated.connect(_on_party_updated)
	_rebuild_cards()

	# Default selection = first available character.
	if GameState.sarro != null:
		_select("sarro")
	elif GameState.liris != null:
		_select("liris")

func _on_party_updated() -> void:
	_rebuild_cards()
	if GameState.sarro != null:
		_select("sarro")
	elif GameState.liris != null:
		_select("liris")

func _rebuild_cards() -> void:
	for c in get_children():
		c.queue_free()
	_cards.clear()

	if GameState.sarro != null:
		_cards.append(_make_card("sarro", GameState.sarro))
	if GameState.liris != null:
		_cards.append(_make_card("liris", GameState.liris))

func _make_card(key: String, char) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(80, 100)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := _card_style(false)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(80, 64)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = _PORTRAIT_COLORS.get(key, Color(0.4, 0.4, 0.5))
	p_style.corner_radius_top_left     = 3
	p_style.corner_radius_top_right    = 3
	p_style.corner_radius_bottom_left  = 3
	p_style.corner_radius_bottom_right = 3
	var p_panel := PanelContainer.new()
	p_panel.add_theme_stylebox_override("panel", p_style)
	p_panel.custom_minimum_size = Vector2(80, 64)
	vbox.add_child(p_panel)

	var name_lbl := Label.new()
	name_lbl.text = String(char.display_name) if char.display_name != "" else key.capitalize()
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(80, 8)
	hp_bar.show_percentage = false
	hp_bar.max_value = float(char.stats.max_hp)
	hp_bar.value     = float(char.stats.current_hp)
	vbox.add_child(hp_bar)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select(key))

	add_child(panel)

	return {
		"key": key,
		"panel": panel,
		"hp_bar": hp_bar,
		"char": char,
	}

func _card_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.09, 0.9)
	if selected:
		s.border_color = Color(1.0, 0.85, 0.2, 1.0)
		s.set_border_width_all(2)
	else:
		s.border_color = Color(0.2, 0.18, 0.15, 0.85)
		s.set_border_width_all(1)
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left   = 4
	s.content_margin_right  = 4
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	return s

func _select(key: String) -> void:
	_selected_key = key
	for card in _cards:
		var is_sel: bool = card["key"] == key
		card["panel"].add_theme_stylebox_override("panel", _card_style(is_sel))
	for card in _cards:
		if card["key"] == key:
			character_selected.emit(card["char"])
			return

func selected_key() -> String:
	return _selected_key

func _process(_delta: float) -> void:
	for card in _cards:
		var char = card["char"]
		if char != null and char.stats != null:
			card["hp_bar"].max_value = float(char.stats.max_hp)
			card["hp_bar"].value     = float(char.stats.current_hp)
