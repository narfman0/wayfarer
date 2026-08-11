## Bottom-center icon skill bar for the currently selected character.
class_name SkillBar
extends HBoxContainer

const _AbilityRegistry = preload("res://scripts/ui/ability_registry.gd")
const _SkillTooltip    = preload("res://scripts/ui/skill_tooltip.gd")

var _abilities: Array[Dictionary] = []
var _slots: Array[Button] = []
var _tooltip: SkillTooltip
var _current_char = null

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top    = -164
	offset_bottom = -80
	# Center the row horizontally by using alignment on a wrapping container.
	alignment = BoxContainer.ALIGNMENT_CENTER

	_tooltip = _SkillTooltip.new()
	# Tooltip is added at the CanvasItem root so it can float above the bar.
	call_deferred("_add_tooltip_to_root")

func _add_tooltip_to_root() -> void:
	var root: Node = get_tree().root
	if root != null and _tooltip.get_parent() == null:
		root.add_child(_tooltip)

func build_for(char) -> void:
	_current_char = char
	for c in get_children():
		c.queue_free()
	_slots.clear()
	_abilities = _AbilityRegistry.abilities_for(char)
	for i in _abilities.size():
		var slot: Button = _make_slot(_abilities[i])
		add_child(slot)
		_slots.append(slot)

func _make_slot(ability: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.focus_mode = Control.FOCUS_NONE

	var style := StyleBoxFlat.new()
	style.bg_color = ability.get("icon_color", Color(0.4, 0.4, 0.5))
	style.border_color = Color(0.15, 0.15, 0.18, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = Color(1.0, 0.85, 0.35, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	var kb := Label.new()
	kb.text = String(ability.get("keybind", ""))
	kb.add_theme_font_size_override("font_size", 12)
	kb.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	kb.position = Vector2(4, 2)
	kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(kb)

	var state := Label.new()
	state.name = "State"
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", Color(1, 1, 1))
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.anchor_left = 0.0
	state.anchor_right = 1.0
	state.anchor_top = 1.0
	state.anchor_bottom = 1.0
	state.offset_top = -16
	state.offset_bottom = -2
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(state)

	var ab_ref: Dictionary = ability
	btn.pressed.connect(func():
		var cb: Callable = ab_ref.get("activate", Callable())
		if cb.is_valid():
			cb.call())
	btn.mouse_entered.connect(func(): _tooltip.show_for(ab_ref, btn.get_global_rect()))
	btn.mouse_exited.connect(func(): _tooltip.hide_tooltip())

	return btn

func _process(_delta: float) -> void:
	for i in _slots.size():
		if i >= _abilities.size():
			continue
		var slot: Button = _slots[i]
		var ability: Dictionary = _abilities[i]
		var ready_cb: Callable = ability.get("is_ready", Callable())
		var is_ready: bool = true
		if ready_cb.is_valid():
			is_ready = bool(ready_cb.call())
		slot.modulate = Color(1, 1, 1, 1) if is_ready else Color(0.4, 0.4, 0.4, 1.0)
		var state_lbl: Label = slot.get_node_or_null("State") as Label
		if state_lbl != null:
			state_lbl.text = "" if is_ready else "spent"

func _exit_tree() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
