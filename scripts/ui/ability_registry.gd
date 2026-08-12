## Central lookup: given a WayfarerCharacter, returns a list of ability dicts
## that describe the icon-bar slots (name, tooltip, ready/activate callables).
class_name AbilityRegistry
extends RefCounted

static func abilities_for(char) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if char == null:
		return out

	var name_lc: String = String(char.display_name).to_lower()
	var is_sarro: bool = name_lc.begins_with("sarro")
	var is_liris: bool = name_lc.begins_with("liris")

	if is_sarro:
		out.append(_second_wind(char))
		out.append(_heavy_strike(char))
		if char.stats != null and char.stats.level >= 3:
			out.append(_shield_bash(char))
		if char.stats != null and char.stats.level >= 2:
			out.append(_action_surge(char))

	if is_liris:
		out.append(_guiding_bolt(char))
		out.append(_healing_word(char))
		out.append(_channel_divinity(char))

	# Maneuvers — every player character fights with their hands too.
	if is_sarro:
		out.append(_shove(char))
		out.append(_grapple(char))
		out.append(_class_flavor(char))

	# Known-spell entries (one per spell) — Sarro or anyone with spells.
	if char.get("known_spells") != null:
		var i: int = 0
		for sp in char.known_spells:
			out.append(_spell_entry(char, sp, i))
			i += 1

	return out

# ── Sarro abilities ───────────────────────────────────────────────────────────

static func _second_wind(char) -> Dictionary:
	return {
		"id": "second_wind",
		"name": "Second Wind",
		"description": "Self-heal drawing on your reserves. Recovers on short rest.",
		"cost": "instant",
		"attack_roll": "",
		"damage": "1d10+%d healing" % char.stats.level,
		"icon_color": Color(0.75, 0.35, 0.35),
		"keybind": "1",
		"is_ready": func() -> bool: return not char.second_wind_used,
		"activate": _trigger_action("ability_1"),
	}

static func _heavy_strike(char) -> Dictionary:
	return {
		"id": "heavy_strike",
		"name": "Heavy Strike",
		"description": "Prime your next swing: +2d6 damage and a stagger. Short cooldown.",
		"cost": "free",
		"attack_roll": "",
		"damage": "+2d6 + stagger",
		"icon_color": Color(0.95, 0.5, 0.2),
		"keybind": "Q",
		"is_ready": func() -> bool:
			return not char.heavy_strike_primed and char.heavy_strike_cd <= 0.0,
		"activate": _trigger_action("ability_7"),
	}

static func _shield_bash(char) -> Dictionary:
	return {
		"id": "shield_bash",
		"name": "Shield Bash",
		"description": "Slam your shield into the target. Damages and knocks prone. Short cooldown.",
		"cost": "combat",
		"attack_roll": "+%d to hit" % _prof_plus_str(char),
		"damage": "1d6 bludgeoning + prone",
		"icon_color": Color(0.55, 0.55, 0.65),
		"keybind": "5",
		"is_ready": func() -> bool: return char.shield_bash_cd <= 0.0,
		"activate": _trigger_action("ability_5"),
	}

static func _action_surge(char) -> Dictionary:
	var freeblade: bool = char.subclass_key == "freeblade"
	var desc: String = "Take an additional action this turn. "
	desc += "Freeblade: short cooldown." if freeblade else "Recovers on short rest."
	return {
		"id": "action_surge",
		"name": "Action Surge",
		"description": desc,
		"cost": "free",
		"attack_roll": "",
		"damage": "",
		"icon_color": Color(0.95, 0.65, 0.25),
		"keybind": "6",
		"is_ready": func() -> bool:
			if freeblade:
				return char.action_surge_cd <= 0.0
			return not char.action_surge_used,
		"activate": _trigger_action("ability_6"),
	}

static func _shove(char) -> Dictionary:
	return {
		"id": "shove",
		"name": "Shove",
		"description": "Contested STR: knock the target away from you. Edges are fair game.",
		"cost": "melee range",
		"attack_roll": "STR vs STR",
		"damage": "knockback",
		"icon_color": Color(0.85, 0.6, 0.35),
		"keybind": "E",
		"is_ready": func() -> bool: return char.shove_cd <= 0.0,
		"activate": _trigger_action("ability_8"),
	}

static func _grapple(char) -> Dictionary:
	return {
		"id": "grapple",
		"name": "Grapple",
		"description": "Contested STR: hold the target in place. They get one escape attempt; attacks against a held target have advantage.",
		"cost": "melee range",
		"attack_roll": "STR vs STR",
		"damage": "hold 2.5s",
		"icon_color": Color(0.6, 0.5, 0.4),
		"keybind": "G",
		"is_ready": func() -> bool: return char.grapple_cd <= 0.0,
		"activate": _trigger_action("ability_9"),
	}

static func _class_flavor(char) -> Dictionary:
	var cls := ""
	if char.class_data != null:
		cls = String(char.class_data.class_name_str).to_lower()
	var name := "Trip"
	var desc := "Contested STR vs DEX: knock the target prone — attacks against them have advantage."
	var color := Color(1.0, 0.7, 0.3)
	match cls:
		"ghost":
			name = "Feint"
			desc = "A misleading step: your next attack within 3s has advantage."
			color = Color(0.7, 0.75, 0.95)
		"warden":
			name = "Ward"
			desc = "A borrowed current shields you: absorbs 8 + level damage."
			color = Color(0.5, 0.8, 1.0)
		"psion":
			name = "Repel"
			desc = "Imposed certainty: every nearby enemy is shoved away."
			color = Color(0.8, 0.55, 1.0)
	return {
		"id": "class_flavor",
		"name": name,
		"description": desc,
		"cost": "class",
		"attack_roll": "",
		"damage": "",
		"icon_color": color,
		"keybind": "R",
		"is_ready": func() -> bool: return char.flavor_cd <= 0.0,
		"activate": _trigger_action("ability_10"),
	}

# ── Liris abilities ───────────────────────────────────────────────────────────

static func _guiding_bolt(char) -> Dictionary:
	return {
		"id": "guiding_bolt",
		"name": "Guiding Bolt",
		"description": "Radiant lance that grants advantage to the next attack against the target.",
		"cost": "combat",
		"attack_roll": "+%d spell attack" % _spell_atk(char),
		"damage": "4d6 radiant",
		"icon_color": Color(0.95, 0.85, 0.4),
		"keybind": "2",
		"is_ready": func() -> bool: return char.guiding_bolt_ready,
		"activate": _trigger_action("ability_2"),
	}

static func _healing_word(char) -> Dictionary:
	return {
		"id": "healing_word",
		"name": "Healing Word",
		"description": "Whispered mercy — restore an ally at range.",
		"cost": "instant",
		"attack_roll": "",
		"damage": "1d4+%d healing" % _cha_mod(char),
		"icon_color": Color(0.4, 0.9, 0.55),
		"keybind": "3",
		"is_ready": func() -> bool: return char.healing_word_charges > 0,
		"activate": _trigger_action("ability_3"),
	}

static func _channel_divinity(char) -> Dictionary:
	return {
		"id": "channel_divinity",
		"name": "Channel Divinity",
		"description": "Invoke divine power — Sacred Flame damage or Turn Undead. Recovers on short rest.",
		"cost": "combat",
		"attack_roll": "DC %d save" % (8 + _prof(char) + _cha_mod(char)),
		"damage": "2d8 radiant",
		"icon_color": Color(0.85, 0.55, 0.95),
		"keybind": "4",
		"is_ready": func() -> bool: return char.channel_divinity_ready,
		"activate": _trigger_action("ability_4"),
	}

# ── Spell entries ─────────────────────────────────────────────────────────────

static func _spell_entry(char, sp, index: int) -> Dictionary:
	var cost: String = "quick cast" if sp.is_bonus_action else "cast"
	# Spell hotkeys 7 8 9 0 (dispatched by the skill bar, not input actions)
	var kb: String = "" if index >= 4 else ("0" if index == 3 else str(7 + index))
	return {
		"id": "spell_%s" % String(sp.spell_name).to_lower().replace(" ", "_"),
		"name": String(sp.spell_name),
		"description": String(sp.description),
		"cost": cost,
		"attack_roll": "",
		"damage": _spell_damage_text(sp),
		"icon_color": Color(0.5, 0.4, 0.9),
		"keybind": kb,
		"is_ready": func() -> bool:
			if sp.spell_level <= 0:
				return true  # cantrips are always available
			return char.energy_slots != null and char.energy_slots.has_slot(sp.spell_level),
		"activate": func() -> void:
			var tree := Engine.get_main_loop() as SceneTree
			var lvl = tree.current_scene if tree != null else null
			if lvl != null and lvl.has_method("cast_spell"):
				lvl.cast_spell(sp, char),
	}

static func _spell_damage_text(sp) -> String:
	if sp.damage_dice > 0:
		return "%dd%d" % [sp.damage_count, sp.damage_dice]
	if sp.heal_dice > 0:
		return "%dd%d healing" % [sp.heal_count, sp.heal_dice]
	return ""

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _trigger_action(action: String) -> Callable:
	return func() -> void:
		Input.action_press(action)
		Input.action_release(action)

static func _prof(char) -> int:
	if char.stats == null:
		return 2
	return 2 + int(float(max(char.stats.level - 1, 0)) / 4.0)

static func _prof_plus_str(char) -> int:
	return _prof(char) + 3

static func _cha_mod(char) -> int:
	if char.stats != null and char.stats.get("charisma") != null:
		return int(float(char.stats.charisma - 10) / 2.0)
	return 3

static func _spell_atk(char) -> int:
	return _prof(char) + _cha_mod(char)
