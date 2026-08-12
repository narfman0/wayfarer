## Enemy readability layer: name + HP + condition badges for enemies, with a
## configurable placement (settings → "Enemy info"):
##   top    — one Diablo-style bar, top-center, for the current target
##   beside — a compact widget floating above the current target
##   all    — mini widgets over every aggroed enemy
## Identification takes time: AC and archetype read "???" until the enemy has
## been targeted ~4 s cumulative (then it sticks, stored on the enemy node).
## Built procedurally as a child of the HUD root.
class_name EnemyInfo
extends Control

const IDENTIFY_SECS := 4.0
const _META_IDENTIFIED := "wayfarer_identified"
const _META_TARGET_TIME := "wayfarer_target_time"

var _panels: Dictionary = {}   # enemy instance_id -> PanelContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var mode: String = Graphics.ui_setting("enemy_info", "beside")
	var player := _player()
	var target: Node3D = player.target_enemy if player != null else null
	if target != null and is_instance_valid(target):
		var t: float = target.get_meta(_META_TARGET_TIME, 0.0) + delta
		target.set_meta(_META_TARGET_TIME, t)
		if t >= IDENTIFY_SECS:
			target.set_meta(_META_IDENTIFIED, true)

	var hovered: Node3D = player.get("hovered_enemy") if player != null else null
	var wanted: Array[Node3D] = []
	match mode:
		"top", "beside":
			if target != null and is_instance_valid(target) and _alive(target):
				wanted.append(target)
		"all":
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and _alive(e) and e.get("_state") != null and int(e._state) != 0:
					wanted.append(e)
			if target != null and is_instance_valid(target) and _alive(target) \
					and not wanted.has(target):
				wanted.append(target)
	# hovering any enemy shows its widget in every mode
	if hovered != null and is_instance_valid(hovered) and _alive(hovered) \
			and not wanted.has(hovered):
		wanted.append(hovered)

	# prune stale panels
	for id in _panels.keys().duplicate():
		var still := false
		for e in wanted:
			if e.get_instance_id() == id:
				still = true
		if not still:
			_panels[id].queue_free()
			_panels.erase(id)

	var cam := get_viewport().get_camera_3d()
	for e in wanted:
		var id := e.get_instance_id()
		if not _panels.has(id):
			_panels[id] = _build_panel()
		_refresh_panel(_panels[id], e, e == target)
		var panel: PanelContainer = _panels[id]
		if mode == "top" and e == target:
			panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
			panel.position = Vector2(get_rect().size.x * 0.5 - panel.size.x * 0.5, 14)
		elif cam != null:
			var sp := cam.unproject_position(e.global_position + Vector3(0, 2.5, 0))
			panel.position = sp - Vector2(panel.size.x * 0.5, panel.size.y)

func _build_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	style.border_color = Color(0.55, 0.45, 0.25)
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(name_lbl)
	var hp_bg := ColorRect.new()
	hp_bg.name = "HpBg"
	hp_bg.color = Color(0.2, 0.05, 0.05)
	hp_bg.custom_minimum_size = Vector2(110, 6)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hp_bg)
	var hp_fill := ColorRect.new()
	hp_fill.name = "HpFill"
	hp_fill.color = Color(0.85, 0.25, 0.2)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(hp_fill)
	var info_lbl := Label.new()
	info_lbl.name = "InfoLabel"
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(info_lbl)
	add_child(panel)
	return panel

func _refresh_panel(panel: PanelContainer, e: Node3D, is_target: bool) -> void:
	var ch = e.get("character")
	var name_lbl: Label = panel.find_child("NameLabel", true, false)
	var hp_bg: ColorRect = panel.find_child("HpBg", true, false)
	var hp_fill: ColorRect = panel.find_child("HpFill", true, false)
	var info_lbl: Label = panel.find_child("InfoLabel", true, false)

	var display: String = String(ch.display_name) if ch != null else String(e.name)
	var badges := _badges(e)
	name_lbl.text = display + ("  " + badges if badges != "" else "")

	if ch != null and ch.stats != null:
		var frac := clampf(float(ch.stats.current_hp) / maxf(1.0, ch.stats.max_hp), 0.0, 1.0)
		hp_fill.size = Vector2(hp_bg.size.x * frac, hp_bg.size.y)
	if e.get_meta(_META_IDENTIFIED, false) and ch != null:
		var ac: int = ch.make_combatant().armor_class if ch.has_method("make_combatant") else 0
		var arch: String = String(e.get("_arch")) if e.get("_arch") != null else "?"
		var hp_txt: String = ("%d/%d" % [ch.stats.current_hp, ch.stats.max_hp]) if ch.stats != null else ""
		info_lbl.text = "AC %d · %s · %s" % [ac, arch, hp_txt]
	elif is_target:
		info_lbl.text = "identifying…"
	else:
		info_lbl.text = ""

## Compact condition badges: ⊘ stunned, ◍ casting, ⌗ held, ✦ marked.
func _badges(e: Node3D) -> String:
	var out := ""
	if e.has_method("is_stunned") and e.is_stunned():
		out += "⊘"
	if e.has_method("is_casting") and e.is_casting():
		out += "◍"
	if e.has_method("is_rooted") and e.is_rooted():
		out += "⌗"
	if e.get("guiding_bolt_active") == true:
		out += "✦"
	return out

func _alive(e: Node3D) -> bool:
	var ch = e.get("character")
	return ch != null and ch.stats != null and ch.stats.current_hp > 0

func _player() -> Node:
	var players := get_tree().get_nodes_in_group("players")
	return players[0] if players.size() > 0 else null
