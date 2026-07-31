## Ronin — Tamori antagonist. Skilled melee Soldier, honour-bound but ruthless.
class_name FixtureRonin
extends RefCounted

static func make(level: int = 1) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Ronin"
	s.level = level; s.hit_die = 10
	s.strength = 14; s.dexterity = 12; s.constitution = 12
	s.intelligence = 10; s.wisdom = 10; s.charisma = 8
	s.max_hp = 10 + (level - 1) * 6 + (level * 1)  # d10 + CON+1 per level
	s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.STRENGTH, true)
	s.set_save_proficiency(SRD.Ability.CONSTITUTION, true)

	var longsword := WeaponData.new()
	longsword.weapon_name = "Katana"
	longsword.weapon_type = SRD.WeaponType.MARTIAL
	longsword.damage_type = SRD.DamageType.SLASHING
	longsword.die_count = 1; longsword.die_sides = 8
	longsword.properties = SRD.WeaponProperty.VERSATILE
	longsword.versatile_die_count = 1; longsword.versatile_die_sides = 10

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_chain_mail())  # AC 16

	return Combatant.new(s, longsword, eq)
