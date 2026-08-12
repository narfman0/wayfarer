## Settings overlay: graphics presets + individual toggles, and audio volume.
## Opened from the pause menu or the main menu. Every change persists to
## user://settings.cfg immediately and applies live to the running level
## (from the main menu it just persists — levels apply at ready).
extends CanvasLayer

signal closed

var _preset_buttons: Dictionary = {}
var _msaa_option: OptionButton
var _shadow_option: OptionButton
var _checks: Dictionary = {}

const _MSAA_ITEMS := [
	["Off", Viewport.MSAA_DISABLED],
	["2×", Viewport.MSAA_2X],
	["4×", Viewport.MSAA_4X],
]
const _SHADOW_ITEMS := [["Standard", 2048], ["High", 4096]]
const _CHECK_ROWS := [
	["ssao", "Ambient occlusion", "contact shading under props and characters"],
	["ssil", "Indirect light", "screen-space bounce light (costliest toggle)"],
	["volumetrics", "Volumetric fog", "plane haze and veil-tear auras"],
	["dof", "Depth of field", "tilt-shift focus band"],
]

func _ready() -> void:
	layer = 200
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -280
	panel.offset_top    = -290
	panel.offset_right  =  280
	panel.offset_bottom =  290
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	# ── Title row ──────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "Settings"
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

	# ── Graphics presets ───────────────────────────────────────────────────────
	outer.add_child(_section_label("Graphics"))
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	outer.add_child(preset_row)
	for preset: String in Graphics.PRESETS:
		var b := Button.new()
		b.text = preset.capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.pressed.connect(_on_preset.bind(preset))
		preset_row.add_child(b)
		_preset_buttons[preset] = b

	# ── Individual settings ────────────────────────────────────────────────────
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	outer.add_child(grid)

	grid.add_child(_row_label("Anti-aliasing", "MSAA — smooths low-poly edges"))
	_msaa_option = OptionButton.new()
	for item in _MSAA_ITEMS:
		_msaa_option.add_item(item[0])
	_msaa_option.item_selected.connect(func(idx: int) -> void:
		_set_and_apply("msaa", _MSAA_ITEMS[idx][1]))
	grid.add_child(_msaa_option)

	grid.add_child(_row_label("Shadow quality", "directional shadow resolution"))
	_shadow_option = OptionButton.new()
	for item in _SHADOW_ITEMS:
		_shadow_option.add_item(item[0])
	_shadow_option.item_selected.connect(func(idx: int) -> void:
		_set_and_apply("shadow_size", _SHADOW_ITEMS[idx][1]))
	grid.add_child(_shadow_option)

	for row in _CHECK_ROWS:
		grid.add_child(_row_label(row[1], row[2]))
		var check := CheckBox.new()
		check.toggled.connect(func(on: bool) -> void:
			_set_and_apply(row[0], on))
		grid.add_child(check)
		_checks[row[0]] = check

	outer.add_child(HSeparator.new())

	# ── Interface ──────────────────────────────────────────────────────────────
	outer.add_child(_section_label("Interface"))
	var ui_grid := GridContainer.new()
	ui_grid.columns = 2
	ui_grid.add_theme_constant_override("h_separation", 16)
	outer.add_child(ui_grid)
	ui_grid.add_child(_row_label("Enemy info", "where enemy name/HP/status display"))
	var enemy_opt := OptionButton.new()
	for item in [["Beside target", "beside"], ["Top bar", "top"], ["Over all enemies", "all"]]:
		enemy_opt.add_item(item[0])
	var current_mode: String = Graphics.ui_setting("enemy_info", "beside")
	var mode_ids := ["beside", "top", "all"]
	enemy_opt.select(mode_ids.find(current_mode) if current_mode in mode_ids else 0)
	enemy_opt.item_selected.connect(func(idx: int) -> void:
		Graphics.set_ui_setting("enemy_info", mode_ids[idx]))
	ui_grid.add_child(enemy_opt)

	outer.add_child(HSeparator.new())

	# ── Audio ──────────────────────────────────────────────────────────────────
	outer.add_child(_section_label("Audio"))
	var vol_grid := GridContainer.new()
	vol_grid.columns = 2
	vol_grid.add_theme_constant_override("h_separation", 16)
	outer.add_child(vol_grid)
	vol_grid.add_child(_row_label("Master volume", ""))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220, 0)
	slider.value = AudioManager.master_volume()
	slider.value_changed.connect(func(v: float) -> void:
		AudioManager.set_master_volume(v))
	vol_grid.add_child(slider)

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	return l

func _row_label(text: String, hint: String) -> Label:
	var l := Label.new()
	l.text = text
	l.tooltip_text = hint
	l.mouse_filter = Control.MOUSE_FILTER_STOP  # so the tooltip shows
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# ── Behavior ──────────────────────────────────────────────────────────────────

func _on_preset(preset: String) -> void:
	Graphics.apply_preset(preset)
	_apply_live()
	_refresh()

func _set_and_apply(key: String, value: Variant) -> void:
	Graphics.set_setting(key, value)
	_apply_live()
	_refresh_presets()

## Push the new settings onto the running level, if we're over one.
func _apply_live() -> void:
	var lvl := get_tree().current_scene
	if lvl != null and lvl.has_method("apply_graphics_tier"):
		lvl.apply_graphics_tier()

## Sync every control to the stored settings.
func _refresh() -> void:
	var msaa: int = Graphics.get_setting("msaa")
	for i in _MSAA_ITEMS.size():
		if _MSAA_ITEMS[i][1] == msaa:
			_msaa_option.select(i)
	var shadow: int = Graphics.get_setting("shadow_size")
	for i in _SHADOW_ITEMS.size():
		if _SHADOW_ITEMS[i][1] == shadow:
			_shadow_option.select(i)
	for key: String in _checks:
		_checks[key].set_pressed_no_signal(Graphics.get_setting(key))
	_refresh_presets()

func _refresh_presets() -> void:
	var current := Graphics.current_preset()
	for preset: String in _preset_buttons:
		_preset_buttons[preset].set_pressed_no_signal(preset == current)

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
