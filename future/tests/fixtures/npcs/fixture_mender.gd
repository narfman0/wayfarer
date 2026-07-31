## Mender — well-meaning antagonist. Warden who genuinely believes they're fixing the Veil.
## Tougher than a ronin — divine conviction makes them resilient.
class_name FixtureMender
extends RefCounted

static func make(level: int = 1) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Mender"
	s.level = level; s.hit_die = 8
	s.strength = 12; s.dexterity = 10; s.constitution = 14
	s.intelligence = 12; s.wisdom = 16; s.charisma = 12
	s.max_hp = 8 + (level - 1) * 5 + (level * 2)
	s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.WISDOM, true)
	s.set_save_proficiency(SRD.Ability.CHARISMA, true)

	var mace := WeaponData.new()
	mace.weapon_name = "Mace"
	mace.weapon_type = SRD.WeaponType.SIMPLE
	mace.damage_type = SRD.DamageType.BLUDGEONING
	mace.die_count = 1; mace.die_sides = 6

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_scale_mail())   # 14 + DEX(0) = 14
	eq.equip_shield(ArmorData.make_shield())      # +2 → 16

	return Combatant.new(s, mace, eq)

## Boss variant: higher level, more HP, boosted WIS
static func make_boss(level: int = 4) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Mender (Archon)"
	s.level = level; s.hit_die = 8
	s.strength = 12; s.dexterity = 10; s.constitution = 16
	s.intelligence = 14; s.wisdom = 18; s.charisma = 14
	s.max_hp = 8 + (level - 1) * 6 + (level * 3)
	s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.WISDOM, true)
	s.set_save_proficiency(SRD.Ability.CHARISMA, true)
	s.set_save_proficiency(SRD.Ability.CONSTITUTION, true)

	var mace := WeaponData.new()
	mace.weapon_name = "Sacred Mace"
	mace.weapon_type = SRD.WeaponType.MARTIAL
	mace.damage_type = SRD.DamageType.RADIANT
	mace.die_count = 1; mace.die_sides = 8

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_chain_mail())
	eq.equip_shield(ArmorData.make_shield())      # AC 18

	return Combatant.new(s, mace, eq)
