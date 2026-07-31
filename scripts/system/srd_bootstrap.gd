## Loaded as an autoload to pre-register all SRD class_names before game
## scripts are compiled. Godot 4.7 non-editor mode does not pre-scan plugins,
## so bare class_name references in @export defaults fail unless this runs first.
extends Node

const _SRD              = preload("res://vendor/godot-srd-addon/addons/srd/srd_enums.gd")
const _CharacterStats   = preload("res://vendor/godot-srd-addon/addons/srd/resources/character_stats.gd")
const _WeaponData       = preload("res://vendor/godot-srd-addon/addons/srd/resources/weapon_data.gd")
const _ArmorData        = preload("res://vendor/godot-srd-addon/addons/srd/resources/armor_data.gd")
const _EquipmentSlots   = preload("res://vendor/godot-srd-addon/addons/srd/systems/equipment.gd")
const _EnergySlots      = preload("res://vendor/godot-srd-addon/addons/srd/resources/energy_slots.gd")
const _ClassData        = preload("res://vendor/godot-srd-addon/addons/srd/resources/class_data.gd")
const _Dice             = preload("res://vendor/godot-srd-addon/addons/srd/dice.gd")
const _ActionEconomy    = preload("res://vendor/godot-srd-addon/addons/srd/systems/action_economy.gd")
const _ConditionTracker = preload("res://vendor/godot-srd-addon/addons/srd/systems/condition_tracker.gd")
const _DeathSaves       = preload("res://vendor/godot-srd-addon/addons/srd/systems/death_saves.gd")
const _DamageResolver   = preload("res://vendor/godot-srd-addon/addons/srd/systems/damage_resolver.gd")
const _Combatant        = preload("res://vendor/godot-srd-addon/addons/srd/systems/combatant.gd")
const _SRDRules         = preload("res://vendor/godot-srd-addon/addons/srd/rules_engine.gd")
