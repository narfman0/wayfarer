## The Anchor Tear — Act 1 finale. The Mender Anchor fight per
## docs/design/bosses.md:
##
##   The real objective is the CRYSTALLIZATION RIG (a VeilRig planted in the
##   tear); Idris defends it. She cannot be killed — the fight ends when the
##   rig breaks, and the act closes on the Warden's Ritual choice
##   (dialogue/warden_ritual.dialogue), not a corpse.
##
##   Phase 1 (100–60%): heavy melee + slam telegraphs (archetype kit), plus
##     ANCHOR SURGE every ~26 s — a 4 s channel that repairs the rig unless
##     Shield Bash [5] interrupts it.
##   Phase 2 (60–30%): "Please — I'm so close." VEIL SHARDS — three sequential
##     line telegraphs sweeping from the rig; step between them.
##   Phase 3 (30%–): she stops fighting and pours everything into the rig — a
##     30 s channel that detonates on completion (heavy party damage) and
##     restarts. Liris answers with her own channel: the rig turns vulnerable
##     (+50% damage). Break it before the third detonation or bleed out.
##
## (bosses.md also lists crystal adds in phase 2 — deferred until dynamic
## enemy spawning exists; the pre-placed brutes are the fight's add pressure.)
class_name AnchorTearScene
extends WayfarerLevel

const _Telegraph = preload("res://scripts/combat/telegraph.gd")

const _SURGE_PERIOD := 26.0
const _SURGE_FIRST := 12.0
const _SURGE_CAST := 4.0
const _SURGE_HEAL_FRAC := 0.12
const _SHARDS_PERIOD := 13.0
const _SHARD_COUNT := 3
const _SHARD_GAP := 0.6         # seconds between sequential shards
const _COMPLETION_CAST := 30.0  # phase-3 rig channel
const _ENGAGE_DIST := 13.0

var _boss: EnemyController
var _rig: VeilRig
var _engaged := false
var _fight_over := false
var _phase := 0
var _surge_timer := _SURGE_FIRST
var _shards_timer := 6.0
var _shard_angle := 0.0

func _on_level_ready() -> void:
	super._on_level_ready()
	_boss = $Enemies/AnchorWarden
	_rig = $Enemies/VeilRig
	_boss.hp_changed.connect(_on_boss_hp)
	_boss.phase_changed.connect(_on_boss_phase_changed)
	_boss.cast_finished.connect(_on_boss_cast_finished)
	_boss.cast_interrupted.connect(_on_boss_cast_interrupted)
	_rig.died.connect(_on_rig_destroyed)
	_rig.healed.connect(func(amount: int) -> void:
		_DamageNumber.spawn(self, _rig.global_position + Vector3(0, 2.2, 0),
			"+%d rig" % amount, Color(0.7, 0.4, 1.0)))

func _process(delta: float) -> void:
	super._process(delta)
	if _fight_over or _defeated or _boss == null:
		return
	if not _engaged:
		if _player.global_position.distance_to(_boss.global_position) < _ENGAGE_DIST:
			_engaged = true
			print("[Boss] Idris: \"Stay back. I can still hold it together.\"")
		return
	if _phase < 2:
		_tick_surge(delta)
	if _phase >= 1:
		_tick_shards(delta)

# ── Mechanics ─────────────────────────────────────────────────────────────────

func _tick_surge(delta: float) -> void:
	_surge_timer -= delta
	if _surge_timer > 0.0 or _boss.is_casting():
		return
	_surge_timer = _SURGE_PERIOD
	_boss.start_cast("Anchor Surge", _SURGE_CAST)
	if _hud != null:
		_hud.show_toast_text("⚠ Anchor Surge — interrupt with [5] Shield Bash!")

func _tick_shards(delta: float) -> void:
	_shards_timer -= delta
	if _shards_timer > 0.0:
		return
	_shards_timer = _SHARDS_PERIOD
	_fire_veil_shards()

## Three sequential line telegraphs fanning around the rig. The dodge is
## stepping BETWEEN lanes — each fires 0.6 s after the previous.
func _fire_veil_shards() -> void:
	var base := _shard_angle
	_shard_angle += 0.9  # next volley sweeps from a rotated start
	for i in _SHARD_COUNT:
		var ang := base + i * (TAU / 5.0)
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		var t = _Telegraph.show_line(self, _rig.global_position, dir, 15.0, 2.2,
			1.1 + i * _SHARD_GAP)
		t.fired.connect(_on_shard_fired.bind(t))

func _on_shard_fired(t) -> void:
	for body in get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("companions"):
		if not body is Node3D or not t.contains((body as Node3D).global_position):
			continue
		var target_char = GameState.sarro if body.is_in_group("players") else GameState.liris
		if target_char == null or target_char.stats.current_hp <= 0:
			continue
		var dmg: int = CharacterProgression.modify_party_damage(
			_Dice.roll(8) + _Dice.roll(8), target_char, "zone")
		target_char.stats.current_hp = max(0, target_char.stats.current_hp - dmg)
		_DamageNumber.hit(self, (body as Node3D).global_position, dmg, false)
		_Juice.impact_burst(self, (body as Node3D).global_position, Color(0.7, 0.4, 1.0))
		AudioManager.play_sfx("hit", -2.0)
		print("[Boss] Veil Shard hits %s for %d" % [target_char.display_name, dmg])

# ── Phase / cast plumbing ─────────────────────────────────────────────────────

## Idris never dies: any hit that would drop her to 0 leaves her at 1 HP.
## (Runs inside hp_changed, which receive_damage emits BEFORE its death
## check — restoring to 1 here keeps _die() from ever firing.)
func _on_boss_hp(hp: int, _max_hp: int) -> void:
	if hp <= 0 and not _fight_over:
		_boss.character.stats.current_hp = 1

func _on_boss_phase_changed(phase: int) -> void:
	_phase = phase
	if phase == 1:
		print("[Boss] Idris: \"Please — I'm so close.\"")
		_shards_timer = 3.0
	elif phase == 2:
		print("[Boss] Idris stops fighting you. Everything goes into the rig.")
		if _hud != null:
			_hud.show_toast_text("⚠ Idris is completing the anchor — break the rig NOW!")
		_start_completion_channel()
		if GameState.liris != null and GameState.liris.stats.current_hp > 0:
			_rig.vulnerable = true
			print("[Boss] Liris channels against the lattice — the rig is VULNERABLE.")
			_DamageNumber.spawn(self, _rig.global_position + Vector3(0, 2.6, 0),
				"Liris: \"I see the seam. Hit it!\"", Color(0.95, 0.85, 0.3))

func _start_completion_channel() -> void:
	if _fight_over:
		return
	_boss.start_cast("Completing the Anchor", _COMPLETION_CAST)

func _on_boss_cast_finished(label: String) -> void:
	if label == "Anchor Surge":
		_rig.heal(int(_rig.character.stats.max_hp * _SURGE_HEAL_FRAC))
		print("[Boss] Anchor Surge completes — the rig re-knits.")
	elif label == "Completing the Anchor":
		_detonate()
		_start_completion_channel.call_deferred()

func _on_boss_cast_interrupted(label: String) -> void:
	AudioManager.play_sfx("crit", 1.0)
	if label == "Completing the Anchor":
		# punished, but she goes right back to it once the stun ends
		_start_completion_channel.call_deferred()
	print("[Boss] %s interrupted!" % label)

## The completion channel ran its course: the lattice discharges through
## everyone, and she starts again. Survivable, but it will not be twice.
func _detonate() -> void:
	AudioManager.play_sfx("death", 2.0)
	_Juice.shake(get_viewport().get_camera_3d(), 0.25, 0.4)
	for c in GameState.party():
		if c.stats.current_hp <= 0:
			continue
		var dmg: int = _Dice.roll(10) + _Dice.roll(10) + _Dice.roll(10)
		c.stats.current_hp = max(0, c.stats.current_hp - dmg)
		print("[Boss] The lattice discharge hits %s for %d" % [c.display_name, dmg])
	if _hud != null:
		_hud.show_toast_text("⚠ The lattice discharges! She begins again…")

# ── Resolution ────────────────────────────────────────────────────────────────

func _on_rig_destroyed() -> void:
	_fight_over = true
	# Subdue Idris: untargetable, rooted, out of the fight — not dead.
	_boss.interrupt_cast(0.0)
	_boss.stun(1e9)
	_boss.remove_from_group("enemies")
	_player.target_enemy = null
	if _hud != null:
		_hud.track_enemy(null)
	print("[Boss] The rig shatters. Idris collapses to her knees. The tear stills.")
	_start_ritual_dialogue.call_deferred()

func _start_ritual_dialogue() -> void:
	await get_tree().create_timer(1.4).timeout
	_player.set_control_enabled(false)
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/warden_ritual.dialogue"), "ritual")
	await DialogueManager.dialogue_ended
	_player.set_control_enabled(true)
	_victory()

func _victory() -> void:
	GameState.set_flag("act1_done")
	GameState.save_game()

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 16)
	dim.add_child(box)

	var title := Label.new()
	title.text = "The Anchor Tear stills."
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "The eastern water will clear by morning.\nAct 1 — Debt: complete."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var stats_line := Label.new()
	stats_line.text = "%s — Level %d (%d XP)" % [
		GameState.sarro.display_name, GameState.sarro.stats.level, GameState.sarro.stats.xp]
	stats_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats_line)

	var cont := Button.new()
	cont.text = "Continue"
	cont.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(cont)

	var keep := Button.new()
	keep.text = "Keep Exploring"
	keep.pressed.connect(layer.queue_free)
	box.add_child(keep)
