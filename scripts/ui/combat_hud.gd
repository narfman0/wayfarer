## Combat action bar — slides in from the bottom when combat starts.
## Builds its own UI in _ready() so no .tscn file is needed.
## Add this script to a CanvasLayer node in your HUD scene or level.
class_name CombatHUD
extends CanvasLayer

var _panel:       PanelContainer
var _btn_move:    Button
var _btn_attack:  Button
var _btn_dash:    Button
var _btn_disengage: Button
var _btn_dodge:   Button
var _btn_end:     Button
var _btn_tb:      Button
var _lbl_move:    Label
var _lbl_turn:    Label

# Whether the player has manually activated "move" targeting mode.
var _move_mode: bool = false

func _ready() -> void:
	_build_ui()
	_hide_bar()

	CombatManager.combat_started.connect(_on_combat_started)
	CombatManager.combat_ended.connect(_on_combat_ended)
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.tb_mode_changed.connect(_on_tb_mode_changed)

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

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var is_my_turn := CombatManager.is_player_turn()
	var player := _get_player()
	var has_act := is_my_turn and player != null and CombatManager.has_action(player)
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

func _refresh_move_label() -> void:
	var player := _get_player()
	if player != null and CombatManager.tb_mode:
		var metres: float = CombatManager.movement_left(player)
		var feet: int = roundi(metres * CombatManager.FEET_PER_METRE)
		_lbl_move.text = "%dft" % feet
	else:
		_lbl_move.text = ""

func _get_player() -> Node:
	var players := get_tree().get_nodes_in_group("players")
	return players[0] if players.size() > 0 else null

# ── Keyboard shortcut ─────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T and CombatManager.in_combat:
			_on_toggle_tb()
		elif event.keycode == KEY_SPACE and CombatManager.tb_mode and CombatManager.is_player_turn():
			_on_end_turn()
