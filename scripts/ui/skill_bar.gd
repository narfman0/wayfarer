## Bottom-center icon skill bar for the currently selected character.
class_name SkillBar
extends HBoxContainer

const _AbilityRegistry = preload("res://scripts/ui/ability_registry.gd")
const _SkillTooltip    = preload("res://scripts/ui/skill_tooltip.gd")

var _abilities: Array[Dictionary] = []
var _slots: Array[Button] = []
var _tooltip
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
	var prev_group := ""
	for i in _abilities.size():
		# thin rule between groups: class kit | maneuvers | spells
		var group: String = String(_abilities[i].get("group", ""))
		if i > 0 and group != prev_group:
			add_child(_make_separator())
		prev_group = group
		var slot: Button = _make_slot(_abilities[i])
		add_child(slot)
		_slots.append(slot)

func _make_separator() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(10, 64)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rule := ColorRect.new()
	rule.color = Color(0.65, 0.55, 0.35, 0.5)
	rule.anchor_left = 0.5
	rule.anchor_right = 0.5
	rule.anchor_top = 0.15
	rule.anchor_bottom = 0.85
	rule.offset_left = -1
	rule.offset_right = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rule)
	return holder

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

	# Cooldown drain: a dark overlay that covers the remaining fraction from
	# the top and shrinks as the cooldown ticks — classic fill-drain read.
	var cd_fill := ColorRect.new()
	cd_fill.name = "CdFill"
	cd_fill.color = Color(0.05, 0.05, 0.08, 0.72)
	cd_fill.anchor_left = 0.0
	cd_fill.anchor_right = 1.0
	cd_fill.anchor_top = 0.0
	cd_fill.anchor_bottom = 0.0
	cd_fill.visible = false
	cd_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cd_fill)

	var cd_text := Label.new()
	cd_text.name = "CdText"
	cd_text.add_theme_font_size_override("font_size", 20)
	cd_text.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	cd_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cd_text.add_theme_constant_override("outline_size", 4)
	cd_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_text.visible = false
	cd_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cd_text)

	# Charge/slot badge, bottom-right (healing word charges, spell slots).
	var count := Label.new()
	count.name = "Count"
	count.add_theme_font_size_override("font_size", 13)
	count.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	count.add_theme_constant_override("outline_size", 3)
	count.anchor_left = 1.0
	count.anchor_right = 1.0
	count.anchor_top = 1.0
	count.anchor_bottom = 1.0
	count.offset_left = -18
	count.offset_top = -20
	count.offset_bottom = -4
	count.visible = false
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(count)

	var ab_ref: Dictionary = ability
	btn.pressed.connect(func():
		var cb: Callable = ab_ref.get("activate", Callable())
		if cb.is_valid():
			cb.call())
	btn.mouse_entered.connect(func(): _tooltip.show_for(ab_ref, btn.get_global_rect()))
	btn.mouse_exited.connect(func(): _tooltip.hide_tooltip())

	return btn

## Spell hotkeys: 7 8 9 0 are dispatched here by keybind label (abilities
## 1-6 flow through real input actions in level_base; spells have none).
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	var label := ""
	match key:
		KEY_7: label = "7"
		KEY_8: label = "8"
		KEY_9: label = "9"
		KEY_0: label = "0"
	if label == "":
		return
	for ability in _abilities:
		if String(ability.get("keybind", "")) != label:
			continue
		var ready_cb: Callable = ability.get("is_ready", Callable())
		if ready_cb.is_valid() and not bool(ready_cb.call()):
			return
		var cb: Callable = ability.get("activate", Callable())
		if cb.is_valid():
			cb.call()
		return

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

		# active cooldown → drain overlay + countdown instead of "spent"
		var cd_left := 0.0
		var cd_frac := 0.0
		var cd_cb: Callable = ability.get("cooldown", Callable())
		if cd_cb.is_valid():
			var cd: Array = cd_cb.call()
			cd_left = float(cd[0])
			cd_frac = clampf(cd_left / maxf(0.001, float(cd[1])), 0.0, 1.0)

		var cd_fill: ColorRect = slot.get_node_or_null("CdFill") as ColorRect
		var cd_text: Label = slot.get_node_or_null("CdText") as Label
		var on_cooldown := cd_left > 0.05
		if cd_fill != null:
			cd_fill.visible = on_cooldown
			cd_fill.anchor_bottom = cd_frac
		if cd_text != null:
			cd_text.visible = on_cooldown
			cd_text.text = ("%.1f" % cd_left) if cd_left < 3.0 else str(ceili(cd_left))

		var count_lbl: Label = slot.get_node_or_null("Count") as Label
		if count_lbl != null:
			var count_cb: Callable = ability.get("count", Callable())
			if count_cb.is_valid():
				var n := int(count_cb.call())
				count_lbl.visible = true
				count_lbl.text = str(n)
				count_lbl.add_theme_color_override("font_color",
					Color(1.0, 0.9, 0.55) if n > 0 else Color(0.9, 0.35, 0.3))
			else:
				count_lbl.visible = false

		# cooldowns keep their color under the drain; only spent-until-rest
		# (or out-of-slots) resources gray out
		if on_cooldown:
			slot.modulate = Color(0.85, 0.85, 0.85, 1.0)
		else:
			slot.modulate = Color(1, 1, 1, 1) if is_ready else Color(0.4, 0.4, 0.4, 1.0)
		var state_lbl: Label = slot.get_node_or_null("State") as Label
		if state_lbl != null:
			var show_spent := not is_ready and not on_cooldown \
				and not (ability.get("count", Callable()) as Callable).is_valid()
			state_lbl.text = String(ability.get("not_ready_label", "spent")) if show_spent else ""

func _exit_tree() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
