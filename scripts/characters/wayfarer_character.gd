## Base character resource for Wayfarer. Wraps SRD CharacterStats and links
## in feat/class data so the rest of the game can work at a higher level.
class_name WayfarerCharacter
extends Resource

const _CharacterStats = preload("res://vendor/godot-srd-addon/addons/srd/resources/character_stats.gd")
const _EquipmentSlots = preload("res://vendor/godot-srd-addon/addons/srd/systems/equipment.gd")
const _Combatant      = preload("res://vendor/godot-srd-addon/addons/srd/systems/combatant.gd")
const _Dice           = preload("res://vendor/godot-srd-addon/addons/srd/dice.gd")
const _SRD            = preload("res://vendor/godot-srd-addon/addons/srd/srd_enums.gd")
const _FeatsSystem    = preload("res://scripts/characters/feats_system.gd")

@export var display_name: String = ""
@export var portrait: Texture2D

@export var stats = null       # CharacterStats
@export var class_data = null  # ClassData
@export var equipment = null   # EquipmentSlots
@export var feats: Array = []  # Array of FeatData

var feature_tracker = null
var energy_slots = null
var lucky_tracker = null

func _init() -> void:
	stats    = _CharacterStats.new()
	equipment = _EquipmentSlots.new()

## Call after setting class_data and stats.level to finish setup.
func setup() -> void:
	if class_data != null:
		if class_data.has_method("make_slots"):
			energy_slots = class_data.make_slots(stats.level)
	for feat in feats:
		_FeatsSystem.apply_stat_mods(stats, feat)
	if _FeatsSystem.has_feat(feats, "Lucky"):
		lucky_tracker = _FeatsSystem.LuckyTracker.new()

## Build the Combatant the SRD battle system uses this turn.
func make_combatant():
	return _Combatant.new(stats, _equipped_weapon(), equipment)

## Total initiative roll with feat bonuses (Alert: +5).
func roll_initiative() -> int:
	var d20: int = _Dice.roll_d20()
	var mod: int = stats.ability_modifier(_SRD.Ability.DEXTERITY)
	return d20 + mod + _FeatsSystem.initiative_bonus(feats)

func _equipped_weapon():
	return equipment.main_hand if equipment != null else null
