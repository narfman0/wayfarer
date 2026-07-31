## Extractor — Psion antagonist. Drains Veil energy for power; ranged arcane attacker.
class_name FixtureExtractor
extends RefCounted

static func make(level: int = 1) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Extractor"
	s.level = level; s.hit_die = 6
	s.strength = 8; s.dexterity = 14; s.constitution = 12
	s.intelligence = 16; s.wisdom = 12; s.charisma = 10
	s.max_hp = 6 + (level - 1) * 4 + (level * 1)
	s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.INTELLIGENCE, true)
	s.set_save_proficiency(SRD.Ability.WISDOM, true)

	# Psionic focus / wand — ranged attack
	var focus := WeaponData.new()
	focus.weapon_name = "Psionic Bolt"
	focus.weapon_type = SRD.WeaponType.SIMPLE
	focus.damage_type = SRD.DamageType.PSYCHIC
	focus.die_count = 1; focus.die_sides = 10
	focus.range_normal = 60; focus.range_long = 120
	focus.properties = SRD.WeaponProperty.AMMUNITION

	# No armor (unarmored: 10 + DEX = 12)
	var eq := EquipmentSlots.new()

	return Combatant.new(s, focus, eq)
