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
		if char.stats != null and char.stats.level >= 3:
			out.append(_shield_bash(char))
		if char.stats != null and char.stats.level >= 2:
			out.append(_action_surge(char))

	if is_liris:
		out.append(_guiding_bolt(char))
		out.append(_healing_word(char))
		out.append(_channel_divinity(char))

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
		"cost": "bonus_action",
		"attack_roll": "",
		"damage": "1d10+%d healing" % char.stats.level,
		"icon_color": Color(0.75, 0.35, 0.35),
		"keybind": "1",
		"is_ready": func() -> bool: return not char.second_wind_used,
		"activate": _trigger_action("ability_1"),
	}

static func _shield_bash(char) -> Dictionary:
	return {
		"id": "shield_bash",
		"name": "Shield Bash",
		"description": "Slam your shield into the target. Damages and knocks prone. Short cooldown.",
		"cost": "action",
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

# ── Liris abilities ───────────────────────────────────────────────────────────

static func _guiding_bolt(char) -> Dictionary:
	return {
		"id": "guiding_bolt",
		"name": "Guiding Bolt",
		"description": "Radiant lance that grants advantage to the next attack against the target.",
		"cost": "action",
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
		"cost": "bonus_action",
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
		"cost": "action",
		"attack_roll": "DC %d save" % (8 + _prof(char) + _cha_mod(char)),
		"damage": "2d8 radiant",
		"icon_color": Color(0.85, 0.55, 0.95),
		"keybind": "4",
		"is_ready": func() -> bool: return char.channel_divinity_ready,
		"activate": _trigger_action("ability_4"),
	}

# ── Spell entries ─────────────────────────────────────────────────────────────

static func _spell_entry(char, sp, index: int) -> Dictionary:
	var cost: String = "bonus_action" if sp.is_bonus_action else "action"
	var kb: String = "" if index >= 4 else str(7 + index)
	return {
		"id": "spell_%s" % String(sp.spell_name).to_lower().replace(" ", "_"),
		"name": String(sp.spell_name),
		"description": String(sp.description),
		"cost": cost,
		"attack_roll": "",
		"damage": "",
		"icon_color": Color(0.5, 0.4, 0.9),
		"keybind": kb,
		"is_ready": func() -> bool:
			if char.energy_slots != null and char.energy_slots.has_method("slots_remaining"):
				return char.energy_slots.slots_remaining(1) > 0
			return true,
		"activate": _trigger_action("ability_spells"),
	}

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
