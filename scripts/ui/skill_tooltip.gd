## Floating tooltip shown above a skill-bar slot when hovered.
class_name SkillTooltip
extends PanelContainer

var _vbox: VBoxContainer
var _lbl_name: Label
var _lbl_cost: Label
var _lbl_desc: Label
var _lbl_atk: Label
var _lbl_dmg: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	custom_minimum_size = Vector2(200, 0)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.07, 0.06, 0.14, 0.96)
	style.border_color = Color(0.6, 0.5, 0.95, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	_lbl_name = Label.new()
	_lbl_name.add_theme_font_size_override("font_size", 18)
	_lbl_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_vbox.add_child(_lbl_name)

	_lbl_cost = Label.new()
	_lbl_cost.add_theme_font_size_override("font_size", 11)
	_vbox.add_child(_lbl_cost)

	_lbl_desc = Label.new()
	_lbl_desc.add_theme_font_size_override("font_size", 13)
	_lbl_desc.add_theme_color_override("font_color", Color(0.88, 0.88, 0.95))
	_lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_desc.custom_minimum_size = Vector2(260, 0)
	_vbox.add_child(_lbl_desc)

	_lbl_atk = Label.new()
	_lbl_atk.add_theme_font_size_override("font_size", 12)
	_lbl_atk.add_theme_color_override("font_color", Color(0.9, 0.75, 0.55))
	_vbox.add_child(_lbl_atk)

	_lbl_dmg = Label.new()
	_lbl_dmg.add_theme_font_size_override("font_size", 12)
	_lbl_dmg.add_theme_color_override("font_color", Color(0.95, 0.6, 0.55))
	_vbox.add_child(_lbl_dmg)

	hide()

func show_for(ability: Dictionary, slot_global_rect: Rect2) -> void:
	_lbl_name.text = String(ability.get("name", ""))

	var cost := String(ability.get("cost", ""))
	_lbl_cost.text = _cost_label(cost)
	_lbl_cost.add_theme_color_override("font_color", _cost_color(cost))

	_lbl_desc.text = String(ability.get("description", ""))

	var atk := String(ability.get("attack_roll", ""))
	_lbl_atk.visible = atk.length() > 0
	_lbl_atk.text = "◈ %s" % atk if atk.length() > 0 else ""

	var dmg := String(ability.get("damage", ""))
	_lbl_dmg.visible = dmg.length() > 0
	_lbl_dmg.text = "✦ %s" % dmg if dmg.length() > 0 else ""

	# Size then position above the slot.
	reset_size()
	await get_tree().process_frame
	var my_size: Vector2 = size
	var x: float = slot_global_rect.position.x + (slot_global_rect.size.x - my_size.x) * 0.5
	var y: float = slot_global_rect.position.y - my_size.y - 8.0
	var vp: Vector2 = get_viewport_rect().size
	x = clamp(x, 8.0, vp.x - my_size.x - 8.0)
	y = max(y, 8.0)
	global_position = Vector2(x, y)
	show()

func hide_tooltip() -> void:
	hide()

func _cost_label(cost: String) -> String:
	match cost:
		"action":       return "● ACTION"
		"bonus_action": return "◆ BONUS ACTION"
		"reaction":     return "◇ REACTION"
		"free":         return "○ FREE"
		_:              return cost.to_upper()

func _cost_color(cost: String) -> Color:
	match cost:
		"action":       return Color(0.95, 0.55, 0.45)
		"bonus_action": return Color(0.55, 0.9, 0.6)
		"reaction":     return Color(0.6, 0.75, 1.0)
		"free":         return Color(0.85, 0.85, 0.6)
		_:              return Color(0.8, 0.8, 0.8)
