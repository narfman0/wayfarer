## AI behavior tests — verify that each CombatAI profile makes sensible decisions
## in controlled contexts (stubbed AIContext with known conditions).
extends GutTest

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_sarro_combatant() -> Combatant:
	return WayfarerCharacter.make_sarro().make_combatant()

func _make_weakened_sarro() -> Combatant:
	var c := WayfarerCharacter.make_sarro().make_combatant()
	c.stats.current_hp = 3  # < 30% of 12
	return c

func _make_ctx(actor: Combatant, allies: Array, enemies: Array) -> AIContext:
	var ctx := AIContext.new()
	ctx.actor = actor
	ctx.allies = allies
	ctx.enemies = enemies
	ctx.is_in_melee_range   = func(_a, _b): return true
	ctx.can_reach_in_one_move = func(_a, _b): return true
	ctx.distance_feet       = func(_a, _b): return 5
	ctx.cover_between       = func(_a, _b): return SRD.Cover.NONE
	return ctx

# ── AGGRESSIVE profile ────────────────────────────────────────────────────────

func test_aggressive_targets_weakest_enemy():
	var actor   := _make_sarro_combatant()
	var weak    := FixtureRonin.make(1); weak.stats.current_hp = 1
	var strong  := FixtureRonin.make(1)
	var ctx     := _make_ctx(actor, [actor], [weak, strong])
	var plan    := CombatAI.plan_turn(ctx, CombatAI.Profile.AGGRESSIVE)
	assert_eq(plan.action_target, weak,
		"AGGRESSIVE should target the weakest enemy")

func test_aggressive_has_action():
	var actor := _make_sarro_combatant()
	var enemy := FixtureRonin.make(1)
	var ctx   := _make_ctx(actor, [actor], [enemy])
	var plan  := CombatAI.plan_turn(ctx, CombatAI.Profile.AGGRESSIVE)
	assert_ne(plan.action_choice, TurnPlan.ActionChoice.NONE,
		"AGGRESSIVE should always choose an action when enemies are present")

# ── DEFENSIVE profile ─────────────────────────────────────────────────────────

func test_defensive_dodges_when_low_hp():
	var actor := _make_weakened_sarro()  # 3/12 HP — below 30%
	var enemy := FixtureRonin.make(1)
	var ctx   := _make_ctx(actor, [actor], [enemy])
	var plan  := CombatAI.plan_turn(ctx, CombatAI.Profile.DEFENSIVE)
	assert_eq(plan.action_choice, TurnPlan.ActionChoice.DODGE,
		"DEFENSIVE should Dodge when below 30%% HP and enemies are in range")

func test_defensive_attacks_when_healthy():
	var actor := _make_sarro_combatant()  # full HP
	var enemy := FixtureRonin.make(1)
	var ctx   := _make_ctx(actor, [actor], [enemy])
	var plan  := CombatAI.plan_turn(ctx, CombatAI.Profile.DEFENSIVE)
	assert_ne(plan.action_choice, TurnPlan.ActionChoice.DODGE,
		"DEFENSIVE should not Dodge at full HP")

# ── SKIRMISHER profile ────────────────────────────────────────────────────────

func test_skirmisher_attacks_reachable_enemy():
	var actor := _make_sarro_combatant()
	var enemy := FixtureRonin.make(1)
	var ctx   := _make_ctx(actor, [actor], [enemy])
	var plan  := CombatAI.plan_turn(ctx, CombatAI.Profile.SKIRMISHER)
	assert_ne(plan.action_target, null,
		"SKIRMISHER should pick a target when enemy is reachable")

# ── SUPPORT profile ───────────────────────────────────────────────────────────

func test_support_helps_injured_ally():
	var actor  := WayfarerCharacter.make_liris().make_combatant()
	var injured := _make_sarro_combatant(); injured.stats.current_hp = 2
	var enemy  := FixtureRonin.make(1)
	var ctx    := _make_ctx(actor, [actor, injured], [enemy])
	var plan   := CombatAI.plan_turn(ctx, CombatAI.Profile.SUPPORT)
	assert_eq(plan.action_choice, TurnPlan.ActionChoice.HELP,
		"SUPPORT should Help the most-injured ally when one is present")

func test_support_bonus_action_not_none_when_ally_injured():
	var actor  := WayfarerCharacter.make_liris().make_combatant()
	var injured := _make_sarro_combatant(); injured.stats.current_hp = 1
	var enemy  := FixtureRonin.make(1)
	var ctx    := _make_ctx(actor, [actor, injured], [enemy])
	var plan   := CombatAI.plan_turn(ctx, CombatAI.Profile.SUPPORT)
	# Support may use bonus action for Channel Divinity or similar
	assert_true(plan.action_choice != TurnPlan.ActionChoice.NONE or
				plan.bonus_choice  != TurnPlan.BonusActionChoice.NONE,
		"SUPPORT should take some action when an ally is critically injured")
