## Combat action bar — slides in from the bottom when combat starts.
## Builds its own UI in _ready() so no .tscn file is needed.
## Add this script to a CanvasLayer node in your HUD scene or level.
class_name CombatHUD
extends CanvasLayer

signal spell_requested(spell_data)

var _panel:         PanelContainer
var _btn_move:      Button
var _btn_attack:    Button
var _btn_dash:      Button
var _btn_disengage: Button
var _btn_dodge:     Button
var _btn_end:       Button
var _btn_tb:        Button
var _lbl_move:      Label
var _lbl_turn:      Label

# Ability row (second row, keybindings 1-6)
var _btn_second_wind:    Button
var _btn_guiding_bolt:   Button
var _btn_healing_word:   Button
var _btn_channel_div:    Button
var _btn_shield_bash:    Button
var _btn_action_surge:   Button
var _btn_spells:         Button

# Spell popup
var _spell_popup: PanelContainer = null

# Reaction prompt overlay
var _reaction_panel: PanelContainer
var _reaction_label: Label
var _reaction_trigger_node: Node = null

# Whether the player has manually activated "move" targeting mode.
var _move_mode: bool = false

func _ready() -> void:
	_build_ui()
	_hide_bar()

	CombatManager.combat_started.connect(_on_combat_started)
	CombatManager.combat_ended.connect(_on_combat_ended)
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.tb_mode_changed.connect(_on_tb_mode_changed)
	CombatManager.reaction_available.connect(_on_reaction_available)

# ── UI build ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top    = -72
	_panel.offset_bottom = 0
	_panel.offset_left   = 0
	_panel.offset_right  = 0

	var style := StyleBoxFlat.new()
	style.bg_color          = Color(0.06, 0.06, 0.08, 0.88)
	style.border_color      = Color(0.55, 0.45, 0.25, 1.0)
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	_panel.add_child(hbox)

	_lbl_turn = Label.new()
	_lbl_turn.add_theme_font_size_override("font_size", 13)
	_lbl_turn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_lbl_turn.text = ""
	hbox.add_child(_lbl_turn)

	var sep := VSeparator.new()
	hbox.add_child(sep)

	_btn_move    = _make_btn("Move",       hbox, _on_move)
	_lbl_move    = Label.new()
	_lbl_move.add_theme_font_size_override("font_size", 12)
	_lbl_move.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	hbox.add_child(_lbl_move)

	_btn_attack  = _make_btn("Attack",     hbox, _on_attack)
	_btn_dash    = _make_btn("Dash",       hbox, _on_dash)
	_btn_disengage = _make_btn("Disengage", hbox, _on_disengage)
	_btn_dodge   = _make_btn("Dodge",      hbox, _on_dodge)

	var sep2 := VSeparator.new()
	hbox.add_child(sep2)

	_btn_end = _make_btn("End Turn", hbox, _on_end_turn)
	_btn_end.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))

	_btn_tb = _make_btn("[T] Exit TB", hbox, _on_toggle_tb)
	_btn_tb.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))

	# ── Ability row (below main bar) ─────────────────────────────────────────
	var ability_panel := PanelContainer.new()
	ability_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ability_panel.offset_top    = -120
	ability_panel.offset_bottom = -72
	ability_panel.offset_left   = 0
	ability_panel.offset_right  = 0
	var ab_style := StyleBoxFlat.new()
	ab_style.bg_color     = Color(0.05, 0.05, 0.07, 0.80)
	ab_style.border_color = Color(0.4, 0.35, 0.2, 0.8)
	ab_style.set_border_width_all(1)
	ability_panel.add_theme_stylebox_override("panel", ab_style)

	var ahbox := HBoxContainer.new()
	ahbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ahbox.add_theme_constant_override("separation", 6)
	ability_panel.add_child(ahbox)

	_btn_second_wind  = _make_btn("[1] 2nd Wind",  ahbox, func(): _trigger_ability("ability_1"))
	_btn_guiding_bolt = _make_btn("[2] Guiding Bolt", ahbox, func(): _trigger_ability("ability_2"))
	_btn_healing_word = _make_btn("[3] Heal Word", ahbox, func(): _trigger_ability("ability_3"))
	_btn_channel_div  = _make_btn("[4] Chan. Div", ahbox, func(): _trigger_ability("ability_4"))
	_btn_shield_bash  = _make_btn("[5] Shield Bash", ahbox, func(): _trigger_ability("ability_5"))
	_btn_action_surge = _make_btn("[6] Act. Surge", ahbox, func(): _trigger_ability("ability_6"))

	var sep3 := VSeparator.new()
	ahbox.add_child(sep3)
	_btn_spells = _make_btn("Spells", ahbox, _on_spells)
	_btn_spells.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))

	add_child(ability_panel)

	# ── Reaction prompt overlay ───────────────────────────────────────────────
	_reaction_panel = PanelContainer.new()
	_reaction_panel.set_anchors_preset(Control.PRESET_CENTER)
	_reaction_panel.offset_left  = -160
	_reaction_panel.offset_right =  160
	_reaction_panel.offset_top   = -50
	_reaction_panel.offset_bottom = 50
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color     = Color(0.1, 0.06, 0.18, 0.96)
	rp_style.border_color = Color(0.7, 0.5, 1.0, 1.0)
	rp_style.set_border_width_all(2)
	rp_style.corner_radius_top_left     = 6
	rp_style.corner_radius_top_right    = 6
	rp_style.corner_radius_bottom_left  = 6
	rp_style.corner_radius_bottom_right = 6
	_reaction_panel.add_theme_stylebox_override("panel", rp_style)

	var rvbox := VBoxContainer.new()
	rvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rvbox.add_theme_constant_override("separation", 8)
	_reaction_panel.add_child(rvbox)

	_reaction_label = Label.new()
	_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reaction_label.add_theme_font_size_override("font_size", 15)
	_reaction_label.add_theme_color_override("font_color", Color(0.95, 0.85, 1.0))
	rvbox.add_child(_reaction_label)

	var rbhbox := HBoxContainer.new()
	rbhbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rbhbox.add_theme_constant_override("separation", 12)
	rvbox.add_child(rbhbox)

	var btn_oa_yes := Button.new()
	btn_oa_yes.text = "Attack!"
	btn_oa_yes.custom_minimum_size = Vector2(80, 36)
	btn_oa_yes.add_theme_font_size_override("font_size", 14)
	btn_oa_yes.pressed.connect(_on_reaction_accept)
	rbhbox.add_child(btn_oa_yes)

	var btn_oa_no := Button.new()
	btn_oa_no.text = "Skip"
	btn_oa_no.custom_minimum_size = Vector2(80, 36)
	btn_oa_no.add_theme_font_size_override("font_size", 14)
	btn_oa_no.pressed.connect(_on_reaction_skip)
	rbhbox.add_child(btn_oa_no)

	_reaction_panel.visible = false
	add_child(_reaction_panel)

	add_child(_panel)

func _make_btn(label: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.flat = false
	b.custom_minimum_size = Vector2(90, 48)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ── Visibility ────────────────────────────────────────────────────────────────

func _hide_bar() -> void:
	_panel.visible = false

func _show_bar() -> void:
	_panel.visible = true

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_combat_started(_combatants: Array) -> void:
	if CombatManager.tb_mode:
		_show_bar()
	_refresh()

func _on_combat_ended() -> void:
	_hide_bar()
	_move_mode = false

func _on_turn_started(_combatant: Node) -> void:
	_move_mode = false
	_refresh()

func _on_tb_mode_changed(enabled: bool) -> void:
	if enabled and CombatManager.in_combat:
		_show_bar()
	elif not enabled:
		_hide_bar()
	_refresh()

func _process(_delta: float) -> void:
	if _panel.visible:
		_refresh_move_label()

# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_move() -> void:
	_move_mode = not _move_mode
	_btn_move.button_pressed = _move_mode

func _on_attack() -> void:
	if not CombatManager.is_player_turn():
		return
	# Signal player controller to enter target-select mode.
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 0 and players[0].has_method("enter_attack_mode"):
		players[0].enter_attack_mode()

func _on_dash() -> void:
	if not CombatManager.is_player_turn():
		return
	var player := _get_player()
	if player == null or not CombatManager.has_action(player):
		return
	CombatManager.spend_action(player)
	# Dash: add a full speed's worth of extra movement.
	var bonus: float = player.get_meta("turn_movement", 9.0)
	player.set_meta("turn_movement", player.get_meta("turn_movement", 9.0) + bonus)
	player.set_meta("turn_dashed", true)
	_refresh()

func _on_disengage() -> void:
	if not CombatManager.is_player_turn():
		return
	var player := _get_player()
	if player == null or not CombatManager.has_action(player):
		return
	CombatManager.spend_action(player)
	player.set_meta("turn_disengage", true)
	_refresh()

func _on_dodge() -> void:
	if not CombatManager.is_player_turn():
		return
	var player := _get_player()
	if player == null or not CombatManager.has_action(player):
		return
	CombatManager.spend_action(player)
	player.set_meta("turn_dodging", true)
	_refresh()

func _on_end_turn() -> void:
	_move_mode = false
	CombatManager.end_turn()

func _on_toggle_tb() -> void:
	if CombatManager.tb_mode:
		CombatManager.exit_tb_mode()
		_btn_tb.text = "[T] Enter TB"
	else:
		CombatManager.enter_tb_mode()
		_btn_tb.text = "[T] Exit TB"

func _trigger_ability(action: String) -> void:
	# Simulate the keybind so level_base handles it (including TB economy).
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)

func _on_reaction_available(type: String, trigger: Node, _reactor: Node) -> void:
	if type == "opportunity_attack":
		_reaction_trigger_node = trigger
		_reaction_label.text = "Opportunity Attack\nvs %s?" % trigger.name
		_reaction_panel.visible = true

func _on_reaction_accept() -> void:
	_reaction_panel.visible = false
	CombatManager.resolve_reaction(true)
	_reaction_trigger_node = null

func _on_reaction_skip() -> void:
	_reaction_panel.visible = false
	CombatManager.resolve_reaction(false)
	_reaction_trigger_node = null

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var is_my_turn := CombatManager.is_player_turn()
	var player := _get_player()
	var has_act := is_my_turn and player != null and CombatManager.has_action(player)
	var has_bon := is_my_turn and player != null and CombatManager.has_bonus_action(player)
	var has_mov := is_my_turn and player != null and CombatManager.movement_left(player) > 0.05

	_btn_move.disabled       = not is_my_turn or not has_mov
	_btn_attack.disabled     = not has_act
	_btn_dash.disabled       = not has_act
	_btn_disengage.disabled  = not has_act
	_btn_dodge.disabled      = not has_act
	_btn_end.disabled        = not CombatManager.tb_mode

	if is_my_turn:
		_lbl_turn.text = "Your turn"
	elif CombatManager.current_combatant != null:
		_lbl_turn.text = CombatManager.current_combatant.name + "'s turn"
	else:
		_lbl_turn.text = ""

	_refresh_move_label()
	_refresh_ability_buttons(has_act, has_bon, is_my_turn)

func _refresh_move_label() -> void:
	var player := _get_player()
	if player != null and CombatManager.tb_mode:
		var metres: float = CombatManager.movement_left(player)
		var feet: int = roundi(metres * CombatManager.FEET_PER_METRE)
		_lbl_move.text = "%dft" % feet
	else:
		_lbl_move.text = ""

func _refresh_ability_buttons(has_act: bool, has_bon: bool, is_my_turn: bool) -> void:
	var s = GameState.sarro
	var l = GameState.liris
	if _btn_second_wind != null:
		_btn_second_wind.disabled  = not has_bon or s == null or s.second_wind_used
	if _btn_guiding_bolt != null:
		_btn_guiding_bolt.disabled = not has_act or l == null or not l.guiding_bolt_ready
	if _btn_healing_word != null:
		_btn_healing_word.disabled = not has_bon or l == null or l.healing_word_charges <= 0
	if _btn_channel_div != null:
		_btn_channel_div.disabled  = not has_act or l == null or not l.channel_divinity_ready
	if _btn_shield_bash != null:
		_btn_shield_bash.disabled  = not has_act or s == null or s.shield_bash_cd > 0.0 or (s.stats != null and s.stats.level < 3)
	if _btn_action_surge != null:
		var surge_rdy: bool = s != null and (
			(s.subclass_key == "freeblade" and s.action_surge_cd <= 0.0) or
			(s.subclass_key != "freeblade" and not s.action_surge_used)
		) and (s.stats == null or s.stats.level >= 2)
		_btn_action_surge.disabled = not surge_rdy
	if _btn_spells != null:
		var has_spells: bool = s != null and (s.cantrips.size() > 0 or s.known_spells.size() > 0)
		_btn_spells.disabled = not is_my_turn or not has_spells

func _get_player() -> Node:
	var players := get_tree().get_nodes_in_group("players")
	return players[0] if players.size() > 0 else null

# ── Spell popup ───────────────────────────────────────────────────────────────

func _on_spells() -> void:
	if not CombatManager.is_player_turn():
		return
	if _spell_popup != null and _spell_popup.visible:
		_spell_popup.queue_free()
		_spell_popup = null
		return
	_build_spell_popup()

func _build_spell_popup() -> void:
	if _spell_popup != null:
		_spell_popup.queue_free()
	_spell_popup = PanelContainer.new()
	_spell_popup.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_spell_popup.offset_top    = -340
	_spell_popup.offset_bottom = -122
	_spell_popup.offset_left   = 200
	_spell_popup.offset_right  = -200
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.07, 0.06, 0.14, 0.96)
	style.border_color = Color(0.5, 0.4, 0.9, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_spell_popup.add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	_spell_popup.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "── Cantrips ──"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	vbox.add_child(title)

	var sarro = GameState.sarro
	if sarro != null:
		for sp in sarro.cantrips:
			vbox.add_child(_spell_btn(sp, false))

		var lvl_title := Label.new()
		lvl_title.text = "── Level 1 Spells ──"
		lvl_title.add_theme_font_size_override("font_size", 14)
		lvl_title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
		vbox.add_child(lvl_title)

		for sp in sarro.known_spells:
			var can_cast: bool = _can_cast_l1()
			vbox.add_child(_spell_btn(sp, not can_cast))

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func():
		if _spell_popup != null: _spell_popup.queue_free(); _spell_popup = null)
	vbox.add_child(close_btn)

	add_child(_spell_popup)

func _spell_btn(sp, disabled: bool) -> Button:
	var btn := Button.new()
	var cost_str := " [bonus]" if sp.is_bonus_action else " [action]"
	btn.text = "%s%s — %s" % [sp.spell_name, cost_str, sp.description]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 12)
	btn.disabled = disabled
	var sp_ref = sp
	btn.pressed.connect(func():
		if _spell_popup != null: _spell_popup.queue_free(); _spell_popup = null
		spell_requested.emit(sp_ref))
	return btn

func _can_cast_l1() -> bool:
	var sarro = GameState.sarro
	if sarro == null:
		return false
	if sarro.energy_slots != null and sarro.energy_slots.has_method("slots_remaining"):
		return sarro.energy_slots.slots_remaining(1) > 0
	return true   # fallback: allow cast if no slot tracker

# ── Keyboard shortcut ─────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T and CombatManager.in_combat:
			_on_toggle_tb()
		elif event.keycode == KEY_SPACE and CombatManager.tb_mode and CombatManager.is_player_turn():
			_on_end_turn()
