## Bandit — low-level Ghost skirmisher. Fast, opportunistic, fragile.
class_name FixtureBandit
extends RefCounted

static func make(level: int = 1) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Bandit"
	s.level = level; s.hit_die = 8
	s.strength = 10; s.dexterity = 15; s.constitution = 12
	s.intelligence = 10; s.wisdom = 10; s.charisma = 8
	s.max_hp = 8 + (level - 1) * 5 + (level * 1)
	s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.DEXTERITY, true)
	s.set_save_proficiency(SRD.Ability.INTELLIGENCE, true)

	var shortsword := WeaponData.new()
	shortsword.weapon_name = "Shortsword"
	shortsword.weapon_type = SRD.WeaponType.MARTIAL
	shortsword.damage_type = SRD.DamageType.PIERCING
	shortsword.die_count = 1; shortsword.die_sides = 6
	shortsword.properties = SRD.WeaponProperty.FINESSE | SRD.WeaponProperty.LIGHT

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_leather())  # 11 + DEX(+2) = 13

	return Combatant.new(s, shortsword, eq)
