## SRD character creation wizard:
## Sarro: Class → Fighting Style → Abilities → Skills → Feat → Review
## Then: "Customize Liris?" → if yes, same flow for Liris (no Style/Feat steps).
## Both characters can pick from all 4 classes. Defaults apply if skipped.
class_name CharacterCreation
extends Control

const _Factory       = preload("res://scripts/characters/character_factory.gd")
const _SRD           = preload("res://addons/srd/srd_enums.gd")
const _AbilityScores = preload("res://addons/srd/systems/ability_scores.gd")
const _Skills        = preload("res://addons/srd/systems/skills_system.gd")
const _Progression   = preload("res://scripts/characters/character_progression.gd")
const _SpeciesData   = preload("res://addons/srd/resources/species_data.gd")
const _BackgroundData = preload("res://addons/srd/resources/background_data.gd")
const _SpellData     = preload("res://addons/srd/resources/spell_data.gd")

enum Step { CLASS, STYLE, ABILITIES, SKILLS, FEAT, REVIEW, LIRIS_PROMPT, LIRIS_CLASS, LIRIS_ABILITIES, LIRIS_SKILLS,
	SPECIES = 10, BACKGROUND = 11, SPELL_PICK = 12 }
enum Method { POINT_BUY, STANDARD_ARRAY, ROLL }

const STEP_TITLES := {
	Step.SPECIES: "Species",
	Step.CLASS: "Class",
	Step.STYLE: "Fighting Style",
	Step.ABILITIES: "Ability Scores",
	Step.SKILLS: "Skills",
	Step.SPELL_PICK: "Spells",
	Step.BACKGROUND: "Background",
	Step.FEAT: "Feat",
	Step.REVIEW: "Review",
	Step.LIRIS_PROMPT: "Companion",
	Step.LIRIS_CLASS: "Liris — Class",
	Step.LIRIS_ABILITIES: "Liris — Ability Scores",
	Step.LIRIS_SKILLS: "Liris — Skills",
}

@onready var _step_label: Label = $Layout/StepLabel
@onready var _body: VBoxContainer = $Layout/Content/StepBody
@onready var _back_btn: Button = $Layout/Nav/Back
@onready var _next_btn: Button = $Layout/Nav/Next

var _step: Step = Step.SPECIES
var _class_key: String = "soldier"
var _method: Method = Method.POINT_BUY
var _pb_scores: Array[int] = [8, 8, 8, 8, 8, 8]      # point buy, by SRD.Ability
var _assign: Array[int] = [-1, -1, -1, -1, -1, -1]   # ability → pool index
var _pool: Array[int] = []                            # array/roll values
var _skill_picks: Array[int] = []
var _style_key: String = ""
var _feat_key: String = ""
var _char_name: String = "Sarro"
var _species_pick = null      # SpeciesData or null
var _background_pick = null   # BackgroundData or null
var _cantrip_picks: Array = []
var _sarro_spell_picks: Array = []

# Liris customisation state (only used when player opts in)
var _liris_class_key: String = "warden"
var _liris_pb_scores: Array[int] = [8, 8, 8, 8, 8, 8]
var _liris_assign: Array[int] = [-1, -1, -1, -1, -1, -1]
var _liris_pool: Array[int] = []
var _liris_skill_picks: Array[int] = []
var _liris_customize: bool = false  # true once player opts in

func _ready() -> void:
	theme = UITheme.theme
	_back_btn.pressed.connect(_on_back)
	_next_btn.pressed.connect(_on_next)
	_pool = _AbilityScores.STANDARD_ARRAY.duplicate()
	_rebuild()

# ── Navigation ───────────────────────────────────────────────────────────────

func _on_back() -> void:
	match _step:
		Step.SPECIES:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
			return
		Step.CLASS:
			_step = Step.SPECIES
		Step.ABILITIES:
			if _Progression.styles_for(_class_key).is_empty():
				_step = Step.CLASS
			else:
				_step = Step.STYLE
		Step.SPELL_PICK:
			_step = Step.SKILLS
		Step.BACKGROUND:
			if _is_caster(_class_key):
				_step = Step.SPELL_PICK
			else:
				_step = Step.SKILLS
		Step.FEAT:
			_step = Step.BACKGROUND
		Step.LIRIS_PROMPT:
			_step = Step.REVIEW
		Step.LIRIS_CLASS:
			_step = Step.LIRIS_PROMPT
		Step.LIRIS_ABILITIES:
			_step = Step.LIRIS_CLASS
		Step.LIRIS_SKILLS:
			_step = Step.LIRIS_ABILITIES
		_:
			_step = (_step - 1) as Step
	_rebuild()

func _on_next() -> void:
	match _step:
		Step.SPECIES:
			_step = Step.CLASS
			_rebuild()
		Step.CLASS:
			if _Progression.styles_for(_class_key).is_empty():
				_style_key = ""
				_step = Step.ABILITIES
			else:
				_step = Step.STYLE
			_rebuild()
		Step.SKILLS:
			if _is_caster(_class_key):
				_step = Step.SPELL_PICK
			else:
				_step = Step.BACKGROUND
			_rebuild()
		Step.SPELL_PICK:
			_step = Step.BACKGROUND
			_rebuild()
		Step.BACKGROUND:
			_step = Step.FEAT
			_rebuild()
		Step.REVIEW:
			_step = Step.LIRIS_PROMPT
			_rebuild()
		Step.LIRIS_PROMPT:
			if _liris_customize:
				_liris_pool = _AbilityScores.STANDARD_ARRAY.duplicate()
				_step = Step.LIRIS_CLASS
				_rebuild()
			else:
				_confirm()
		Step.LIRIS_SKILLS:
			_confirm()
		_:
			_step = (_step + 1) as Step
			_rebuild()

func _confirm() -> void:
	var sarro = _Factory.make_custom(_char_name, _class_key, _scores(), _skill_picks,
		_species_pick, _background_pick, _cantrip_picks, _sarro_spell_picks)
	_Progression.apply_choice(sarro, {"kind": "style", "style": _style_key})
	_Progression.apply_choice(sarro, {"kind": "feat", "level": 1, "feat": _feat_key})
	var liris
	if _liris_customize:
		liris = _Factory.make_custom("Liris", _liris_class_key, _liris_scores(), _liris_skill_picks)
	else:
		liris = _Factory.make_liris()
	GameState.set_party(sarro, liris)
	get_tree().change_scene_to_file("res://scenes/world/tamori.tscn")

## The six chosen scores indexed by SRD.Ability, per the active method.
func _scores() -> Array:
	if _method == Method.POINT_BUY:
		return _pb_scores.duplicate()
	var out: Array[int] = []
	for i in 6:
		out.append(_pool[_assign[i]] if _assign[i] >= 0 else 8)
	return out

func _liris_scores() -> Array:
	var out: Array[int] = []
	for i in 6:
		out.append(_liris_pool[_liris_assign[i]] if _liris_assign[i] >= 0 else 8)
	return out

func _rebuild() -> void:
	var title: String = STEP_TITLES.get(_step, "...")
	_step_label.text = title
	_back_btn.text = "Main Menu" if _step == Step.SPECIES else "Back"
	match _step:
		Step.LIRIS_PROMPT:
			_next_btn.text = "Use Default Liris" if not _liris_customize else "Customize Liris"
		Step.LIRIS_SKILLS:
			_next_btn.text = "Begin"
		Step.REVIEW:
			_next_btn.text = "Next →"
		_:
			_next_btn.text = "Next"
	for child in _body.get_children():
		child.queue_free()
	match _step:
		Step.SPECIES:        _build_species_step()
		Step.CLASS:          _build_class_step()
		Step.STYLE:          _build_style_step()
		Step.ABILITIES:      _build_abilities_step()
		Step.SKILLS:         _build_skills_step()
		Step.SPELL_PICK:     _build_spell_step()
		Step.BACKGROUND:     _build_background_step()
		Step.FEAT:           _build_feat_step()
		Step.REVIEW:         _build_review_step()
		Step.LIRIS_PROMPT:   _build_liris_prompt_step()
		Step.LIRIS_CLASS:    _build_liris_class_step()
		Step.LIRIS_ABILITIES: _build_liris_abilities_step()
		Step.LIRIS_SKILLS:   _build_liris_skills_step()
	_validate()

func _validate() -> void:
	match _step:
		Step.SPECIES:
			_next_btn.disabled = _species_pick == null
		Step.STYLE:
			_next_btn.disabled = _style_key == ""
		Step.FEAT:
			_next_btn.disabled = _feat_key == ""
		Step.ABILITIES:
			if _method == Method.POINT_BUY:
				_next_btn.disabled = not _AbilityScores.point_buy_valid(_pb_scores)
			else:
				_next_btn.disabled = _assign.count(-1) > 0
		Step.SKILLS:
			var cd = _Factory.make_class_data(_class_key)
			_next_btn.disabled = _skill_picks.size() != cd.skill_choices_count
		Step.SPELL_PICK:
			_next_btn.disabled = false  # spells optional at creation
		Step.BACKGROUND:
			_next_btn.disabled = _background_pick == null
		Step.REVIEW:
			_next_btn.disabled = _char_name.strip_edges().is_empty()
		Step.LIRIS_ABILITIES:
			_next_btn.disabled = _liris_assign.count(-1) > 0
		Step.LIRIS_SKILLS:
			var lcd = _Factory.make_class_data(_liris_class_key)
			_next_btn.disabled = _liris_skill_picks.size() != lcd.skill_choices_count
		_:
			_next_btn.disabled = false

# ── Step 1: Class ────────────────────────────────────────────────────────────

func _build_class_step() -> void:
	_add_header("Choose a class. It sets your hit die, saving throws, proficiencies, and skill list.")
	var group := ButtonGroup.new()
	for key in _Factory.CLASS_KEYS:
		var cd = _Factory.make_class_data(key)
		var btn := CheckBox.new()
		btn.button_group = group
		btn.toggle_mode = true
		btn.text = "%s  (d%d, saves %s/%s)" % [
			cd.class_name_str, cd.hit_die,
			_SRD.ability_abbrev(cd.save_proficiencies[0]),
			_SRD.ability_abbrev(cd.save_proficiencies[1])]
		btn.button_pressed = key == _class_key
		btn.toggled.connect(func(on: bool):
			if on:
				_class_key = key
				_skill_picks.clear()  # class change invalidates skill choices
				if _style_key not in _Progression.styles_for(key):
					_style_key = ""   # and class-specific fighting styles
				_rebuild())
		_body.add_child(btn)
		var desc := Label.new()
		desc.text = "    " + cd.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		_body.add_child(desc)

# ── Step 2: Fighting style ───────────────────────────────────────────────────

func _build_style_step() -> void:
	_add_header("Choose a fighting style — a permanent combat passive.")
	var group := ButtonGroup.new()
	for key in _Progression.styles_for(_class_key):
		var spec: Dictionary = _Progression.FIGHTING_STYLES[key]
		var btn := CheckBox.new()
		btn.button_group = group
		btn.toggle_mode = true
		btn.text = spec["name"]
		btn.button_pressed = key == _style_key
		btn.toggled.connect(func(on: bool):
			if on:
				_style_key = key
				_validate())
		_body.add_child(btn)
		_add_desc(spec["desc"])

# ── Step 5: Feat ─────────────────────────────────────────────────────────────

func _build_feat_step() -> void:
	_add_header("Choose a starting feat. More arrive as you level — spent at stable tears.")
	var group := ButtonGroup.new()
	for key in _Progression.FEATS:
		var spec: Dictionary = _Progression.FEATS[key]
		var btn := CheckBox.new()
		btn.button_group = group
		btn.toggle_mode = true
		btn.text = spec["name"]
		btn.button_pressed = key == _feat_key
		btn.toggled.connect(func(on: bool):
			if on:
				_feat_key = key
				_validate())
		_body.add_child(btn)
		_add_desc(spec["desc"])

# ── Step 3: Ability scores ───────────────────────────────────────────────────

func _build_abilities_step() -> void:
	var cd = _Factory.make_class_data(_class_key)
	var primaries := ", ".join(cd.primary_abilities.map(func(a): return _SRD.ability_abbrev(a)))
	_add_header("Assign ability scores. %s favors %s." % [cd.class_name_str, primaries])

	var method_row := HBoxContainer.new()
	_body.add_child(method_row)
	var method_opt := OptionButton.new()
	method_opt.add_item("Point Buy (27 points)", Method.POINT_BUY)
	method_opt.add_item("Standard Array (15 14 13 12 10 8)", Method.STANDARD_ARRAY)
	method_opt.add_item("Roll 4d6, drop lowest", Method.ROLL)
	method_opt.select(_method)
	method_opt.item_selected.connect(func(idx: int):
		_method = idx as Method
		_assign = [-1, -1, -1, -1, -1, -1]
		_pool = _AbilityScores.roll_array() if _method == Method.ROLL \
			else _AbilityScores.STANDARD_ARRAY.duplicate()
		_rebuild())
	method_row.add_child(method_opt)

	var rec_btn := Button.new()
	rec_btn.text = "Recommended"
	rec_btn.tooltip_text = "Auto-assign for a typical %s build" % cd.class_name_str
	rec_btn.pressed.connect(_apply_recommended)
	method_row.add_child(rec_btn)

	if _method == Method.ROLL:
		var reroll := Button.new()
		reroll.text = "Reroll"
		reroll.pressed.connect(func():
			_pool = _AbilityScores.roll_array()
			_assign = [-1, -1, -1, -1, -1, -1]
			_rebuild())
		method_row.add_child(reroll)

	if _method == Method.POINT_BUY:
		_build_point_buy()
	else:
		_build_pool_assign()

func _build_point_buy() -> void:
	var spent: int = _AbilityScores.point_buy_total(_pb_scores)
	var budget := Label.new()
	budget.text = "Points remaining: %d / %d" % [_AbilityScores.POINT_BUY_BUDGET - spent, _AbilityScores.POINT_BUY_BUDGET]
	_body.add_child(budget)
	for i in 6:
		var row := HBoxContainer.new()
		_body.add_child(row)
		row.add_child(_fixed_label(_SRD.ability_name(i), 130))
		var minus := Button.new()
		minus.text = "-"
		minus.disabled = _pb_scores[i] <= _AbilityScores.POINT_BUY_MIN
		minus.pressed.connect(func(): _pb_adjust(i, -1))
		row.add_child(minus)
		row.add_child(_fixed_label("%2d  (%+d)" % [_pb_scores[i], _mod(_pb_scores[i])], 90))
		var plus := Button.new()
		plus.text = "+"
		var next_cost: int = _AbilityScores.point_buy_cost(_pb_scores[i] + 1)
		plus.disabled = _pb_scores[i] >= _AbilityScores.POINT_BUY_MAX \
			or next_cost < 0 \
			or spent + next_cost - _AbilityScores.point_buy_cost(_pb_scores[i]) > _AbilityScores.POINT_BUY_BUDGET
		plus.pressed.connect(func(): _pb_adjust(i, +1))
		row.add_child(plus)

func _pb_adjust(ability: int, dir: int) -> void:
	_pb_scores[ability] += dir
	_rebuild()

func _build_pool_assign() -> void:
	var note := Label.new()
	note.text = "Pool: " + " ".join(_pool.map(func(v): return str(v)))
	_body.add_child(note)
	for i in 6:
		var row := HBoxContainer.new()
		_body.add_child(row)
		row.add_child(_fixed_label(_SRD.ability_name(i), 130))
		var opt := OptionButton.new()
		opt.add_item("—", -1)
		for p in _pool.size():
			opt.add_item(str(_pool[p]), p)
		opt.select(opt.get_item_index(_assign[i] if _assign[i] >= 0 else -1))
		opt.item_selected.connect(func(idx: int):
			_pool_select(i, opt.get_item_id(idx)))
		row.add_child(opt)
		row.add_child(_fixed_label(
			"(%+d)" % _mod(_pool[_assign[i]]) if _assign[i] >= 0 else "", 60))

## Assign pool slot to ability; if another ability held it, swap.
func _pool_select(ability: int, pool_idx: int) -> void:
	if pool_idx >= 0:
		var holder := _assign.find(pool_idx)
		if holder >= 0 and holder != ability:
			_assign[holder] = _assign[ability]
	_assign[ability] = pool_idx
	_rebuild()

## Auto-assign per class: primaries get the top values, CON is protected next.
func _apply_recommended() -> void:
	var cd = _Factory.make_class_data(_class_key)
	var order: Array[int] = []
	for a in cd.primary_abilities:
		if a not in order:
			order.append(a)
	for a in [int(_SRD.Ability.CONSTITUTION), int(_SRD.Ability.DEXTERITY),
			int(_SRD.Ability.WISDOM), int(_SRD.Ability.STRENGTH),
			int(_SRD.Ability.INTELLIGENCE), int(_SRD.Ability.CHARISMA)]:
		if a not in order:
			order.append(a)
	if _method == Method.POINT_BUY:
		var values := [15, 14, 13, 12, 10, 8]  # a legal 27-point spend
		for rank in 6:
			_pb_scores[order[rank]] = values[rank]
	else:
		var ranked := range(_pool.size())
		ranked.sort_custom(func(a, b): return _pool[a] > _pool[b])
		for rank in 6:
			_assign[order[rank]] = ranked[rank]
	_rebuild()

# ── Step 3: Skills ───────────────────────────────────────────────────────────

func _build_skills_step() -> void:
	var cd = _Factory.make_class_data(_class_key)
	_add_header("Choose %d skill proficiencies (%d selected)." % [cd.skill_choices_count, _skill_picks.size()])
	var scores := _scores()
	for skill in cd.skill_options:
		var ability: int = _Skills.governing_ability(skill)
		var picked: bool = skill in _skill_picks
		var btn := CheckBox.new()
		var bonus: int = _mod(scores[ability]) + (2 if picked else 0)  # prof +2 at level 1
		btn.text = "%s (%s)  %+d" % [_Skills.skill_name(skill), _SRD.ability_abbrev(ability), bonus]
		btn.button_pressed = picked
		btn.disabled = not picked and _skill_picks.size() >= cd.skill_choices_count
		btn.toggled.connect(func(on: bool):
			if on and skill not in _skill_picks:
				_skill_picks.append(skill)
			elif not on:
				_skill_picks.erase(skill)
			_rebuild())
		_body.add_child(btn)

# ── Step 4: Review ───────────────────────────────────────────────────────────

func _build_review_step() -> void:
	var name_row := HBoxContainer.new()
	_body.add_child(name_row)
	name_row.add_child(_fixed_label("Name", 130))
	var name_edit := LineEdit.new()
	name_edit.text = _char_name
	name_edit.custom_minimum_size.x = 240
	name_edit.text_changed.connect(func(t: String):
		_char_name = t
		_validate())
	name_row.add_child(name_edit)

	var preview = _Factory.make_custom(
		_char_name if not _char_name.strip_edges().is_empty() else "Sarro",
		_class_key, _scores(), _skill_picks)
	if _style_key != "":
		_Progression.apply_choice(preview, {"kind": "style", "style": _style_key})
	if _feat_key != "":
		_Progression.apply_choice(preview, {"kind": "feat", "level": 1, "feat": _feat_key})
	var combatant = preview.make_combatant()
	var cd = preview.class_data
	var scores := _scores()

	var lines: Array[String] = []
	lines.append("%s — Level 1 %s" % [preview.display_name, cd.class_name_str])
	if _style_key != "":
		lines.append("Style: %s    Feat: %s" % [
			_Progression.FIGHTING_STYLES[_style_key]["name"],
			_Progression.FEATS[_feat_key]["name"] if _feat_key != "" else "—"])
	var parts: Array[String] = []
	for i in 6:
		parts.append("%s %d (%+d)" % [_SRD.ability_abbrev(i), scores[i], _mod(scores[i])])
	lines.append("  ".join(parts))
	lines.append("HP %d    AC %d    Speed %d ft" % [preview.stats.max_hp, combatant.armor_class, preview.stats.speed])
	lines.append("Saves: %s +%d, %s +%d" % [
		_SRD.ability_abbrev(cd.save_proficiencies[0]),
		preview.stats.saving_throw_bonus(cd.save_proficiencies[0]),
		_SRD.ability_abbrev(cd.save_proficiencies[1]),
		preview.stats.saving_throw_bonus(cd.save_proficiencies[1])])
	var skill_strs: Array[String] = []
	for s in _skill_picks:
		skill_strs.append("%s %+d" % [_Skills.skill_name(s), _Skills.skill_bonus(preview.stats, s)])
	lines.append("Skills: " + (", ".join(skill_strs) if skill_strs.size() > 0 else "none"))
	var weapon = preview.equipment.main_hand
	if weapon != null:
		lines.append("Attack: %s %+d to hit, %dd%d damage" % [
			weapon.weapon_name, combatant.attack_modifier(), weapon.die_count, weapon.die_sides])
	lines.append("")
	lines.append("Liris joins you.")

	var summary := Label.new()
	summary.text = "\n".join(lines)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(summary)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _add_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(lbl)

func _add_desc(text: String) -> void:
	var desc := Label.new()
	desc.text = "    " + text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_body.add_child(desc)

func _fixed_label(text: String, width: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = width
	return lbl

static func _mod(score: int) -> int:
	return (score - 10) / 2 if score >= 10 else (score - 11) / 2

# ── Liris steps ───────────────────────────────────────────────────────────────

func _build_liris_prompt_step() -> void:
	_add_header("Liris is your companion. She has a default Warden build — or you can customise her class and stats.")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_body.add_child(vb)

	var default_info := Label.new()
	default_info.text = "Default Liris: Warden (d8, WIS saves)  —  WIS 16, DEX 14, CON 12"
	default_info.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	default_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(default_info)

	var grp := ButtonGroup.new()
	for label_text: String in ["Use default Liris", "Customise Liris"]:
		var btn := CheckBox.new()
		btn.button_group = grp
		btn.toggle_mode = true
		btn.text = label_text
		btn.button_pressed = (label_text == "Use default Liris") != _liris_customize
		var wants_custom: bool = label_text == "Customise Liris"
		btn.toggled.connect(func(on: bool):
			if on:
				_liris_customize = wants_custom
				_next_btn.text = "Customise Liris" if _liris_customize else "Use Default Liris"
				_validate())
		vb.add_child(btn)

func _build_liris_class_step() -> void:
	_add_header("Choose Liris's class.")
	var group := ButtonGroup.new()
	for key in _Factory.CLASS_KEYS:
		var cd = _Factory.make_class_data(key)
		var btn := CheckBox.new()
		btn.button_group = group
		btn.toggle_mode = true
		btn.text = "%s  (d%d, saves %s/%s)" % [
			cd.class_name_str, cd.hit_die,
			_SRD.ability_abbrev(cd.save_proficiencies[0]),
			_SRD.ability_abbrev(cd.save_proficiencies[1])]
		btn.button_pressed = key == _liris_class_key
		btn.toggled.connect(func(on: bool):
			if on:
				_liris_class_key = key
				_liris_skill_picks.clear())
		_body.add_child(btn)
		_add_desc(cd.description)

func _build_liris_abilities_step() -> void:
	_add_header("Assign the standard array to Liris's ability scores.  [15, 14, 13, 12, 10, 8]")
	_liris_pool = _AbilityScores.STANDARD_ARRAY.duplicate()
	var ability_names := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
	var used: Array[int] = []
	for assigned in _liris_assign:
		if assigned >= 0:
			used.append(assigned)

	for i in 6:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_body.add_child(row)
		row.add_child(_fixed_label(ability_names[i] + ":", 44))
		var opt := OptionButton.new()
		opt.custom_minimum_size.x = 80
		opt.add_item("—", -1)
		for pi in _liris_pool.size():
			var val: int = _liris_pool[pi]
			var taken: bool = pi in used and _liris_assign[i] != pi
			if not taken:
				opt.add_item(str(val) + "  (%+d)" % _mod(val), pi)
		if _liris_assign[i] >= 0:
			for idx in opt.item_count:
				if opt.get_item_id(idx) == _liris_assign[i]:
					opt.select(idx)
					break
		var ability_idx := i
		opt.item_selected.connect(func(idx: int):
			_liris_assign[ability_idx] = opt.get_item_id(idx)
			_rebuild())
		row.add_child(opt)

func _build_liris_skills_step() -> void:
	var cd = _Factory.make_class_data(_liris_class_key)
	_add_header("Choose %d skills for Liris." % cd.skill_choices_count)
	for skill_int in cd.skill_options:
		var skill := skill_int as _SRD.Skill
		var chk := CheckBox.new()
		chk.text = _Skills.skill_name(skill)
		chk.button_pressed = int(skill) in _liris_skill_picks
		chk.toggled.connect(func(on: bool):
			var si := int(skill)
			if on and si not in _liris_skill_picks:
				if _liris_skill_picks.size() < cd.skill_choices_count:
					_liris_skill_picks.append(si)
				else:
					chk.set_pressed_no_signal(false)
			elif not on:
				_liris_skill_picks.erase(si)
			_validate())
		_body.add_child(chk)

# ── New steps: Species, Background, Spells ───────────────────────────────────

static func _is_caster(class_key: String) -> bool:
	return class_key == "psion" or class_key == "warden"

func _build_species_step() -> void:
	_add_header("Choose your species. Each grants ability score bonuses and unique traits.")
	var group := ButtonGroup.new()
	var desc_lbl := Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	desc_lbl.text = ""

	for sp in _SpeciesData.all_species():
		var btn := CheckBox.new()
		btn.button_group = group
		btn.toggle_mode = true
		var asi_parts: Array[String] = []
		var ab_abbrev := ["STR","DEX","CON","INT","WIS","CHA"]
		for ab in sp.asi:
			asi_parts.append("%s+%d" % [ab_abbrev[ab], sp.asi[ab]])
		var speed_str: String = " · Speed %dft" % sp.speed if sp.speed != 30 else ""
		var dv_str: String = " · Darkvision %dft" % sp.darkvision if sp.darkvision > 0 else ""
		btn.text = "%s  (%s%s%s)" % [sp.species_name, ", ".join(asi_parts), speed_str, dv_str]
		btn.button_pressed = _species_pick != null and _species_pick.species_name == sp.species_name
		var sp_ref = sp
		btn.toggled.connect(func(on: bool):
			if on:
				_species_pick = sp_ref
				desc_lbl.text = "Traits: " + ", ".join(sp_ref.traits)
				_validate())
		_body.add_child(btn)

	_body.add_child(desc_lbl)

func _build_background_step() -> void:
	_add_header("Choose a background. Each grants 2 skill proficiencies and a narrative feature.")
	var group := ButtonGroup.new()
	var feat_lbl := Label.new()
	feat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feat_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	feat_lbl.text = ""

	for bg in _BackgroundData.all_backgrounds():
		var btn := CheckBox.new()
		btn.button_group = group
		btn.toggle_mode = true
		var sk_names: Array[String] = []
		for sk_int in bg.skill_proficiencies:
			sk_names.append(_Skills.skill_name(sk_int as _SRD.Skill))
		btn.text = "%s  (%s)" % [bg.background_name, ", ".join(sk_names)]
		btn.button_pressed = _background_pick != null and _background_pick.background_name == bg.background_name
		var bg_ref = bg
		btn.toggled.connect(func(on: bool):
			if on:
				_background_pick = bg_ref
				feat_lbl.text = "%s: %s" % [bg_ref.feature_name, bg_ref.feature_desc]
				_validate())
		_body.add_child(btn)

	_body.add_child(feat_lbl)

func _build_spell_step() -> void:
	const CANTRIP_LIMIT := 3
	const SPELL_LIMIT := 2
	var all_cantrips: Array = _SpellData.psion_cantrips() if _class_key == "psion" \
		else _SpellData.warden_cantrips()
	var all_spells: Array = _SpellData.psion_l1_spells() if _class_key == "psion" \
		else _SpellData.warden_l1_spells()

	_add_header("Choose %d cantrips and %d level-1 spells." % [CANTRIP_LIMIT, SPELL_LIMIT])

	var c_header := Label.new()
	c_header.text = "── Cantrips ──"
	c_header.add_theme_font_size_override("font_size", 14)
	_body.add_child(c_header)

	for sp in all_cantrips:
		var chk := CheckBox.new()
		chk.text = "%s — %s" % [sp.spell_name, sp.description]
		chk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chk.button_pressed = _cantrip_picks.any(func(s): return s.spell_name == sp.spell_name)
		chk.disabled = not chk.button_pressed and _cantrip_picks.size() >= CANTRIP_LIMIT
		var sp_ref = sp
		chk.toggled.connect(func(on: bool):
			if on and not _cantrip_picks.any(func(s): return s.spell_name == sp_ref.spell_name):
				if _cantrip_picks.size() < CANTRIP_LIMIT:
					_cantrip_picks.append(sp_ref)
				else:
					chk.set_pressed_no_signal(false)
			elif not on:
				_cantrip_picks = _cantrip_picks.filter(func(s): return s.spell_name != sp_ref.spell_name)
			_rebuild())
		_body.add_child(chk)

	var s_header := Label.new()
	s_header.text = "── Level 1 Spells ──"
	s_header.add_theme_font_size_override("font_size", 14)
	_body.add_child(s_header)

	for sp in all_spells:
		var chk := CheckBox.new()
		chk.text = "%s — %s" % [sp.spell_name, sp.description]
		chk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chk.button_pressed = _sarro_spell_picks.any(func(s): return s.spell_name == sp.spell_name)
		chk.disabled = not chk.button_pressed and _sarro_spell_picks.size() >= SPELL_LIMIT
		var sp_ref = sp
		chk.toggled.connect(func(on: bool):
			if on and not _sarro_spell_picks.any(func(s): return s.spell_name == sp_ref.spell_name):
				if _sarro_spell_picks.size() < SPELL_LIMIT:
					_sarro_spell_picks.append(sp_ref)
				else:
					chk.set_pressed_no_signal(false)
			elif not on:
				_sarro_spell_picks = _sarro_spell_picks.filter(func(s): return s.spell_name != sp_ref.spell_name)
			_rebuild())
		_body.add_child(chk)
