## Factory for creating pre-configured WayfarerCharacter instances.
## Kept separate from wayfarer_character.gd to avoid circular class_name
## self-reference in static methods (Godot 4.7 runtime parse limitation).
extends RefCounted

const _WC         = preload("res://scripts/characters/wayfarer_character.gd")
const _ClassData  = preload("res://addons/srd/resources/class_data.gd")
const _WeaponData = preload("res://addons/srd/resources/weapon_data.gd")
const _ArmorData  = preload("res://addons/srd/resources/armor_data.gd")
const _SRD        = preload("res://addons/srd/srd_enums.gd")
const _LevelUp    = preload("res://addons/srd/systems/level_up.gd")
const _Experience = preload("res://addons/srd/systems/experience.gd")

## Playable classes. Psion/Warden exist in the SRD addon but stay out of the
## game until spellcasting is wired into combat.
const CLASS_KEYS := ["soldier", "ghost"]

static func make_class_data(class_key: String):
	match class_key:
		"soldier": return _ClassData.make_soldier()
		"ghost":   return _ClassData.make_ghost()
	return null

## Build a level-1 character from SRD creation choices.
## scores: 6-element Array[int] indexed by SRD.Ability.
## skill_picks: Array of SRD.Skill ints (validated against class skill_options).
static func make_custom(display_name: String, class_key: String,
		scores: Array, skill_picks: Array):
	var c = _WC.new()
	var cd = make_class_data(class_key)
	assert(cd != null, "Unknown class key: " + class_key)
	c.display_name = display_name
	c.stats.character_name = display_name
	c.stats.level = 1
	c.stats.hit_die = cd.hit_die
	c.stats.speed = 30
	for i in 6:
		c.stats.set_ability(i as _SRD.Ability, scores[i])
	c.class_data = cd
	_LevelUp.apply_class_proficiencies(c.stats, cd)
	for skill in skill_picks:
		if int(skill) in cd.skill_options:
			c.stats.set_skill_proficiency(skill as _SRD.Skill, true)
	_equip_class_kit(c, class_key)
	c.stats.max_hp = cd.starting_hp(c.stats.ability_modifier(_SRD.Ability.CONSTITUTION))
	c.stats.reset()
	c.setup()
	return c

## SRD-style starting equipment per class.
static func _equip_class_kit(c, class_key: String) -> void:
	match class_key:
		"soldier":
			c.equipment.equip_main_hand(_WeaponData.make_longsword())
			c.equipment.equip_armor(_ArmorData.make_chain_mail())
		"ghost":
			c.equipment.equip_main_hand(_WeaponData.make_rapier())
			c.equipment.equip_armor(_ArmorData.make_leather())

## Serialize a character to a JSON-safe dict. Only creation choices and
## mutable state are stored; everything derived is rebuilt on load.
static func to_save_dict(c) -> Dictionary:
	var scores: Array[int] = []
	for i in 6:
		scores.append(c.stats.get_ability(i as _SRD.Ability))
	return {
		"name": c.display_name,
		"class_key": c.class_data.class_name_str.to_lower(),
		"scores": scores,
		"skill_mask": c.stats.skill_proficiency_mask,
		"current_hp": c.stats.current_hp,
		"xp": c.stats.xp,
	}

## Rebuild a character from a to_save_dict() dict (JSON round-trip safe).
static func make_from_save(d: Dictionary):
	var scores: Array[int] = []
	for v in d.get("scores", [10, 10, 10, 10, 10, 10]):
		scores.append(int(v))
	var c = make_custom(str(d.get("name", "Sarro")), str(d.get("class_key", "soldier")), scores, [])
	c.stats.skill_proficiency_mask = int(d.get("skill_mask", 0))
	c.stats.xp = int(d.get("xp", 0))
	var target: int = _Experience.level_for_xp(c.stats.xp)
	while c.stats.level < target and c.stats.level < 20:
		_LevelUp.level_up(c.stats, c.class_data, c.energy_slots)
	c.stats.current_hp = clampi(int(d.get("current_hp", c.stats.max_hp)), 0, c.stats.max_hp)
	return c

## Default Sarro — Soldier with the standard array on a STR build.
static func make_sarro():
	return make_custom("Sarro", "soldier",
		[16, 14, 14, 10, 12, 10],
		[int(_SRD.Skill.ATHLETICS), int(_SRD.Skill.PERCEPTION)])

## Liris fights as a Soldier kit until Warden spellcasting exists in-game.
static func make_liris():
	return make_custom("Liris", "soldier",
		[10, 14, 12, 14, 16, 12],
		[int(_SRD.Skill.INSIGHT), int(_SRD.Skill.PERCEPTION)])

static func make_enemy_char():
	var c = _WC.new()
	c.display_name = "Bandit"
	c.stats.character_name = "Bandit"
	c.stats.level = 1; c.stats.max_hp = 11
	c.equipment.equip_armor(_ArmorData.make_studded_leather())
	c.stats.strength = 12; c.stats.dexterity = 10; c.stats.constitution = 10
	c.stats.reset()
	c.equipment.equip_main_hand(_WeaponData.make_dagger())
	c.setup()
	return c
