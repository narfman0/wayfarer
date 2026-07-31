## Combat outcome tests — validate that each scenario produces expected win rates
## and that deterministic runs resolve correctly.
extends GutTest

# ── Deterministic sanity checks ──────────────────────────────────────────────

func test_tavern_brawl_deterministic_party_wins():
	var sim := _det_sim()
	var result := sim.run(ScenarioTavernBrawl.make_party(), ScenarioTavernBrawl.make_enemies())
	assert_true(result.party_won,
		"Party should win tavern brawl at median rolls (d20=11, avg damage)")

func test_open_ambush_deterministic_resolves():
	var sim := _det_sim()
	var result := sim.run(ScenarioOpenAmbush.make_party(), ScenarioOpenAmbush.make_enemies())
	assert_false(result.draw,
		"Open ambush should not draw — someone wins within %d rounds" % sim.max_rounds)

func test_boss_mender_deterministic_resolves():
	var sim := _det_sim()
	var result := sim.run(ScenarioBossMender.make_party(), ScenarioBossMender.make_enemies())
	assert_false(result.draw, "Boss fight should resolve within max rounds")

# ── Statistical win-rate checks (random rolls, N trials) ──────────────────

func test_tavern_brawl_party_wins_majority():
	var wins := _run_trials(ScenarioTavernBrawl, 30)
	assert_gte(wins, 16,
		"Party should win tavern brawl >50%% of the time (%d/30)" % wins)

func test_boss_mender_is_a_real_threat():
	var wins := _run_trials(ScenarioBossMender, 20)
	assert_lt(wins, 18,
		"Boss scenario should not be a cakewalk — party should lose sometimes (%d/20 wins)" % wins)

# ── Round-count sanity ────────────────────────────────────────────────────────

func test_tavern_brawl_ends_quickly():
	var sim := _det_sim()
	var result := sim.run(ScenarioTavernBrawl.make_party(), ScenarioTavernBrawl.make_enemies())
	assert_lte(result.rounds_elapsed, 10,
		"Tavern brawl should resolve in ≤10 rounds at deterministic rolls")

# ── BattleResult log structure ────────────────────────────────────────────────

func test_round_log_has_attack_events():
	var sim := _det_sim()
	var result := sim.run(ScenarioTavernBrawl.make_party(), ScenarioTavernBrawl.make_enemies())
	var attacks := sim.count_events(result, 1, "attack")
	assert_gt(attacks, 0, "Round 1 should contain at least one attack event")

func test_round_log_snapshot_fields():
	var sim := _det_sim()
	var result := sim.run(ScenarioTavernBrawl.make_party(), ScenarioTavernBrawl.make_enemies())
	var snap: Dictionary = result.round_logs[0]["end_state"]
	assert_true(snap.has("party_alive"),      "Snapshot must have party_alive")
	assert_true(snap.has("enemy_total_hp"),   "Snapshot must have enemy_total_hp")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _det_sim() -> BattleSimulator:
	var s := BattleSimulator.new()
	s.fixed_d20 = 11
	s.use_average_damage = true
	s.max_rounds = 30
	return s

func _run_trials(scenario, n: int) -> int:
	var sim := BattleSimulator.new()
	sim.max_rounds = 30
	var wins := 0
	for _i in n:
		var result := sim.run(scenario.make_party(), scenario.make_enemies())
		if result.party_won:
			wins += 1
	return wins
