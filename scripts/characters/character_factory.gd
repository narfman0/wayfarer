## Factory for creating pre-configured WayfarerCharacter instances.
## Kept separate from wayfarer_character.gd to avoid circular class_name
## self-reference in static methods (Godot 4.7 runtime parse limitation).
extends RefCounted

const _WC         = preload("res://scripts/characters/wayfarer_character.gd")
const _FeatData   = preload("res://scripts/characters/feat_data.gd")
const _ClassData  = preload("res://addons/srd/resources/class_data.gd")
const _WeaponData = preload("res://addons/srd/resources/weapon_data.gd")
const _ArmorData  = preload("res://addons/srd/resources/armor_data.gd")
const _SRD        = preload("res://addons/srd/srd_enums.gd")
const _LevelUp    = preload("res://addons/srd/systems/level_up.gd")

const CLASS_KEYS := ["soldier", "ghost", "psion", "warden"]

static func make_class_data(class_key: String):
	match class_key:
		"soldier": return _ClassData.make_soldier()
		"ghost":   return _ClassData.make_ghost()
		"psion":   return _ClassData.make_psion()
		"warden":  return _ClassData.make_warden()
	return null

## Build a level-1 character from SRD creation choices.
## scores: 6-element Array[int] indexed by SRD.Ability.
## skill_picks: Array of SRD.Skill ints (validated against class skill_options).
static func make_custom(display_name: String, class_key: String,
		scores: Array, skill_picks: Array, feat_key: String = ""):
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
	var feat = make_feat(_FeatData, feat_key)
	if feat != null:
		c.feats.append(feat)
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
		"psion":
			c.equipment.equip_main_hand(_WeaponData.make_quarterstaff())
		"warden":
			c.equipment.equip_main_hand(_WeaponData.make_mace())
			c.equipment.equip_armor(_ArmorData.make_scale_mail())
			c.equipment.equip_shield(_ArmorData.make_shield())

## Default Sarro — Soldier with the standard array on a STR build.
static func make_sarro():
	return make_custom("Sarro", "soldier",
		[16, 14, 14, 10, 12, 10],
		[int(_SRD.Skill.ATHLETICS), int(_SRD.Skill.PERCEPTION)])

static func make_liris():
	return make_custom("Liris", "warden",
		[10, 14, 12, 14, 16, 12],
		[int(_SRD.Skill.INSIGHT), int(_SRD.Skill.MEDICINE)])

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

static func make_feat(feat_data_script, key: String):
	var f = feat_data_script.new()
	match key:
		"gwm":        f.feat_name = "Great Weapon Master"
		"alert":      f.feat_name = "Alert";      f.initiative_mod = 5
		"sentinel":   f.feat_name = "Sentinel"
		"mobile":     f.feat_name = "Mobile";     f.speed_mod = 10
		"war_caster": f.feat_name = "War Caster"
		"lucky":      f.feat_name = "Lucky"
		_:            return null
	return f
