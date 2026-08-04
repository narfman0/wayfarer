## Rest-point choice screen: pages through Sarro's pending build choices
## (CharacterProgression.pending_choices) oldest-first — fighting style and
## feat pages double as the old-save migration path — and closes on a rest
## summary that carries Liris's story-driven unlock announcements.
##
## Construct with `LevelUpScreen.open(parent)`; connect/await `finished`.
## Pauses the tree while open, like the pause menu.
class_name LevelUpScreen
extends CanvasLayer

signal finished

const _Progression = preload("res://scripts/characters/character_progression.gd")
const _SRD         = preload("res://addons/srd/srd_enums.gd")

var _panel: VBoxContainer

static func open(parent: Node) -> LevelUpScreen:
	var s: LevelUpScreen = load("res://scripts/ui/level_up_screen.gd").new()
	parent.add_child(s)
	return s

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.custom_minimum_size = Vector2(560, 520)
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.custom_minimum_size.x = 540
	_panel.add_theme_constant_override("separation", 10)
	scroll.add_child(_panel)

	_show_next_page()

# ── Paging ────────────────────────────────────────────────────────────────────

func _show_next_page() -> void:
	for child in _panel.get_children():
		child.queue_free()
	var c = GameState.sarro
	var pend: Array = _Progression.pending_choices(c) if c != null else []
	if pend.is_empty():
		_build_summary_page()
		return
	var p: Dictionary = pend[0]
	match str(p.get("kind")):
		"style":
			_build_pick_page("Fighting Style",
				"The stable tear steadies you. Commit to a stance.",
				_style_options(c), func(key): return {"kind": "style", "style": key})
		"feat":
			_build_pick_page("Feat (level %d)" % int(p.get("level", 1)),
				"A knack, sharpened into something dependable.",
				_feat_options(c),
				func(key): return {"kind": "feat", "level": int(p.get("level", 1)), "feat": key})
		"subclass":
			_build_pick_page("Subclass — level 3",
				"Your way of fighting has become a discipline. Name it.",
				_subclass_options(c), func(key): return {"kind": "subclass", "subclass": key})
		"asi_or_feat":
			_build_asi_page(int(p.get("level")))

func _apply_and_advance(rec: Dictionary) -> void:
	_Progression.apply_choice(GameState.sarro, rec)
	if str(rec.get("kind")) == "subclass" and str(rec.get("subclass")) == "faceless":
		GameState.set_flag("faceless")
	AudioManager.play_sfx("portal", -6.0)
	_show_next_page()

# ── Pages ─────────────────────────────────────────────────────────────────────

## options: Array of {key, name, desc}
func _build_pick_page(title: String, blurb: String, options: Array,
		to_record: Callable) -> void:
	_add_title(title)
	_add_blurb(blurb)
	for opt in options:
		var btn := Button.new()
		btn.text = opt["name"]
		btn.pressed.connect(func(): _apply_and_advance(to_record.call(opt["key"])))
		_panel.add_child(btn)
		_add_desc(opt["desc"])

func _build_asi_page(lvl: int) -> void:
	_add_title("Level %d — Ability Increase or Feat" % lvl)
	_add_blurb("Push your body further, or learn something new.")

	_add_section("Ability increase (+2)")
	var stats = GameState.sarro.stats
	for a in _Progression._ASISystem.improvable_abilities(stats):
		var btn := Button.new()
		btn.text = "+2 %s  (%d → %d)" % [_SRD.ability_name(a),
			stats.get_ability(a), mini(20, stats.get_ability(a) + 2)]
		btn.pressed.connect(func(): _apply_and_advance(
			{"kind": "asi", "level": lvl, "mode": "single", "ability": int(a)}))
		_panel.add_child(btn)

	_add_section("Split (+1 / +1)")
	var row := HBoxContainer.new()
	_panel.add_child(row)
	var opt_a := _ability_dropdown(stats)
	var opt_b := _ability_dropdown(stats)
	row.add_child(opt_a)
	row.add_child(opt_b)
	var split_btn := Button.new()
	split_btn.text = "Apply Split"
	split_btn.pressed.connect(func():
		var a := opt_a.get_selected_id()
		var b := opt_b.get_selected_id()
		if a >= 0 and b >= 0 and a != b:
			_apply_and_advance({"kind": "asi", "level": lvl, "mode": "split",
				"abilities": [a, b]}))
	row.add_child(split_btn)

	_add_section("Or take a feat")
	for opt in _feat_options(GameState.sarro):
		var btn := Button.new()
		btn.text = opt["name"]
		btn.pressed.connect(func(): _apply_and_advance(
			{"kind": "feat", "level": lvl, "feat": opt["key"]}))
		_panel.add_child(btn)
		_add_desc(opt["desc"])

## Rest summary: what the tear gives back, plus Liris's arc announcements.
func _build_summary_page() -> void:
	_add_title("The current steadies you.")
	var lines: Array[String] = []
	var sarro = GameState.sarro
	if sarro != null:
		lines.append("%s — Level %d.  HP restored, abilities recovered." %
			[sarro.display_name, sarro.stats.level])
		if sarro.subclass_key != "":
			lines.append("Discipline: %s" % _Progression.SUBCLASSES[
				_Progression.class_key(sarro)][sarro.subclass_key]["name"])
	var liris = GameState.liris
	if liris != null:
		var announced := int(GameState.get_flag("liris_announced_level", 1))
		for lvl in _Progression.LIRIS_UNLOCKS:
			if lvl > announced and lvl <= liris.stats.level:
				lines.append("")
				lines.append(str(_Progression.LIRIS_UNLOCKS[lvl]))
		GameState.set_flag("liris_announced_level", liris.stats.level)
	var body := Label.new()
	body.text = "\n".join(lines)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(body)

	var done := Button.new()
	done.text = "Break camp"
	done.pressed.connect(_close)
	_panel.add_child(done)

func _close() -> void:
	get_tree().paused = false
	finished.emit()
	queue_free()

# ── Option lists ──────────────────────────────────────────────────────────────

func _style_options(c) -> Array:
	var out := []
	for key in _Progression.styles_for(_Progression.class_key(c)):
		var spec: Dictionary = _Progression.FIGHTING_STYLES[key]
		out.append({"key": key, "name": spec["name"], "desc": spec["desc"]})
	return out

func _feat_options(c) -> Array:
	var out := []
	for key in _Progression.FEATS:
		if _Progression.has_feat(c, key):
			continue  # each feat once
		var spec: Dictionary = _Progression.FEATS[key]
		out.append({"key": key, "name": spec["name"], "desc": spec["desc"]})
	return out

func _subclass_options(c) -> Array:
	var out := []
	var table: Dictionary = _Progression.SUBCLASSES[_Progression.class_key(c)]
	for key in table:
		out.append({"key": key, "name": table[key]["name"], "desc": table[key]["desc"]})
	return out

func _ability_dropdown(stats) -> OptionButton:
	var opt := OptionButton.new()
	opt.add_item("—", -1)
	for a in _Progression._ASISystem.improvable_abilities(stats):
		opt.add_item(_SRD.ability_abbrev(a), int(a))
	return opt

# ── Layout helpers ────────────────────────────────────────────────────────────

func _add_title(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	_panel.add_child(lbl)

func _add_blurb(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	_panel.add_child(lbl)

func _add_section(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "— %s —" % text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	_panel.add_child(lbl)

func _add_desc(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "    " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_panel.add_child(lbl)
