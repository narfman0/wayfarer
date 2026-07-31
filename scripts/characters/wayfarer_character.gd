## Base character resource for Wayfarer. Wraps SRD CharacterStats and links
## in feat/class data so the rest of the game can work at a higher level.
class_name WayfarerCharacter
extends Resource

@export var display_name: String = ""
@export var portrait: Texture2D

## Core SRD data — drive all rules through these
@export var stats: CharacterStats
@export var class_data: ClassData
@export var equipment: EquipmentSlots
@export var feats: Array[FeatData] = []

## Optional — only companions with class features need this
var feature_tracker: ClassFeatureTracker = null
var energy_slots: EnergySlots = null
var lucky_tracker: FeatsSystem.LuckyTracker = null

func _init() -> void:
	stats = CharacterStats.new()
	equipment = EquipmentSlots.new()

## Call after setting class_data and stats.level to finish setup.
func setup() -> void:
	if class_data != null:
		feature_tracker = ClassFeatureTracker.new(class_data)
		energy_slots = class_data.make_slots(stats.level)
	for feat: FeatData in feats:
		FeatsSystem.apply_stat_mods(stats, feat)
	if FeatsSystem.has_feat(feats, "Lucky"):
		lucky_tracker = FeatsSystem.LuckyTracker.new()

## Build the Combatant the SRD battle system uses this turn.
func make_combatant(weapon: WeaponData = null) -> Combatant:
	var c := Combatant.new(stats, weapon if weapon != null else _equipped_weapon(), equipment)
	return c

## Passive Perception — used for hidden enemies, traps, Veil anomalies.
func passive_perception() -> int:
	return SRDRules.passive_check(stats, SRD.Skill.PERCEPTION)

## Total initiative roll with feat bonuses (Alert: +5).
func roll_initiative() -> int:
	var d20 := Dice.roll_d20()
	var mod := stats.ability_modifier(SRD.Ability.DEXTERITY)
	return d20 + mod + FeatsSystem.initiative_bonus(feats)

func _equipped_weapon() -> WeaponData:
	return equipment.main_hand if equipment != null else null


## ── Built-in companion factories ──────────────────────────────────────────────

static func make_sarro() -> WayfarerCharacter:
	var c := WayfarerCharacter.new()
	c.display_name = "Sarro"
	c.stats.character_name = "Sarro"
	c.stats.level = 1; c.stats.hit_die = 10
	c.stats.strength = 16; c.stats.dexterity = 14; c.stats.constitution = 14
	c.stats.intelligence = 10; c.stats.wisdom = 12; c.stats.charisma = 10
	c.stats.max_hp = 12; c.stats.speed = 30; c.stats.reset()
	c.class_data = ClassData.make_soldier()
	c.setup()
	return c

static func make_liris() -> WayfarerCharacter:
	var c := WayfarerCharacter.new()
	c.display_name = "Liris"
	c.stats.character_name = "Liris"
	c.stats.level = 1; c.stats.hit_die = 8
	c.stats.strength = 10; c.stats.dexterity = 14; c.stats.constitution = 12
	c.stats.intelligence = 14; c.stats.wisdom = 16; c.stats.charisma = 12
	c.stats.max_hp = 9; c.stats.speed = 30; c.stats.reset()
	c.class_data = ClassData.make_warden()
	c.setup()
	return c
