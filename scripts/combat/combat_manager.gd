## Real-time combat manager — autoload singleton.
## Owns encounter membership and end-of-combat detection. Combat runs in
## real time: the archetype AI in EnemyController acts freely; this node
## just tracks who is in the fight and polls for its end each round.
extends Node

signal combat_started(combatants: Array)
signal combat_ended

const RT_ROUND := 6.0

var in_combat: bool = false

var _queue: Array = []      # every combatant in the encounter
var _rt_timer: float = 0.0

func _process(delta: float) -> void:
	if in_combat:
		_rt_timer += delta
		if _rt_timer >= RT_ROUND:
			_rt_timer = 0.0
			_check_combat_end()

func enter_combat(combatants: Array) -> void:
	if in_combat:
		for c in combatants:
			if not _queue.has(c):
				_queue.append(c)
		return
	in_combat = true
	_queue = combatants.duplicate()
	combat_started.emit(_queue)

func exit_combat() -> void:
	in_combat = false
	_queue.clear()
	_rt_timer = 0.0
	combat_ended.emit()

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
