## In-world HUD: party HP bars + targeted enemy HP + ability hotbar + rest buttons.
class_name HUD
extends Control

@onready var _enemy_row:  HBoxContainer = $EnemyRow
@onready var _enemy_bar:  ProgressBar = $EnemyRow/EnemyHP
@onready var _enemy_name: Label = $EnemyRow/EnemyName

const _Progression = preload("res://scripts/characters/character_progression.gd")
const _PartyPanel  = preload("res://scripts/ui/party_panel.gd")
const _SkillBar    = preload("res://scripts/ui/skill_bar.gd")

var _tracked_enemy: EnemyController = null
var _toast: Label
var _party_panel
var _skill_bar
var _pending_label: Label
var _rest_panel: PanelContainer
var _btn_short_rest: Button
var _btn_long_rest: Button
var _gold_label: Label

func _ready() -> void:
	add_child(load("res://scripts/ui/enemy_info.gd").new())
	theme = UITheme.theme
	_enemy_row.visible = false
	# Hide the old scene-based HP bars — replaced by PartyPanel
	var old_party := get_node_or_null("Party")
	if old_party:
		old_party.visible = false

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 60
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.visible = false
	add_child(_toast)

	_party_panel = _PartyPanel.new()
	add_child(_party_panel)

	_skill_bar = _SkillBar.new()
	add_child(_skill_bar)

	_party_panel.character_selected.connect(_skill_bar.build_for)

	if GameState.sarro != null:
		_skill_bar.build_for(GameState.sarro)

	_pending_label = Label.new()
	_pending_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pending_label.position.y = 92
	_pending_label.add_theme_font_size_override("font_size", 16)
	_pending_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_pending_label.text = "✦ Choices await — rest at a stable tear"
	_pending_label.visible = false
	add_child(_pending_label)

	_build_rest_panel()
	_build_gold_label()

	GameState.xp_gained.connect(_on_xp_gained)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.gold_changed.connect(_on_gold_changed)

func _build_rest_panel() -> void:
	_rest_panel = PanelContainer.new()
	_rest_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rest_panel.offset_left  = -210
	_rest_panel.offset_top   = 12
	_rest_panel.offset_right = -12
	_rest_panel.offset_bottom = 52
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.07, 0.07, 0.10, 0.85)
	style.border_color = Color(0.4, 0.35, 0.2, 0.7)
	style.set_border_width_all(1)
	_rest_panel.add_theme_stylebox_override("panel", style)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	_rest_panel.add_child(hb)

	_btn_short_rest = Button.new()
	_btn_short_rest.text = "Short Rest"
	_btn_short_rest.custom_minimum_size = Vector2(90, 32)
	_btn_short_rest.add_theme_font_size_override("font_size", 13)
	_btn_short_rest.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	_btn_short_rest.tooltip_text = "Recover short-rest resources (out of combat only)"
	_btn_short_rest.pressed.connect(_on_short_rest)
	hb.add_child(_btn_short_rest)

	_btn_long_rest = Button.new()
	_btn_long_rest.text = "Long Rest"
	_btn_long_rest.custom_minimum_size = Vector2(90, 32)
	_btn_long_rest.add_theme_font_size_override("font_size", 13)
	_btn_long_rest.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_btn_long_rest.tooltip_text = "Full recovery — HP, all abilities, spell slots (out of combat only)"
	_btn_long_rest.pressed.connect(_on_long_rest)
	hb.add_child(_btn_long_rest)

	add_child(_rest_panel)

func _build_gold_label() -> void:
	_gold_label = Label.new()
	_gold_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gold_label.offset_left   = -130
	_gold_label.offset_top    = 56
	_gold_label.offset_right  = -12
	_gold_label.offset_bottom = 80
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.text = "⬡ %d g" % GameState.gold
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(_gold_label)

func _on_gold_changed(amount: int) -> void:
	if _gold_label != null:
		_gold_label.text = "⬡ %d g" % amount

func _on_short_rest() -> void:
	if CombatManager.in_combat:
		return
	var s = GameState.sarro
	var l = GameState.liris
	if s != null:
		s.second_wind_used = false
		s.shield_bash_cd   = 0.0
	if l != null:
		l.healing_word_charges = 1
	_show_toast("Short rest — short-rest resources recovered.")

func _on_long_rest() -> void:
	if CombatManager.in_combat:
		return
	var s = GameState.sarro
	var l = GameState.liris
	if s != null:
		s.second_wind_used  = false
		s.action_surge_used = false
		s.action_surge_cd   = 0.0
		s.shield_bash_cd    = 0.0
		if s.stats != null:
			s.stats.current_hp = s.stats.max_hp
	if l != null:
		l.healing_word_charges  = 1
		l.guiding_bolt_ready    = true
		l.channel_divinity_ready = true
		if l.stats != null:
			l.stats.current_hp = l.stats.max_hp
		if l.energy_slots != null:
			l.energy_slots.recover_all()  # EnergySlots API
	_show_toast("Long rest — full recovery.")

## Called by level scripts to show encounter result banners.
func show_encounter_result(won: bool) -> void:
	_show_toast("✦ Encounter complete!" if won else "The Veil pulls you back...")

func _on_xp_gained(amount: int) -> void:
	_show_toast("+%d XP  (Level %d — %d XP)" % [amount, GameState.sarro.stats.level, GameState.sarro.stats.xp])

func _on_leveled_up(new_level: int) -> void:
	var msg := "Level %d!" % new_level
	if GameState.sarro != null \
			and not _Progression.pending_choices(GameState.sarro).is_empty():
		msg += "  New choices await at a stable tear."
	elif _Progression.LIRIS_UNLOCKS.has(new_level):
		msg += "  " + str(_Progression.LIRIS_UNLOCKS[new_level])
	_show_toast(msg)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(func(): _toast.visible = false)

func show_boss_phase(phase: int) -> void:
	_show_toast("⚠ Boss Phase %d!" % phase)

## Public toast for level scripts (boss mechanics callouts etc.).
func show_toast_text(text: String) -> void:
	_show_toast(text)

func _process(_delta: float) -> void:
	if _pending_label != null:
		_pending_label.visible = GameState.sarro != null \
			and _Progression.is_choice_driven(GameState.sarro) \
			and not _Progression.pending_choices(GameState.sarro).is_empty()
	if _rest_panel != null:
		_rest_panel.visible = not CombatManager.in_combat
	if _btn_short_rest != null:
		_btn_short_rest.disabled = CombatManager.in_combat
	if _btn_long_rest != null:
		_btn_long_rest.disabled = CombatManager.in_combat

## Superseded by EnemyInfo (configurable enemy widgets); kept as a no-op so
## existing callers need no change. The old top bar stays hidden.
func track_enemy(_enemy: EnemyController) -> void:
	_enemy_row.visible = false

func _on_enemy_hp(current: int, max_hp: int) -> void:
	_enemy_bar.max_value = max_hp
	_enemy_bar.value     = current

func _on_enemy_died() -> void:
	_enemy_row.visible = false
	_tracked_enemy = null
