## Base character resource for Wayfarer. Wraps SRD CharacterStats and links
## in class data so the rest of the game can work at a higher level.
class_name WayfarerCharacter
extends Resource

const _CharacterStats = preload("res://addons/srd/resources/character_stats.gd")
const _EquipmentSlots = preload("res://addons/srd/systems/equipment.gd")
const _Combatant      = preload("res://addons/srd/systems/combatant.gd")
const _Dice           = preload("res://addons/srd/dice.gd")
const _SRD            = preload("res://addons/srd/srd_enums.gd")

@export var display_name: String = ""
@export var portrait: Texture2D

@export var stats = null       # CharacterStats
@export var class_data = null  # ClassData
@export var equipment = null   # EquipmentSlots

var energy_slots = null

func _init() -> void:
	stats    = _CharacterStats.new()
	equipment = _EquipmentSlots.new()

## Call after setting class_data and stats.level to finish setup.
func setup() -> void:
	if class_data != null and class_data.has_method("make_slots"):
		energy_slots = class_data.make_slots(stats.level)

## Build the Combatant the SRD battle system uses this turn.
func make_combatant():
	return _Combatant.new(stats, _equipped_weapon(), equipment)

func roll_initiative() -> int:
	return _Dice.roll_d20() + stats.ability_modifier(_SRD.Ability.DEXTERITY)

func _equipped_weapon():
	return equipment.main_hand if equipment != null else null
