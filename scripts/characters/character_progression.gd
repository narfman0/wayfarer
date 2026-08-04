## Build choices: fighting styles, feats, ASI, subclasses — the registries,
## the pending-choice engine, and the derived combat bonuses.
##
## Design (docs/design/setting-classes.md, gameplay.md):
## - Creation: fighting style + one starting feat.
## - Level 3: subclass (three per class).
## - Class ASI levels (ASISystem tables): +2 / +1+1 ability increase OR a feat.
## - Choices are SPENT at rest points only; until then they sit pending.
##   `pending_choices` derives the owed list from the character's level and
##   recorded picks — nothing is stored as "pending", so it can never desync,
##   and old saves are automatically owed everything at their next rest.
##
## `level_choices` on the character is the persisted source of truth (JSON-
## safe dicts); mirrors (fighting_style / subclass_key / feat_keys) and all
## stat effects are (re)derived by _apply_effect. Max HP is always recomputed
## from scratch (recompute_max_hp) so CON changes and Tough are retroactive
## and idempotent across save/load replays.
##
## Takes untyped characters (no WayfarerCharacter preload) to avoid the
## circular-preload issue character_factory.gd documents.
class_name CharacterProgression
extends RefCounted

const _SRD         = preload("res://addons/srd/srd_enums.gd")
const _ASISystem   = preload("res://addons/srd/systems/asi_system.gd")
const _FeatData    = preload("res://addons/srd/resources/feat_data.gd")
const _FeatsSystem = preload("res://addons/srd/systems/feats_system.gd")

# ── Registries ────────────────────────────────────────────────────────────────

const FIGHTING_STYLES := {
	"defense": {"name": "Defense", "classes": ["soldier", "ghost"],
		"desc": "+1 AC. The stance that keeps you standing."},
	"dueling": {"name": "Dueling", "classes": ["soldier"],
		"desc": "+2 damage with a one-handed weapon."},
	"great_weapon": {"name": "Great Weapon Fighting", "classes": ["soldier"],
		"desc": "+1 damage with two-handed weapons."},
	"skirmisher": {"name": "Skirmisher", "classes": ["ghost"],
		"desc": "+10% move speed; critical hits on 19–20."},
}

## Curated for effects that matter in this real-time loop. Cut with reasons:
## Alert (no initiative system), War Caster (no player concentration),
## Sharpshooter (no player ranged weapon).
const FEATS := {
	"tough": {"name": "Tough",
		"desc": "+2 max HP per level, retroactive."},
	"resilient": {"name": "Resilient (Constitution)",
		"desc": "+1 Constitution and proficiency in CON saves."},
	"mobile": {"name": "Mobile",
		"desc": "+15% move speed."},
	"lucky": {"name": "Lucky",
		"desc": "Reroll up to 3 missed attacks per rest — the Veil nudges."},
	"sentinel": {"name": "Sentinel",
		"desc": "Your hits stagger enemies for a beat."},
	"gwm": {"name": "Great Weapon Master",
		"desc": "−5 to hit, +10 damage while wielding a two-handed weapon."},
}

const SUBCLASSES := {
	"soldier": {
		"freeblade": {"name": "Freeblade",
			"desc": "Tempo. Action Surge every 8 s of downtime instead of once per rest, and enemies that miss you open themselves — your next attack within 3 s has advantage."},
		"gatewatch": {"name": "Gatewatch",
			"desc": "Protection. Springing ambushers are staggered 1.5 s, and Liris takes 25% less damage while near you."},
		"anchor": {"name": "Anchor",
			"desc": "Stillness. All incoming damage reduced by 1 (min 1), and the party takes 2 less from Veil zones and telegraphed blasts."},
	},
	"ghost": {
		"threshold_thief": {"name": "Threshold Thief",
			"desc": "Micro-tears. +1d6 damage against staggered or casting targets, and your attack rhythm is 10% faster."},
		"faceless": {"name": "Faceless",
			"desc": "Identity work. Expertise (double proficiency) in Deception and Persuasion; certain people will recognize the trade."},
		"between_scout": {"name": "Between-Scout",
			"desc": "You hear the Veil. Telegraphed attacks aimed at you show 25% longer, and critical hits against you deal half damage."},
	},
}

## Liris's growth is the conviction arc, not a build (setting-classes.md §3):
## announced, never chosen. Flavor only — her kit unlocks are story-driven.
const LIRIS_UNLOCKS := {
	2: "Liris walks a little straighter. The current is listening.",
	5: "Liris: \"I can feel where the tears want to close now.\"",
	9: "Liris reads the Veil like weather — she calls the bleedthroughs before you see them.",
	13: "Liris no longer flinches at crossings. The current parts for her.",
	17: "Liris carries the calm of a stable tear with her. The Order would call her Warden.",
}

# ── Queries ───────────────────────────────────────────────────────────────────

static func class_key(c) -> String:
	return c.class_data.class_name_str.to_lower()

## Only Sarro spends choices; Liris (and every enemy) is story/data-driven.
static func is_choice_driven(c) -> bool:
	return c != null and c == GameState.sarro

static func styles_for(key: String) -> Array:
	var out := []
	for k in FIGHTING_STYLES:
		if key in FIGHTING_STYLES[k]["classes"]:
			out.append(k)
	return out

static func has_feat(c, key: String) -> bool:
	return key in c.feat_keys

## Everything this character is owed, oldest first. Derived, never stored.
static func pending_choices(c) -> Array:
	var out := []
	if c == null or c.class_data == null:
		return out
	if c.fighting_style == "":
		out.append({"kind": "style"})
	if not _has_slot_choice(c, 1):
		out.append({"kind": "feat", "level": 1})
	if c.stats.level >= 3 and c.subclass_key == "":
		out.append({"kind": "subclass", "level": 3})
	for lvl in range(4, c.stats.level + 1):
		if _ASISystem.is_asi_level(c.class_data, lvl) and not _has_slot_choice(c, lvl):
			out.append({"kind": "asi_or_feat", "level": lvl})
	return out

## A feat/ASI pick recorded for this level?
static func _has_slot_choice(c, lvl: int) -> bool:
	for rec in c.level_choices:
		if int(rec.get("level", -1)) == lvl and str(rec.get("kind")) in ["feat", "asi"]:
			return true
	return false

# ── Applying choices ──────────────────────────────────────────────────────────

## Record + apply one choice. Records are JSON-safe dicts:
##   {"kind":"style", "style":"defense"}
##   {"kind":"feat", "level":4, "feat":"lucky"}
##   {"kind":"asi", "level":4, "mode":"single", "ability":0}
##   {"kind":"asi", "level":8, "mode":"split", "abilities":[0, 2]}
##   {"kind":"subclass", "subclass":"freeblade"}
static func apply_choice(c, rec: Dictionary) -> void:
	_apply_effect(c, rec)
	c.level_choices.append(rec)
	recompute_max_hp(c)

## Rebuild all choice state from a saved record list (load path).
static func replay_choices(c, records: Array) -> void:
	c.level_choices = []
	for rec in records:
		if rec is Dictionary:
			_apply_effect(c, rec)
			c.level_choices.append(rec)
	recompute_max_hp(c)

static func _apply_effect(c, rec: Dictionary) -> void:
	match str(rec.get("kind")):
		"style":
			c.fighting_style = str(rec.get("style"))
		"subclass":
			c.subclass_key = str(rec.get("subclass"))
			if c.subclass_key == "faceless":
				c.stats.skill_expertise_mask |= (1 << int(_SRD.Skill.DECEPTION)) \
					| (1 << int(_SRD.Skill.PERSUASION))
		"feat":
			var key := str(rec.get("feat"))
			c.feat_keys.append(key)
			match key:
				"resilient":
					_FeatsSystem.apply_stat_mods(c.stats,
						_FeatData.make_resilient(_SRD.Ability.CONSTITUTION))
				"lucky":
					c.lucky_points = 3
		"asi":
			if str(rec.get("mode")) == "split":
				var ab: Array = rec.get("abilities", [])
				if ab.size() == 2:
					_ASISystem.apply_split(c.stats,
						int(ab[0]) as _SRD.Ability, int(ab[1]) as _SRD.Ability)
			else:
				_ASISystem.apply_single(c.stats,
					int(rec.get("ability", 0)) as _SRD.Ability)

## Max HP derived from scratch — mirrors SRDLevelUp's average math, plus
## Tough. Retroactive for CON changes and idempotent across replays.
static func recompute_max_hp(c) -> void:
	var con: int = c.stats.ability_modifier(_SRD.Ability.CONSTITUTION)
	var hd: int = c.class_data.hit_die
	var mx: int = maxi(1, hd + con)
	mx += (c.stats.level - 1) * maxi(1, (hd / 2 + 1) + con)
	if has_feat(c, "tough"):
		mx += 2 * c.stats.level
	c.stats.max_hp = mx
	c.stats.current_hp = clampi(c.stats.current_hp, 0, mx)

## Deterministically spend everything pending (debug parties, tests) so
## isolated scene runs never stall on unspent choices.
static func auto_resolve(c) -> void:
	var guard := 0
	while guard < 32:
		guard += 1
		var pend := pending_choices(c)
		if pend.is_empty():
			return
		var p: Dictionary = pend[0]
		match str(p.get("kind")):
			"style":
				apply_choice(c, {"kind": "style", "style": styles_for(class_key(c))[0]})
			"feat":
				apply_choice(c, {"kind": "feat", "level": int(p.get("level", 1)), "feat": "tough"})
			"subclass":
				var first: String = SUBCLASSES[class_key(c)].keys()[0]
				apply_choice(c, {"kind": "subclass", "subclass": first})
			"asi_or_feat":
				apply_choice(c, {"kind": "asi", "level": int(p.get("level")),
					"mode": "single", "ability": int(_SRD.Ability.STRENGTH)})

# ── Derived combat numbers ────────────────────────────────────────────────────

## Flat bonuses stamped onto Combatant by WayfarerCharacter.make_combatant().
static func combat_bonuses(c) -> Dictionary:
	var b := {"attack": 0, "damage": 0, "ac": 0, "crit": 20}
	var w = c.equipment.main_hand
	var two_handed: bool = w != null and w.has_property(_SRD.WeaponProperty.TWO_HANDED)
	match c.fighting_style:
		"defense":
			b["ac"] += 1
		"dueling":
			if w != null and not two_handed:
				b["damage"] += 2
		"great_weapon":
			if two_handed:
				b["damage"] += 1
		"skirmisher":
			b["crit"] = 19
	if has_feat(c, "gwm") and two_handed:
		b["attack"] -= 5
		b["damage"] += 10
	return b

static func speed_multiplier(c) -> float:
	var m := 1.0
	if has_feat(c, "mobile"):
		m *= 1.15
	if c.fighting_style == "skirmisher":
		m *= 1.10
	return m

## Base attack-interval multiplier (Action Surge multiplies on top).
static func base_rate_scale(c) -> float:
	return 0.9 if c.subclass_key == "threshold_thief" else 1.0

## Subclass defenses, applied wherever the party takes damage.
## kind: "melee" (enemy weapon hits) or "zone" (telegraphs, Veil discharges).
## Anchor — Bulwark: Sarro's own incoming −1; Steadying Aura: party −2 from
## zones. Gatewatch — Bodyguard: Liris −25% while near Sarro. Between-Scout —
## Uncanny Dodge: crits against Sarro deal half.
static func modify_party_damage(dmg: int, target_char, kind: String,
		crit := false, liris_near_sarro := false) -> int:
	var s = GameState.sarro
	if s == null or dmg <= 0:
		return dmg
	match s.subclass_key:
		"anchor":
			if kind == "zone":
				dmg = maxi(1, dmg - 2)
			elif target_char == s:
				dmg = maxi(1, dmg - 1)
		"gatewatch":
			if target_char == GameState.liris and liris_near_sarro:
				dmg = maxi(1, int(dmg * 0.75))
		"between_scout":
			if target_char == s and crit:
				dmg = maxi(1, dmg / 2)
	return dmg

## Between-Scout Danger Sense: telegraphs aimed at the party linger longer.
static func telegraph_scale() -> float:
	var s = GameState.sarro
	return 1.25 if s != null and s.subclass_key == "between_scout" else 1.0
