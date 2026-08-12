## The Convergence — Cael's arena (D3, bosses.md). As much dialogue as combat:
##
##   Phase 1 — "You still don't understand": Veil Bolt (circle at your feet),
##     Rift Step (he blinks away, leaving a lingering hazard pool), and
##     PLANAR ECHO — a copy of a previous boss ability, rotating through
##     Anchor Surge (interruptible self-heal), Veil Shards, and the Harvest
##     Beam sweep. The journey, replayed at you.
##   Phase 2 (60%) — "Then I'll show you what I've seen": COLLAPSE POINTS —
##     he targets the floor; stand in the circle to hold the node, or that
##     ground collapses into a permanent hazard (up to 3 — the arena shrinks).
##   Phase 3 (30%) — "I have no other choice": if Liris's conviction is high
##     enough (≥ 2), Cael stops fighting and the resolution is DIALOGUE —
##     combat ends without killing him. Otherwise: full collapse mode, every
##     mechanic faster, and the fight runs to its end.
##
## Both resolutions lead through the Final Portal choice to the ending; the
## dialogue resolution grants the different epilogue.
class_name ConvergenceScene
extends WayfarerLevel

const _Telegraph = preload("res://scripts/combat/telegraph.gd")

const _BOLT_PERIOD := 7.0
const _RIFT_PERIOD := 14.0
const _ECHO_PERIOD := 20.0
const _COLLAPSE_PERIOD := 15.0
const _COLLAPSE_MAX := 3
const _HAZARD_TICK := 1.2
const _ENGAGE_DIST := 14.0
const _CONVICTION_GATE := 2
const _COLLAPSE_RATE_SCALE := 0.6  # phase-3 desperation: everything faster

var _cael: EnemyController
var _engaged := false
var _over := false
var _phase := 0
var _collapse_mode := false
var _bolt_timer := 4.0
var _rift_timer := 10.0
var _echo_timer := 14.0
var _collapse_timer := 8.0
var _hazard_tick := 0.0
var _echo_idx := 0
var _hazards: Array = []  # {pos: Vector3, radius: float}
var _rng := RandomNumberGenerator.new()

func _on_level_ready() -> void:
	super._on_level_ready()
	_rng.seed = hash("convergence")
	_cael = $Enemies/Cael
	_cael.hp_changed.connect(_on_cael_hp)
	_cael.phase_changed.connect(_on_cael_phase)
	_cael.cast_finished.connect(_on_cael_cast_finished)
	_cael.died.connect(_on_cael_died)

func _process(delta: float) -> void:
	super._process(delta)
	if _over or _defeated or _cael == null:
		return
	_tick_hazards(delta)
	if not _engaged:
		if _player.global_position.distance_to(_cael.global_position) < _ENGAGE_DIST:
			_engaged = true
			print("[Boss] Cael: \"You still don't understand. I'll be brief.\"")
		return
	var scale := _COLLAPSE_RATE_SCALE if _collapse_mode else 1.0
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = _BOLT_PERIOD * scale
		_fire_veil_bolt()
	_rift_timer -= delta
	if _rift_timer <= 0.0:
		_rift_timer = _RIFT_PERIOD * scale
		_rift_step()
	_echo_timer -= delta
	if _echo_timer <= 0.0:
		_echo_timer = _ECHO_PERIOD * scale
		_fire_planar_echo()
	if _phase >= 1 and _hazards.size() < _COLLAPSE_MAX:
		_collapse_timer -= delta
		if _collapse_timer <= 0.0:
			_collapse_timer = _COLLAPSE_PERIOD * scale
			_fire_collapse_point()

# ── Phase 1 kit ───────────────────────────────────────────────────────────────

func _fire_veil_bolt() -> void:
	var t = _Telegraph.show_circle(self, _player.global_position, 2.2, 1.1)
	t.fired.connect(_on_zone_fired.bind(t, _Dice.roll(10) + _Dice.roll(10)))

## Blink away, leaving a hazard pool where he stood.
func _rift_step() -> void:
	var origin := _cael.global_position
	var ang := _rng.randf_range(0.0, TAU)
	var dest := origin + Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(5.0, 8.0)
	dest.x = clampf(dest.x, -16.0, 16.0)
	dest.z = clampf(dest.z, -16.0, 16.0)
	_Juice.impact_burst(self, origin, Color(0.7, 0.4, 1.0))
	_cael.global_position = dest
	_Juice.impact_burst(self, dest, Color(0.7, 0.4, 1.0))
	AudioManager.play_sfx("portal", -4.0)
	_add_hazard(origin, 1.8)
	print("[Boss] Cael rift-steps; the Veil bleeds where he stood.")

## A copy of a previous boss's ability — the journey, replayed.
func _fire_planar_echo() -> void:
	match _echo_idx % 3:
		0:
			_cael.start_cast("Echo: Anchor Surge", 4.0)
			if _hud != null:
				_hud.show_toast_text("⚠ Echo: Anchor Surge — interrupt with [5]!")
		1:
			for i in 3:
				var ang := _rng.randf_range(0.0, TAU) + i * (TAU / 5.0)
				var dir := Vector3(sin(ang), 0.0, cos(ang))
				var t = _Telegraph.show_line(self, _cael.global_position, dir, 14.0, 2.2,
					1.1 + i * 0.6)
				t.fired.connect(_on_zone_fired.bind(t, _Dice.roll(8) + _Dice.roll(8)))
			print("[Boss] Echo: Veil Shards.")
		2:
			var start := _rng.randf_range(0.0, TAU)
			for i in 5:
				var ang := start + PI * i / 4.0
				var dir := Vector3(sin(ang), 0.0, cos(ang))
				var t = _Telegraph.show_line(self, _cael.global_position, dir, 13.0, 2.0,
					1.0 + i * 0.5)
				t.fired.connect(_on_zone_fired.bind(t, _Dice.roll(10) + _Dice.roll(10)))
			print("[Boss] Echo: Harvest Beam.")
	_echo_idx += 1

func _on_cael_cast_finished(label: String) -> void:
	if label == "Echo: Anchor Surge" and not _over:
		var heal := int(_cael.character.stats.max_hp * 0.08)
		_cael.character.stats.current_hp = mini(_cael.character.stats.max_hp,
			_cael.character.stats.current_hp + heal)
		_cael.hp_changed.emit(_cael.character.stats.current_hp, _cael.character.stats.max_hp)
		print("[Boss] The echoed surge re-knits Cael for %d." % heal)

# ── Phase 2: Collapse Points ──────────────────────────────────────────────────

func _fire_collapse_point() -> void:
	var ang := _rng.randf_range(0.0, TAU)
	var r := _rng.randf_range(4.0, 11.0)
	var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	var t = _Telegraph.show_circle(self, pos, 2.5, 3.0)
	t.fired.connect(_on_collapse_fired.bind(t))
	if _hud != null:
		_hud.show_toast_text("⚠ Collapse Point — stand in it to hold the floor!")

func _on_collapse_fired(t) -> void:
	if _over:
		return
	for body in get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("companions"):
		if body is Node3D and t.contains((body as Node3D).global_position):
			_DamageNumber.spawn(self, t.global_position + Vector3(0, 1.5, 0),
				"HELD", Color(0.6, 1.0, 0.7))
			print("[Boss] The node is held. The floor stays real.")
			return
	_add_hazard(t.global_position, 2.5)
	print("[Boss] A section of the arena collapses into the Veil.")
	if _hud != null:
		_hud.show_toast_text("⚠ The floor gives way — %d collapse(s)." % _hazards.size())

# ── Hazard pools (rift scars + collapsed floor) ───────────────────────────────

func _add_hazard(pos: Vector3, radius: float) -> void:
	_hazards.append({"pos": pos, "radius": radius})
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	mi.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.05, 0.35, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.15, 0.8)
	mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)

func _tick_hazards(delta: float) -> void:
	if _hazards.is_empty():
		return
	_hazard_tick -= delta
	if _hazard_tick > 0.0:
		return
	_hazard_tick = _HAZARD_TICK
	for body in get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("companions"):
		if not body is Node3D:
			continue
		for h in _hazards:
			var d2: float = Vector2(body.global_position.x - h["pos"].x,
				body.global_position.z - h["pos"].z).length_squared()
			if d2 <= h["radius"] * h["radius"]:
				_zone_damage(body as Node3D, _Dice.roll(8))
				break

func _on_zone_fired(t, dmg: int) -> void:
	if _over:
		return
	for body in get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("companions"):
		if body is Node3D and t.contains((body as Node3D).global_position):
			_zone_damage(body as Node3D, dmg)

func _zone_damage(body: Node3D, dmg: int) -> void:
	var target_char = GameState.sarro if body.is_in_group("players") else GameState.liris
	if target_char == null or target_char.stats.current_hp <= 0:
		return
	dmg = CharacterProgression.modify_party_damage(dmg, target_char, "zone")
	target_char.stats.current_hp = max(0, target_char.stats.current_hp - dmg)
	_DamageNumber.hit(self, body.global_position, dmg, false)
	_Juice.impact_burst(self, body.global_position, Color(0.7, 0.4, 1.0))
	AudioManager.play_sfx("hit", -3.0)

# ── Phase 3: conviction gate ──────────────────────────────────────────────────

func _on_cael_hp(hp: int, _max_hp: int) -> void:
	# In the dialogue path Cael never dies mid-conversation window.
	if hp <= 0 and not _over and GameState.conviction() >= _CONVICTION_GATE:
		_cael.character.stats.current_hp = 1

func _on_cael_phase(phase: int) -> void:
	_phase = phase
	if phase == 1:
		print("[Boss] Cael: \"Then I'll show you what I've seen.\"")
		_collapse_timer = 5.0
	elif phase == 2:
		if GameState.conviction() >= _CONVICTION_GATE:
			_begin_dialogue_resolution()
		else:
			_collapse_mode = true
			print("[Boss] Cael: \"I have no other choice.\"")
			if _hud != null:
				_hud.show_toast_text("⚠ Full collapse — everything, at once, faster.")

## High conviction: he stops. The rest is words.
func _begin_dialogue_resolution() -> void:
	_over = true
	_cael.interrupt_cast(0.0)
	_cael.stun(1e9)
	_cael.remove_from_group("enemies")
	_player.target_enemy = null
	if _attacker != null:
		_attacker.stop()
	if _hud != null:
		_hud.track_enemy(null)
	print("[Boss] Cael lowers his hands. \"...Say it, then. The warden's version.\"")
	_run_resolution_dialogue.call_deferred()

func _run_resolution_dialogue() -> void:
	await get_tree().create_timer(1.2).timeout
	_player.set_control_enabled(false)
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/cael_resolution.dialogue"), "resolution")
	await DialogueManager.dialogue_ended
	GameState.set_flag("cael_convinced")
	GameState.grant_xp(25000)
	_finish("understood")

## Low conviction: the fight runs to its end.
func _on_cael_died() -> void:
	if _over:
		return
	_over = true
	GameState.set_flag("cael_fought")
	_finish("fought")

func _finish(ending: String) -> void:
	GameState.set_flag("game_won")
	GameState.save_game()
	_final_portal_then_victory.call_deferred(ending)

func _final_portal_then_victory(ending: String) -> void:
	await get_tree().create_timer(1.2).timeout
	_player.set_control_enabled(false)
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/final_portal.dialogue"), "final")
	await DialogueManager.dialogue_ended
	GameState.save_game()
	_player.set_control_enabled(true)
	_victory(ending)

func _victory(ending: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 16)
	dim.add_child(box)

	var title := Label.new()
	title.text = "The stitching stops."
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	if ending == "understood":
		sub.text = "He calls it off himself. His team obeys on trust.\nNot beaten — persuaded. In Tamori, the eastern water clears.\n\nWAYFARER"
	else:
		sub.text = "The apparatus dies with its maker's silence.\nHis team scatters. In Tamori, the eastern water clears — slowly.\n\nWAYFARER"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var hours := int(GameState.play_time_seconds) / 3600
	var minutes := (int(GameState.play_time_seconds) % 3600) / 60
	var stats_line := Label.new()
	stats_line.text = "%s — Level %d (%d XP) — %dh %02dm" % [
		GameState.sarro.display_name, GameState.sarro.stats.level,
		GameState.sarro.stats.xp, hours, minutes]
	stats_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats_line)

	var cont := Button.new()
	cont.text = "Continue"
	cont.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(cont)

	var keep := Button.new()
	keep.text = "Stay a While"
	keep.pressed.connect(layer.queue_free)
	box.add_child(keep)
