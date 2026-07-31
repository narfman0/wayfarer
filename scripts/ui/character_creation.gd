## SRD character creation wizard: Class → Abilities → Skills → Review.
## Builds the player character (Sarro) from real SRD rules; Liris joins as a
## fixed companion.
class_name CharacterCreation
extends Control

const _Factory       = preload("res://scripts/characters/character_factory.gd")
const _SRD           = preload("res://addons/srd/srd_enums.gd")
const _AbilityScores = preload("res://addons/srd/systems/ability_scores.gd")
const _Skills        = preload("res://addons/srd/systems/skills_system.gd")

enum Step { CLASS, ABILITIES, SKILLS, REVIEW }
enum Method { POINT_BUY, STANDARD_ARRAY, ROLL }

const STEP_TITLES := ["Class", "Ability Scores", "Skills", "Review"]

@onready var _step_label: Label = $Layout/StepLabel
@onready var _body: VBoxContainer = $Layout/Content/StepBody
@onready var _back_btn: Button = $Layout/Nav/Back
@onready var _next_btn: Button = $Layout/Nav/Next

var _step: Step = Step.CLASS
var _class_key: String = "soldier"
var _method: Method = Method.POINT_BUY
var _pb_scores: Array[int] = [8, 8, 8, 8, 8, 8]      # point buy, by SRD.Ability
var _assign: Array[int] = [-1, -1, -1, -1, -1, -1]   # ability → pool index
var _pool: Array[int] = []                            # array/roll values
var _skill_picks: Array[int] = []
var _char_name: String = "Sarro"

func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_next_btn.pressed.connect(_on_next)
	_pool = _AbilityScores.STANDARD_ARRAY.duplicate()
	_rebuild()

# ── Navigation ───────────────────────────────────────────────────────────────

func _on_back() -> void:
	if _step == Step.CLASS:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return
	_step = (_step - 1) as Step
	_rebuild()

func _on_next() -> void:
	if _step == Step.REVIEW:
		_confirm()
		return
	_step = (_step + 1) as Step
	_rebuild()

func _confirm() -> void:
	var sarro = _Factory.make_custom(_char_name, _class_key, _scores(), _skill_picks)
	GameState.set_party(sarro, _Factory.make_liris())
	get_tree().change_scene_to_file("res://scenes/world/tamori.tscn")

## The six chosen scores indexed by SRD.Ability, per the active method.
func _scores() -> Array:
	if _method == Method.POINT_BUY:
		return _pb_scores.duplicate()
	var out: Array[int] = []
	for i in 6:
		out.append(_pool[_assign[i]] if _assign[i] >= 0 else 8)
	return out

func _rebuild() -> void:
	_step_label.text = "Step %d of %d — %s" % [_step + 1, STEP_TITLES.size(), STEP_TITLES[_step]]
	_back_btn.text = "Main Menu" if _step == Step.CLASS else "Back"
	_next_btn.text = "Begin" if _step == Step.REVIEW else "Next"
	for child in _body.get_children():
		child.queue_free()
	match _step:
		Step.CLASS:     _build_class_step()
		Step.ABILITIES: _build_abilities_step()
		Step.SKILLS:    _build_skills_step()
		Step.REVIEW:    _build_review_step()
	_validate()

func _validate() -> void:
	match _step:
		Step.ABILITIES:
			if _method == Method.POINT_BUY:
				_next_btn.disabled = not _AbilityScores.point_buy_valid(_pb_scores)
			else:
				_next_btn.disabled = _assign.count(-1) > 0
		Step.SKILLS:
			var cd = _Factory.make_class_data(_class_key)
			_next_btn.disabled = _skill_picks.size() != cd.skill_choices_count
		Step.REVIEW:
			_next_btn.disabled = _char_name.strip_edges().is_empty()
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
				_rebuild())
		_body.add_child(btn)
		var desc := Label.new()
		desc.text = "    " + cd.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		_body.add_child(desc)

# ── Step 2: Ability scores ───────────────────────────────────────────────────

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
	var combatant = preview.make_combatant()
	var cd = preview.class_data
	var scores := _scores()

	var lines: Array[String] = []
	lines.append("%s — Level 1 %s" % [preview.display_name, cd.class_name_str])
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

func _fixed_label(text: String, width: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = width
	return lbl

static func _mod(score: int) -> int:
	return (score - 10) / 2 if score >= 10 else (score - 11) / 2
