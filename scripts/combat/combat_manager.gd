## Coordinates a real-time-with-pause combat encounter.
## Owns the SRD CombatOrder, SpellResolver, and per-enemy AIContext wiring.
##
## Usage:
##   var cm := CombatManager.new()
##   cm.setup(party, enemies)
##   cm.start()
##   # each frame: cm.process(delta) while cm.is_active
class_name CombatManager
extends RefCounted

signal combat_started
signal turn_started(combatant: Combatant)
signal turn_ended(combatant: Combatant)
signal combat_ended(party_won: bool)

var _order: CombatOrder = CombatOrder.new()
var _party: Array = []      ## Array[Combatant] — player characters
var _enemies: Array = []    ## Array[Combatant] — AI-controlled
var _spell_resolver: SpellResolver
var _aoe_resolver: AoEResolver
var _surprise: SurpriseTracker = SurpriseTracker.new()
var is_active: bool = false
var is_paused: bool = false

## ai_profile: CombatAI.Profile applied to all enemies (override per-enemy in subclass)
var ai_profile: CombatAI.Profile = CombatAI.Profile.AGGRESSIVE

## Inject custom spell/AoE resolvers — or use defaults.
func setup(party: Array, enemies: Array,
		spell_resolver: SpellResolver = null,
		aoe_resolver: AoEResolver = null) -> void:
	_party = party
	_enemies = enemies
	_spell_resolver = spell_resolver if spell_resolver != null else SpellResolver.new()
	_aoe_resolver = aoe_resolver if aoe_resolver != null else AoEResolver.new()
	var all := party + enemies
	_order.build(all.map(func(c): return c.stats))

func start() -> void:
	is_active = true
	emit_signal("combat_started")
	_begin_turn()

## Call at the end of the current combatant's player-driven turn.
func end_player_turn() -> void:
	_finish_turn(_order.current())
	_advance()

## Pause/resume (real-time-with-pause).
func toggle_pause() -> void:
	is_paused = not is_paused

## Run the current enemy's AI turn and advance. Call from game loop when
## it's an enemy's turn and the game isn't paused.
func run_ai_turn() -> void:
	var current := _current_combatant()
	if current == null or not _is_enemy(current):
		return
	var ctx := _make_ai_context(current)
	var plan := CombatAI.plan_turn(ctx, ai_profile)
	_execute_plan(current, plan)
	_finish_turn(current)
	_advance()

# ── Overridable hooks ─────────────────────────────────────────────────────────

## Override to wire positional queries from the scene. Default: everyone in range.
func build_ai_context(actor: Combatant, allies: Array,
		enemies: Array) -> AIContext:
	var ctx := AIContext.new()
	ctx.actor = actor
	ctx.allies = allies
	ctx.enemies = enemies
	# Default stubs — override in game to use NavigationServer / node positions
	ctx.is_in_melee_range = func(_a, _b): return true
	ctx.can_reach_in_one_move = func(_a, _b): return true
	ctx.distance_feet = func(_a, _b): return 5
	ctx.cover_between = func(_a, _b): return SRD.Cover.NONE
	return ctx

## Override to execute movement, trigger animations, etc.
func execute_plan(_actor: Combatant, _plan: TurnPlan) -> void:
	pass

# ── Private ───────────────────────────────────────────────────────────────────

func _begin_turn() -> void:
	var c := _current_combatant()
	if c == null:
		return
	_surprise.apply_to_turn(c)
	c.action_economy.reset_turn()
	c.action_economy.reset_reaction()
	c.conditions.tick_round()
	emit_signal("turn_started", c)

func _finish_turn(c: Combatant) -> void:
	emit_signal("turn_ended", c)

func _advance() -> void:
	var new_round := _order.advance()
	if new_round:
		_surprise.end_surprise_round()
	if _check_end():
		return
	_begin_turn()

func _check_end() -> bool:
	var party_alive := _party.any(func(c): return c.is_active)
	var enemies_alive := _enemies.any(func(c): return c.is_active)
	if not party_alive or not enemies_alive:
		is_active = false
		emit_signal("combat_ended", party_alive)
		return true
	return false

func _current_combatant() -> Combatant:
	var char := _order.current()
	if char == null:
		return null
	var all: Array = _party + _enemies
	for c: Combatant in all:
		if c.stats == char:
			return c
	return null

func _is_enemy(c: Combatant) -> bool:
	return _enemies.has(c)

func _make_ai_context(actor: Combatant) -> AIContext:
	return build_ai_context(actor, _enemies, _party)

func _execute_plan(actor: Combatant, plan: TurnPlan) -> void:
	execute_plan(actor, plan)
