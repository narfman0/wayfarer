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

## Enemy roster. Draft stats + XP values live in docs/design/progression.md.
static func make_enemy(enemy_type: String = "bandit"):
	var c = _WC.new()
	match enemy_type:
		"brute":
			c.display_name = "Bandit Brute"
			c.stats.level = 3; c.stats.max_hp = 26
			c.stats.strength = 16; c.stats.dexterity = 8; c.stats.constitution = 14
			c.equipment.equip_armor(_ArmorData.make_studded_leather())
			c.equipment.equip_main_hand(_WeaponData.make_greatsword())
		"anchor_warden":
			c.display_name = "Idris, the Mender Anchor"
			c.stats.level = 5; c.stats.max_hp = 65
			c.stats.strength = 18; c.stats.dexterity = 10; c.stats.constitution = 16
			c.equipment.equip_armor(_ArmorData.make_chain_mail())
			c.equipment.equip_main_hand(_WeaponData.make_greatsword())
		"veil_rig":
			c.display_name = "Crystallization Rig"
			c.stats.level = 5; c.stats.max_hp = 110
			c.stats.strength = 1; c.stats.dexterity = 1; c.stats.constitution = 20
			c.equipment.equip_armor(_ArmorData.make_chain_mail())  # AC stand-in: crystal lattice
		"rig_pillar":
			c.display_name = "Extraction Pillar"
			c.stats.level = 6; c.stats.max_hp = 40
			c.stats.strength = 1; c.stats.dexterity = 1; c.stats.constitution = 14
			c.equipment.equip_armor(_ArmorData.make_scale_mail())
		"extractor_engine":
			c.display_name = "The Extractor Engine"
			c.stats.level = 7; c.stats.max_hp = 170
			c.stats.strength = 20; c.stats.dexterity = 6; c.stats.constitution = 20
			c.equipment.equip_armor(_ArmorData.make_chain_mail())
			c.equipment.equip_main_hand(_WeaponData.make_greatsword())
		# --- Act 2a: The Reach ---
		"extractor_guard":
			c.display_name = "Extractor Guard"
			c.stats.level = 6; c.stats.max_hp = 45
			c.stats.strength = 14; c.stats.dexterity = 14; c.stats.constitution = 14
			c.equipment.equip_armor(_ArmorData.make_scale_mail())
			c.equipment.equip_main_hand(_WeaponData.make_shortsword())
		"extractor_enforcer":
			c.display_name = "Extractor Enforcer"
			c.stats.level = 7; c.stats.max_hp = 60
			c.stats.strength = 18; c.stats.dexterity = 10; c.stats.constitution = 16
			c.equipment.equip_armor(_ArmorData.make_chain_mail())
			c.equipment.equip_main_hand(_WeaponData.make_greatsword())
		# --- Act 2b: Old Kaveth ---
		"stitched_husk":
			c.display_name = "Stitched Husk"
			c.stats.level = 9; c.stats.max_hp = 75
			c.stats.strength = 16; c.stats.dexterity = 12; c.stats.constitution = 16
			c.equipment.equip_armor(_ArmorData.make_scale_mail())
			c.equipment.equip_main_hand(_WeaponData.make_mace())
		"kaveth_shade":
			c.display_name = "Kaveth Shade"
			c.stats.level = 10; c.stats.max_hp = 90
			c.stats.strength = 18; c.stats.dexterity = 14; c.stats.constitution = 16
			c.equipment.equip_armor(_ArmorData.make_studded_leather())
			c.equipment.equip_main_hand(_WeaponData.make_greatsword())
		# --- Act 2c: Verath ---
		"dock_blade":
			c.display_name = "Dockside Blade"
			c.stats.level = 12; c.stats.max_hp = 100
			c.stats.strength = 12; c.stats.dexterity = 18; c.stats.constitution = 14
			c.equipment.equip_armor(_ArmorData.make_studded_leather())
			c.equipment.equip_main_hand(_WeaponData.make_rapier())
		# --- Act 2d: The Between ---
		"veil_fragment":
			c.display_name = "Veil Fragment"
			c.stats.level = 14; c.stats.max_hp = 120
			c.stats.strength = 18; c.stats.dexterity = 16; c.stats.constitution = 18
			c.equipment.equip_armor(_ArmorData.make_scale_mail())
			c.equipment.equip_main_hand(_WeaponData.make_mace())
		# --- Act 3b: The Convergence ---
		"mender_zealot":
			c.display_name = "Mender Zealot"
			c.stats.level = 17; c.stats.max_hp = 140
			c.stats.strength = 16; c.stats.dexterity = 14; c.stats.constitution = 16
			c.equipment.equip_armor(_ArmorData.make_chain_mail())
			c.equipment.equip_main_hand(_WeaponData.make_longsword())
		"cael":
			c.display_name = "Cael"
			c.stats.level = 20; c.stats.max_hp = 250
			c.stats.strength = 20; c.stats.dexterity = 14; c.stats.constitution = 20
			c.equipment.equip_armor(_ArmorData.make_chain_mail())
			c.equipment.equip_main_hand(_WeaponData.make_greatsword())
		_:  # "bandit"
			c.display_name = "Bandit"
			c.stats.level = 1; c.stats.max_hp = 11
			c.stats.strength = 12; c.stats.dexterity = 10; c.stats.constitution = 10
			c.equipment.equip_armor(_ArmorData.make_studded_leather())
			c.equipment.equip_main_hand(_WeaponData.make_dagger())
	c.stats.character_name = c.display_name
	c.stats.reset()
	c.setup()
	return c

static func make_enemy_char():
	return make_enemy("bandit")
