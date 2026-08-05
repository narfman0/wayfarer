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

var species = null       # SpeciesData or null
var background = null    # BackgroundData or null
var known_spells: Array = []   # Array of SpellData (level 1+)
var cantrips: Array = []       # Array of SpellData (level 0)

## Ability state (session-scoped; refreshed at rest points).
# ── Build choices (CharacterProgression) ──────────────────────────────────────
## Persisted source of truth: ordered choice records (JSON-safe dicts).
var level_choices: Array = []
# Mirrors, derived from level_choices by CharacterProgression._apply_effect:
var fighting_style: String = ""
var subclass_key: String = ""
var feat_keys: Array = []
## Ability scores as chosen at creation — saved instead of live scores so
## ASI/feat mutations replay cleanly on load instead of double-applying.
var base_scores: Array = []
# Session state:
var lucky_points: int = 0          # Lucky feat rerolls; refilled at rest
var riposte_until_ms: int = 0      # Freeblade: advantage window after enemy miss

var second_wind_used: bool = false

## Sarro: Shield Bash cooldown (seconds remaining; ticked by the level).
var shield_bash_cd: float = 0.0

## Sarro: Action Surge (level 2) — once per rest; Freeblades instead run it
## on a short cooldown (Surge Mastery).
var action_surge_used: bool = false
var action_surge_cd: float = 0.0
## Liris: Healing Word — short-rest resource (1 charge, recovers at rest).
var healing_word_charges: int = 1
## Liris: Guiding Bolt — long-rest recharge; marks target for advantage.
var guiding_bolt_ready: bool = true
## Liris: Channel Divinity — short-rest recharge; Sacred Flame burst.
var channel_divinity_ready: bool = true

func _init() -> void:
	stats    = _CharacterStats.new()
	equipment = _EquipmentSlots.new()

## Call after setting class_data and stats.level to finish setup.
func setup() -> void:
	if class_data != null and class_data.has_method("make_slots"):
		energy_slots = class_data.make_slots(stats.level)

## Build the Combatant the SRD battle system uses this turn.
const _Progression = preload("res://scripts/characters/character_progression.gd")

## The single attack-resolution choke point: every combat roll flows through
## a Combatant built here, so stamping the build bonuses covers offense,
## AC, crit range, and the creation wizard's stat preview alike.
func make_combatant():
	var cb = _Combatant.new(stats, _equipped_weapon(), equipment)
	if class_data != null:
		var b: Dictionary = _Progression.combat_bonuses(self)
		cb.bonus_attack = b["attack"]
		cb.bonus_damage = b["damage"]
		cb.bonus_ac = b["ac"]
		cb.crit_threshold = b["crit"]
	return cb

func roll_initiative() -> int:
	return _Dice.roll_d20() + stats.ability_modifier(_SRD.Ability.DEXTERITY)

func _equipped_weapon():
	return equipment.main_hand if equipment != null else null
