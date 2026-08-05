## Turn-based combat manager — autoload singleton.
## Owns the TB/RT state machine and initiative queue.
## TB mode: players and enemies act in initiative order, one at a time.
## RT mode: 6-second rounds tick automatically (existing AI loop runs freely).
extends Node

signal combat_started(combatants: Array)
signal combat_ended
signal turn_started(combatant: Node)
signal turn_ended(combatant: Node)
signal tb_mode_changed(enabled: bool)

const FEET_PER_METRE := 3.28084
const RT_ROUND       := 6.0

var tb_mode: bool  = false
var in_combat: bool = false

var _queue:    Array = []   # ordered by initiative roll (descending)
var _turn_idx: int   = 0
var _rt_timer: float = 0.0

# Tracks whose turn it currently is in TB mode.
var current_combatant: Node = null

func _process(delta: float) -> void:
	if in_combat and not tb_mode:
		_rt_timer += delta
		if _rt_timer >= RT_ROUND:
			_rt_timer = 0.0
			_run_rt_round()

# ── Public API ────────────────────────────────────────────────────────────────

func enter_combat(combatants: Array) -> void:
	if in_combat:
		# Add any new combatants not already in the queue.
		for c in combatants:
			if not _queue.has(c):
				_queue.append(c)
				_reset_turn_data(c)
		return

	in_combat = true
	_queue = _roll_initiative(combatants)
	for c in _queue:
		_reset_turn_data(c)

	combat_started.emit(_queue)
	if tb_mode:
		_turn_idx = 0
		_start_turn(_queue[0])

func exit_combat() -> void:
	in_combat = false
	current_combatant = null
	_queue.clear()
	_turn_idx = 0
	_rt_timer = 0.0
	combat_ended.emit()

## Called by player UI "End Turn" button, or by enemy AI when done.
func end_turn() -> void:
	if not tb_mode or not in_combat:
		return
	if current_combatant != null:
		turn_ended.emit(current_combatant)

	_check_combat_end()
	if not in_combat:
		return

	_turn_idx = (_turn_idx + 1) % _queue.size()
	_reset_turn_data(_queue[_turn_idx])
	_start_turn(_queue[_turn_idx])

func enter_tb_mode() -> void:
	if tb_mode:
		return
	tb_mode = true
	tb_mode_changed.emit(true)
	if in_combat and not _queue.is_empty():
		_turn_idx = 0
		_start_turn(_queue[0])

func exit_tb_mode() -> void:
	if not tb_mode:
		return
	tb_mode = false
	current_combatant = null
	tb_mode_changed.emit(false)

## Returns remaining movement in metres for a combatant this turn.
func movement_left(combatant: Node) -> float:
	return combatant.get_meta("turn_movement", 9.0)

## Deduct metres of movement from a combatant's turn economy.
func spend_movement(combatant: Node, metres: float) -> void:
	var left: float = combatant.get_meta("turn_movement", 9.0)
	combatant.set_meta("turn_movement", max(0.0, left - metres))

func has_action(combatant: Node) -> bool:
	return combatant.get_meta("turn_action", false)

func spend_action(combatant: Node) -> void:
	combatant.set_meta("turn_action", false)

func has_bonus_action(combatant: Node) -> bool:
	return combatant.get_meta("turn_bonus", false)

func spend_bonus_action(combatant: Node) -> void:
	combatant.set_meta("turn_bonus", false)

func is_player_turn() -> bool:
	if not tb_mode or current_combatant == null:
		return false
	return current_combatant.is_in_group("players")

# ── Private ───────────────────────────────────────────────────────────────────

func _roll_initiative(combatants: Array) -> Array:
	var rolls: Array = []
	for c in combatants:
		var dex_mod: int = 0
		if c.has_method("get") and c.get("character") != null:
			var ch = c.character
			if ch != null and ch.stats != null:
				dex_mod = (ch.stats.dexterity - 10) / 2
		elif c.has_method("get") and c.get("stats") != null:
			dex_mod = (c.stats.dexterity - 10) / 2
		var roll: int = randi_range(1, 20) + dex_mod
		rolls.append({"node": c, "roll": roll})

	rolls.sort_custom(func(a, b): return a["roll"] > b["roll"])
	var ordered: Array = []
	for r in rolls:
		ordered.append(r["node"])
	return ordered

func _reset_turn_data(c: Node) -> void:
	var speed_ft: int = 30
	if c.has_method("get") and c.get("character") != null:
		var ch = c.character
		if ch != null and ch.stats != null:
			speed_ft = ch.stats.speed
	elif c.has_method("get") and c.get("stats") != null:
		speed_ft = c.stats.speed
	var speed_m: float = speed_ft / FEET_PER_METRE
	c.set_meta("turn_action",   true)
	c.set_meta("turn_bonus",    true)
	c.set_meta("turn_movement", speed_m)
	c.set_meta("turn_disengage", false)
	c.set_meta("turn_dodging",   false)
	c.set_meta("turn_dashed",    false)

func _start_turn(c: Node) -> void:
	current_combatant = c
	_reset_turn_data(c)
	turn_started.emit(c)
	# If it's an enemy, kick off their AI turn.
	if c.is_in_group("enemies") and c.has_method("take_turn"):
		c.take_turn()

func _run_rt_round() -> void:
	_check_combat_end()
	# RT mode: enemies run their own AI via _physics_process; we just check end.

func _check_combat_end() -> void:
	if not in_combat:
		return
	var alive_enemies := false
	var alive_players := false
	for c in _queue:
		if not is_instance_valid(c):
			continue
		var hp := _get_hp(c)
		if hp > 0:
			if c.is_in_group("enemies"):
				alive_enemies = true
			elif c.is_in_group("players"):
				alive_players = true
	if not alive_enemies or not alive_players:
		exit_combat()

func _get_hp(c: Node) -> int:
	if c.has_method("get") and c.get("character") != null:
		var ch = c.character
		if ch != null and ch.stats != null:
			return ch.stats.current_hp
	elif c.has_method("get") and c.get("stats") != null:
		return c.stats.current_hp
	return 1  # unknown — assume alive
