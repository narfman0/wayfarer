class_name PauseMenu
extends Control

const _InventoryScreen = preload("res://scripts/ui/inventory_screen.gd")

@onready var _resume_btn: Button  = $Panel/VBox/Resume
@onready var _save_btn:   Button  = $Panel/VBox/Save
@onready var _menu_btn:   Button  = $Panel/VBox/MainMenu
@onready var _quit_btn:   Button  = $Panel/VBox/Quit

## Emitted when the menu closes. Carries queued ability actions (empty = none).
signal queued(sarro_action: String, liris_action: String)

var _queued_sarro: String = ""
var _queued_liris: String = ""
var _liris_btns: Array = []

func _ready() -> void:
	_resume_btn.pressed.connect(_resume)
	_save_btn.pressed.connect(_save)
	_menu_btn.pressed.connect(_to_main_menu)
	_quit_btn.pressed.connect(_quit)
	_add_inventory_button()
	_build_queue_section()

func _add_inventory_button() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	var inv_btn := Button.new()
	inv_btn.text = "Inventory  [%dg]" % GameState.gold
	inv_btn.pressed.connect(_open_inventory)
	# Insert after Save button (index 2)
	vbox.add_child(inv_btn)
	vbox.move_child(inv_btn, 2)

func _open_inventory() -> void:
	var screen: CanvasLayer = _InventoryScreen.new()
	get_tree().current_scene.add_child(screen)
	# Inventory closes over the pause menu — no need to close pause first

func _build_queue_section() -> void:
	var vbox: VBoxContainer = $Panel/VBox

	vbox.add_child(HSeparator.new())

	var header := Label.new()
	header.text = "Queue Action (fires on resume):"
	header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(header)

	# Sarro row
	var sarro_row := HBoxContainer.new()
	var sl := Label.new()
	sl.text = "Sarro "
	sl.custom_minimum_size.x = 46
	sarro_row.add_child(sl)
	var sc = GameState.sarro
	var sw_btn := Button.new()
	sw_btn.text = "[1] Second Wind"
	sw_btn.disabled = sc == null or sc.second_wind_used
	sw_btn.toggle_mode = true
	sw_btn.pressed.connect(_on_sarro_pressed.bind("ability_1", sw_btn))
	sarro_row.add_child(sw_btn)
	vbox.add_child(sarro_row)

	# Liris row
	var liris_row := HBoxContainer.new()
	var ll := Label.new()
	ll.text = "Liris "
	ll.custom_minimum_size.x = 46
	liris_row.add_child(ll)
	var lc = GameState.liris
	_liris_btns.clear()
	_add_liris_btn(liris_row, "[2] Guiding Bolt",    "ability_2", lc == null or not lc.guiding_bolt_ready)
	_add_liris_btn(liris_row, "[3] Healing Word",    "ability_3", lc == null or lc.healing_word_charges <= 0)
	_add_liris_btn(liris_row, "[4] Channel Divinity","ability_4", lc == null or not lc.channel_divinity_ready)
	vbox.add_child(liris_row)

func _add_liris_btn(row: HBoxContainer, label: String, action: String, disabled: bool) -> void:
	var btn := Button.new()
	btn.text = label
	btn.disabled = disabled
	btn.toggle_mode = true
	btn.pressed.connect(_on_liris_pressed.bind(action, btn))
	row.add_child(btn)
	_liris_btns.append(btn)

func _on_sarro_pressed(action: String, btn: Button) -> void:
	_queued_sarro = action if btn.button_pressed else ""

func _on_liris_pressed(action: String, btn: Button) -> void:
	if btn.button_pressed:
		_queued_liris = action
		for b in _liris_btns:
			if b != btn and b.button_pressed:
				b.set_pressed_no_signal(false)
	else:
		_queued_liris = ""

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()

func _resume() -> void:
	get_tree().paused = false
	queued.emit(_queued_sarro, _queued_liris)
	queue_free()

func _save() -> void:
	if GameState.save_game():
		_save_btn.text = "Saved!"
		_save_btn.disabled = true
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(_save_btn):
			_save_btn.text = "Save"
			_save_btn.disabled = false

func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _quit() -> void:
	get_tree().quit()
