## In-engine combat sandbox — pick a scenario, run it, inspect the log.
## Useful for tuning balance and validating AI behaviour visually.
class_name CombatLab
extends Control

const SCENARIOS := [
	ScenarioTavernBrawl,
	ScenarioOpenAmbush,
	ScenarioBossMender,
]

const SCENARIO_NAMES := [
	"Tavern Brawl (2v3)",
	"Open Ambush (2v5)",
	"Boss Mender (2v3)",
]

@onready var _scenario_pick: OptionButton = $Layout/Controls/ScenarioPicker
@onready var _mode_pick:     OptionButton = $Layout/Controls/ModePicker
@onready var _run_btn:       Button       = $Layout/Controls/RunButton
@onready var _trials_spin:   SpinBox      = $Layout/Controls/Trials
@onready var _log:           RichTextLabel = $Layout/Log
@onready var _summary:       Label        = $Layout/Summary

func _ready() -> void:
	for name in SCENARIO_NAMES:
		_scenario_pick.add_item(name)
	_mode_pick.add_item("Random rolls")
	_mode_pick.add_item("Deterministic (d20=11, avg dmg)")
	_run_btn.pressed.connect(_on_run)

func _on_run() -> void:
	_log.clear()
	_summary.text = "Running…"
	var scenario_idx := _scenario_pick.selected
	var deterministic := _mode_pick.selected == 1
	var trials := int(_trials_spin.value)

	if trials == 1:
		_run_single(scenario_idx, deterministic)
	else:
		_run_batch(scenario_idx, trials)

func _run_single(scenario_idx: int, deterministic: bool) -> void:
	var scenario = SCENARIOS[scenario_idx]
	var sim := _make_sim(deterministic)
	var result: BattleSimulator.BattleResult = sim.run(
		scenario.make_party(), scenario.make_enemies()
	)

	_log.append_text("[b]%s[/b] — %s\n\n" % [
		SCENARIO_NAMES[scenario_idx],
		"Deterministic" if deterministic else "Random"
	])

	for round_data in result.round_logs:
		_log.append_text("[color=yellow]Round %d[/color]\n" % round_data["round"])
		for ev in round_data["events"]:
			_log.append_text("  %s\n" % _format_event(ev))
		var snap: Dictionary = round_data["end_state"]
		_log.append_text("  Party HP: %d (%d alive)  |  Enemy HP: %d (%d alive)\n\n" % [
			snap.get("party_total_hp", 0), snap.get("party_alive", 0),
			snap.get("enemy_total_hp", 0), snap.get("enemy_alive", 0),
		])

	var winner := result.winner().to_upper()
	_summary.text = "Result: %s in %d round(s)" % [winner, result.rounds_elapsed]

func _run_batch(scenario_idx: int, trials: int) -> void:
	var scenario = SCENARIOS[scenario_idx]
	var sim := _make_sim(false)
	var wins := 0; var losses := 0; var draws := 0
	var total_rounds := 0
	for _i in trials:
		var r: BattleSimulator.BattleResult = sim.run(
			scenario.make_party(), scenario.make_enemies()
		)
		if r.party_won:   wins   += 1
		elif r.enemy_won: losses += 1
		else:             draws  += 1
		total_rounds += r.rounds_elapsed

	_log.append_text("[b]%s — %d trials[/b]\n\n" % [SCENARIO_NAMES[scenario_idx], trials])
	_log.append_text("Party wins:   %d (%.0f%%)\n" % [wins,   100.0 * wins   / trials])
	_log.append_text("Enemy wins:   %d (%.0f%%)\n" % [losses, 100.0 * losses / trials])
	_log.append_text("Draws:        %d\n"          % draws)
	_log.append_text("Avg rounds:   %.1f\n"        % (float(total_rounds) / trials))
	_summary.text = "%d/%d party wins (%.0f%%)" % [wins, trials, 100.0 * wins / trials]

func _make_sim(deterministic: bool) -> BattleSimulator:
	var s := BattleSimulator.new()
	s.max_rounds = 30
	if deterministic:
		s.fixed_d20 = 11
		s.use_average_damage = true
	return s

func _format_event(ev: Dictionary) -> String:
	match ev.get("type", ""):
		"attack":
			var hit_str := "[color=red]MISS[/color]"
			if ev.get("crit"): hit_str = "[color=gold]CRIT[/color]"
			elif ev.get("hit"): hit_str = "[color=green]HIT %d[/color]" % ev.get("damage", 0)
			return "%s → %s: %s (d20=%d+%d vs AC%d)" % [
				ev.get("attacker","?"), ev.get("target","?"), hit_str,
				ev.get("d20",0), ev.get("attack_mod",0), ev.get("target_ac",0),
			]
		"death_save":
			return "%s death save: %d success / %d fail%s" % [
				ev.get("actor","?"),
				ev.get("successes",0), ev.get("failures",0),
				" — STABLE" if ev.get("stable") else (" — DEAD" if ev.get("dead") else ""),
			]
	return str(ev)
