## In-world HUD: party HP bars + targeted enemy HP.
class_name HUD
extends Control

@onready var _sarro_bar:  ProgressBar = $Party/SarroHP
@onready var _liris_bar:  ProgressBar = $Party/LirisHP
@onready var _enemy_row:  HBoxContainer = $EnemyRow
@onready var _enemy_bar:  ProgressBar = $EnemyRow/EnemyHP
@onready var _enemy_name: Label = $EnemyRow/EnemyName

var _tracked_enemy: EnemyController = null
var _toast: Label

func _ready() -> void:
	_enemy_row.visible = false
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 60
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.visible = false
	add_child(_toast)
	GameState.xp_gained.connect(_on_xp_gained)
	GameState.leveled_up.connect(_on_leveled_up)

func _on_xp_gained(amount: int) -> void:
	_show_toast("+%d XP  (Level %d — %d XP)" % [amount, GameState.sarro.stats.level, GameState.sarro.stats.xp])

func _on_leveled_up(new_level: int) -> void:
	_show_toast("Level %d!" % new_level)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(func(): _toast.visible = false)

func _process(_delta: float) -> void:
	_refresh_party()

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
