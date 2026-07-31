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

static func make_sarro():
	var c = _WC.new()
	c.display_name = "Sarro"
	c.stats.character_name = "Sarro"
	c.stats.level = 1; c.stats.hit_die = 10
	c.stats.strength = 16; c.stats.dexterity = 14; c.stats.constitution = 14
	c.stats.intelligence = 10; c.stats.wisdom = 12; c.stats.charisma = 10
	c.stats.max_hp = 12; c.stats.speed = 30; c.stats.reset()
	c.stats.set_save_proficiency(_SRD.Ability.STRENGTH, true)
	c.stats.set_save_proficiency(_SRD.Ability.CONSTITUTION, true)
	c.class_data = _ClassData.make_soldier()
	var longsword = _WeaponData.new()
	longsword.weapon_name = "Longsword"
	longsword.weapon_type = _SRD.WeaponType.MARTIAL
	longsword.damage_type = _SRD.DamageType.SLASHING
	longsword.die_count = 1; longsword.die_sides = 8
	longsword.properties = _SRD.WeaponProperty.VERSATILE
	longsword.versatile_die_count = 1; longsword.versatile_die_sides = 10
	c.equipment.equip_main_hand(longsword)
	c.equipment.equip_armor(_ArmorData.make_chain_mail())
	c.setup()
	return c

static func make_liris():
	var c = _WC.new()
	c.display_name = "Liris"
	c.stats.character_name = "Liris"
	c.stats.level = 1; c.stats.hit_die = 8
	c.stats.strength = 10; c.stats.dexterity = 14; c.stats.constitution = 12
	c.stats.intelligence = 14; c.stats.wisdom = 16; c.stats.charisma = 12
	c.stats.max_hp = 9; c.stats.speed = 30; c.stats.reset()
	c.stats.set_save_proficiency(_SRD.Ability.WISDOM, true)
	c.stats.set_save_proficiency(_SRD.Ability.CHARISMA, true)
	c.class_data = _ClassData.make_warden()
	var mace = _WeaponData.new()
	mace.weapon_name = "Mace"
	mace.weapon_type = _SRD.WeaponType.SIMPLE
	mace.damage_type = _SRD.DamageType.BLUDGEONING
	mace.die_count = 1; mace.die_sides = 6
	c.equipment.equip_main_hand(mace)
	c.equipment.equip_armor(_ArmorData.make_scale_mail())
	c.equipment.equip_shield(_ArmorData.make_shield())
	c.setup()
	return c

static func make_enemy_char():
	var c = _WC.new()
	c.display_name = "Bandit"
	c.stats.character_name = "Bandit"
	c.stats.level = 1; c.stats.max_hp = 11
	c.equipment.equip_armor(_ArmorData.make_studded_leather())
	c.stats.strength = 12; c.stats.dexterity = 10; c.stats.constitution = 10
	c.stats.reset()
	var dagger = _WeaponData.new()
	dagger.weapon_name = "Dagger"
	dagger.weapon_type = _SRD.WeaponType.SIMPLE
	dagger.damage_type = _SRD.DamageType.PIERCING
	dagger.die_count = 1; dagger.die_sides = 4
	c.equipment.equip_main_hand(dagger)
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
