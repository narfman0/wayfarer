## Headless smoke test for the build-choice system (creation + level-up):
## registries, the pending engine, choice application math, save/load
## replay, old-save migration, and (once wired) the rest-point flow.
## Run: godot --headless res://future/tests/harnesses/progression_smoke.tscn
extends Node

const _Factory     = preload("res://scripts/characters/character_factory.gd")
const _Progression = preload("res://scripts/characters/character_progression.gd")
const _Experience  = preload("res://addons/srd/systems/experience.gd")
const _SRD         = preload("res://addons/srd/srd_enums.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_run()

func _run() -> void:
	_test_combat_bonus_math()
	_test_pending_lifecycle()
	_test_save_round_trip()
	_test_old_save_migration()
	_test_auto_resolve()

	if _failures.is_empty():
		print("PROGRESSION SMOKE: ALL PASS")
	else:
		for f in _failures:
			print("PROGRESSION SMOKE FAIL: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _fresh(xp_level: int = 1):
	var c = _Factory.make_custom("Test", "soldier", [16, 14, 14, 10, 12, 10],
		[int(_SRD.Skill.ATHLETICS)])
	if xp_level > 1:
		c.stats.xp = _Experience.xp_for_level(xp_level)
		var lvl_up = preload("res://addons/srd/systems/level_up.gd")
		while c.stats.level < xp_level:
			lvl_up.level_up(c.stats, c.class_data, c.energy_slots)
	return c

# ── Choice math shows up in the Combatant ─────────────────────────────────────

func _test_combat_bonus_math() -> void:
	var c = _fresh()
	var base_ac: int = c.make_combatant().armor_class
	var base_atk: int = c.make_combatant().attack_modifier()
	var base_hp: int = c.stats.max_hp

	_Progression.apply_choice(c, {"kind": "style", "style": "defense"})
	_check(c.make_combatant().armor_class == base_ac + 1, "Defense style: +1 AC")

	_Progression.apply_choice(c, {"kind": "feat", "level": 1, "feat": "tough"})
	_check(c.stats.max_hp == base_hp + 2, "Tough at level 1: +2 max HP")

	var d = _fresh()
	_Progression.apply_choice(d, {"kind": "style", "style": "dueling"})
	var dmg_bonus: int = d.make_combatant().bonus_damage
	_check(dmg_bonus == 2, "Dueling with one-handed longsword: +2 damage")

	var g = _Factory.make_custom("Ghost", "ghost", [10, 16, 12, 14, 12, 10], [])
	_Progression.apply_choice(g, {"kind": "style", "style": "skirmisher"})
	_check(g.make_combatant().crit_threshold == 19, "Skirmisher: crits on 19-20")
	_check(absf(_Progression.speed_multiplier(g) - 1.10) < 0.001, "Skirmisher: +10% speed")

	var r = _fresh()
	var con_before: int = r.stats.get_ability(_SRD.Ability.CONSTITUTION)
	_Progression.apply_choice(r, {"kind": "feat", "level": 1, "feat": "resilient"})
	_check(r.stats.get_ability(_SRD.Ability.CONSTITUTION) == con_before + 1
		and r.stats.is_save_proficient(_SRD.Ability.CONSTITUTION),
		"Resilient: +1 CON and CON save proficiency")

	var a = _fresh(4)
	var str_before: int = a.stats.get_ability(_SRD.Ability.STRENGTH)
	_Progression.apply_choice(a, {"kind": "asi", "level": 4, "mode": "split",
		"abilities": [int(_SRD.Ability.STRENGTH), int(_SRD.Ability.DEXTERITY)]})
	_check(a.stats.get_ability(_SRD.Ability.STRENGTH) == str_before + 1,
		"Split ASI: +1 to each ability")

	var a2 = _fresh(4)
	var hp_before_asi: int = a2.stats.max_hp
	_Progression.apply_choice(a2, {"kind": "asi", "level": 4, "mode": "single",
		"ability": int(_SRD.Ability.CONSTITUTION)})  # 14→16: +1 mod × 4 levels
	_check(a2.stats.max_hp == hp_before_asi + 4,
		"+2 CON retroactively raises max HP by level count")

	_check(_Progression.base_rate_scale(_apply_subclass(_fresh(3), "threshold_thief")) < 1.0,
		"Threshold Thief: faster base attack rhythm")

func _apply_subclass(c, key: String):
	# ghost subclass on a soldier chassis is invalid; make the right class
	var g = _Factory.make_custom("G", "ghost", [10, 16, 12, 14, 12, 10], [])
	_Progression.apply_choice(g, {"kind": "subclass", "subclass": key})
	return g

# ── Pending lifecycle ─────────────────────────────────────────────────────────

func _test_pending_lifecycle() -> void:
	var c = _fresh()
	var kinds := _pending_kinds(c)
	_check(kinds == ["style", "feat"], "level 1: owes style + creation feat (%s)" % [kinds])

	_Progression.apply_choice(c, {"kind": "style", "style": "defense"})
	_Progression.apply_choice(c, {"kind": "feat", "level": 1, "feat": "lucky"})
	_check(_Progression.pending_choices(c).is_empty(), "choices spent → nothing pending")
	_check(c.lucky_points == 3, "Lucky grants 3 points on pick")

	var lvl_up = preload("res://addons/srd/systems/level_up.gd")
	while c.stats.level < 6:
		lvl_up.level_up(c.stats, c.class_data, c.energy_slots)
	kinds = _pending_kinds(c)
	_check(kinds == ["subclass", "asi_or_feat", "asi_or_feat"],
		"soldier at 6: owes subclass + ASI@4 + ASI@6 (%s)" % [kinds])

	_Progression.apply_choice(c, {"kind": "subclass", "subclass": "gatewatch"})
	_Progression.apply_choice(c, {"kind": "feat", "level": 4, "feat": "sentinel"})
	_Progression.apply_choice(c, {"kind": "asi", "level": 6, "mode": "single",
		"ability": int(_SRD.Ability.STRENGTH)})
	_check(_Progression.pending_choices(c).is_empty(), "all level-6 choices spendable")

func _pending_kinds(c) -> Array:
	var out := []
	for p in _Progression.pending_choices(c):
		out.append(str(p["kind"]))
	return out

# ── Persistence ───────────────────────────────────────────────────────────────

func _test_save_round_trip() -> void:
	var c = _fresh(6)
	_Progression.apply_choice(c, {"kind": "style", "style": "great_weapon"})
	_Progression.apply_choice(c, {"kind": "feat", "level": 1, "feat": "tough"})
	_Progression.apply_choice(c, {"kind": "subclass", "subclass": "anchor"})
	_Progression.apply_choice(c, {"kind": "asi", "level": 4, "mode": "single",
		"ability": int(_SRD.Ability.CONSTITUTION)})
	_Progression.apply_choice(c, {"kind": "feat", "level": 6, "feat": "gwm"})

	# JSON round-trip like the real save file
	var d: Dictionary = str_to_var(var_to_str(_Factory.to_save_dict(c)))
	var r = _Factory.make_from_save(d)
	_check(r.fighting_style == "great_weapon" and r.subclass_key == "anchor"
		and "tough" in r.feat_keys and "gwm" in r.feat_keys,
		"round-trip preserves style/subclass/feats")
	_check(r.stats.max_hp == c.stats.max_hp,
		"round-trip max HP identical (%d vs %d) — no double-applied ASI/Tough" %
			[r.stats.max_hp, c.stats.max_hp])
	_check(r.stats.get_ability(_SRD.Ability.CONSTITUTION)
		== c.stats.get_ability(_SRD.Ability.CONSTITUTION),
		"round-trip CON identical — base scores saved, choices replayed")
	_check(_Progression.pending_choices(r).is_empty(), "loaded character owes nothing")

	# double round-trip = idempotence
	var r2 = _Factory.make_from_save(str_to_var(var_to_str(_Factory.to_save_dict(r))))
	_check(r2.stats.max_hp == c.stats.max_hp, "second round-trip still identical")

func _test_old_save_migration() -> void:
	# a hand-built v3-era dict: live scores, no choices key
	var old := {
		"name": "Sarro", "class_key": "soldier",
		"scores": [16, 14, 14, 10, 12, 10],
		"skill_mask": 0, "current_hp": 30,
		"xp": _Experience.xp_for_level(5),
	}
	var c = _Factory.make_from_save(old)
	_check(c.stats.level == 5, "old save levels up to 5")
	var kinds := _pending_kinds(c)
	_check("style" in kinds and "subclass" in kinds and kinds.count("asi_or_feat") == 1,
		"old save owes style, creation feat, subclass, ASI@4 (%s)" % [kinds])

func _test_auto_resolve() -> void:
	var c = _fresh(8)
	_Progression.auto_resolve(c)
	_check(_Progression.pending_choices(c).is_empty(), "auto_resolve spends everything")
	_check(c.fighting_style != "" and c.subclass_key != "", "auto_resolve picks style+subclass")

func _check(cond: bool, label: String) -> void:
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures.append(label)
