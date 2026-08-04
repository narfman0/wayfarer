## In-world HUD: party HP bars + targeted enemy HP + ability hotbar.
class_name HUD
extends Control

@onready var _sarro_bar:  ProgressBar = $Party/SarroHP
@onready var _liris_bar:  ProgressBar = $Party/LirisHP
@onready var _enemy_row:  HBoxContainer = $EnemyRow
@onready var _enemy_bar:  ProgressBar = $EnemyRow/EnemyHP
@onready var _enemy_name: Label = $EnemyRow/EnemyName

const _Progression = preload("res://scripts/characters/character_progression.gd")

var _tracked_enemy: EnemyController = null
var _toast: Label
var _sarro_label: Label   # hotbar row for Sarro
var _liris_label: Label   # hotbar row for Liris
var _pending_label: Label # "choices await at a stable tear" hint

func _ready() -> void:
	_enemy_row.visible = false

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 60
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.visible = false
	add_child(_toast)

	_sarro_label = Label.new()
	_sarro_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sarro_label.position.y = -62
	_sarro_label.add_theme_font_size_override("font_size", 15)
	add_child(_sarro_label)

	_liris_label = Label.new()
	_liris_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_liris_label.position.y = -40
	_liris_label.add_theme_font_size_override("font_size", 15)
	add_child(_liris_label)

	_pending_label = Label.new()
	_pending_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pending_label.position.y = 92
	_pending_label.add_theme_font_size_override("font_size", 16)
	_pending_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_pending_label.text = "✦ Choices await — rest at a stable tear"
	_pending_label.visible = false
	add_child(_pending_label)

	GameState.xp_gained.connect(_on_xp_gained)
	GameState.leveled_up.connect(_on_leveled_up)

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
	_refresh_party()
	_refresh_hotbar()
	if _pending_label != null:
		_pending_label.visible = GameState.sarro != null \
			and _Progression.is_choice_driven(GameState.sarro) \
			and not _Progression.pending_choices(GameState.sarro).is_empty()

func _refresh_hotbar() -> void:
	if GameState.sarro != null and _sarro_label != null:
		var sc = GameState.sarro
		var sw := "Ready" if not sc.second_wind_used else "Spent"
		var line := "Sarro — [1] Second Wind: %s" % sw
		if sc.stats.level >= 2:
			line += "  [6] Action Surge: %s" % ("Ready" if not sc.action_surge_used else "Spent")
		if sc.stats.level >= 3:
			var sb := "Ready" if sc.shield_bash_cd <= 0.0 else "%ds" % ceili(sc.shield_bash_cd)
			line += "  [5] Shield Bash: %s" % sb
		_sarro_label.text = line
		_sarro_label.modulate = Color(0.6, 1.0, 0.7) if not sc.second_wind_used or sc.shield_bash_cd <= 0.0 else Color(0.55, 0.55, 0.6)

	if GameState.liris != null and _liris_label != null:
		var lc = GameState.liris
		var gb := "Ready" if lc.guiding_bolt_ready else "Spent"
		var hw := "%d charge" % lc.healing_word_charges if lc.healing_word_charges == 1 else "Spent"
		var cd := "Ready" if lc.channel_divinity_ready else "Spent"
		_liris_label.text = "Liris — [2] Guiding Bolt: %s  [3] Healing Word: %s  [4] Channel Divinity: %s" % [gb, hw, cd]
		var any_ready: bool = lc.guiding_bolt_ready or lc.healing_word_charges > 0 or lc.channel_divinity_ready
		_liris_label.modulate = Color(0.6, 0.8, 1.0) if any_ready else Color(0.55, 0.55, 0.6)

func track_enemy(enemy: EnemyController) -> void:
	if _tracked_enemy != null:
		if _tracked_enemy.hp_changed.is_connected(_on_enemy_hp):
			_tracked_enemy.hp_changed.disconnect(_on_enemy_hp)
		if _tracked_enemy.died.is_connected(_on_enemy_died):
			_tracked_enemy.died.disconnect(_on_enemy_died)

	_tracked_enemy = enemy
	if enemy == null:
		_enemy_row.visible = false
		return

	_enemy_row.visible = true
	_enemy_name.text = enemy.name
	enemy.hp_changed.connect(_on_enemy_hp)
	enemy.died.connect(_on_enemy_died)
	if enemy.character != null:
		_enemy_bar.max_value = enemy.character.stats.max_hp
		_enemy_bar.value     = enemy.character.stats.current_hp

func _refresh_party() -> void:
	if GameState.sarro != null:
		_sarro_bar.max_value = GameState.sarro.stats.max_hp
		_sarro_bar.value     = GameState.sarro.stats.current_hp
	if GameState.liris != null:
		_liris_bar.max_value = GameState.liris.stats.max_hp
		_liris_bar.value     = GameState.liris.stats.current_hp

func _on_enemy_hp(current: int, max_hp: int) -> void:
	_enemy_bar.max_value = max_hp
	_enemy_bar.value     = current

func _on_enemy_died() -> void:
	_enemy_row.visible = false
	_tracked_enemy = null
