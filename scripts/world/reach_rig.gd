## The Extraction Rig — Act 2a finale. The Extractor Engine fight per
## docs/design/bosses.md: an autonomous harvest construct, pure mechanics,
## horror tone. No dialogue — the horror is that nobody is driving.
##
##   All phases: heavy melee kit (slam telegraphs) plus HARVEST BEAM — a line
##     telegraph sweeping 180° around the Engine in five steps. Standing
##     behind a surviving extraction pillar blocks the beam, so the pillars
##     are cover worth protecting.
##   Phase 1 (60%): the Engine grinds up one of its own pillars; beams faster.
##   Phase 2 (30%): it consumes the rest — the arena is open — beams faster
##     still, and SIPHON ZONES appear: circle soaks that must have somebody
##     standing in them when they fire or the discharge arcs to everyone.
##
## Killing the Engine sets reach_rig_done (gates the Kaveth portal).
class_name ExtractorRigScene
extends WayfarerLevel

const _Telegraph = preload("res://scripts/combat/telegraph.gd")
const _Juice     = preload("res://scripts/combat/juice.gd")

const _BEAM_PERIODS := [12.0, 9.5, 7.5]  # by boss phase
const _BEAM_STEPS := 5
const _BEAM_STEP_GAP := 0.5
const _BEAM_LEN := 14.0
const _BEAM_WIDTH := 2.0
const _SOAK_PERIOD := 16.0
const _SOAK_RADIUS := 2.2
const _ENGAGE_DIST := 15.0
const _PILLAR_BLOCK_DIST := 1.4

var _engine: EnemyController
var _pillars: Array = []
var _engaged := false
var _over := false
var _phase := 0
var _beam_timer := 7.0
var _soak_timer := 8.0
var _beam_angle := 0.0
var _rng := RandomNumberGenerator.new()

func _on_level_ready() -> void:
	super._on_level_ready()
	_rng.seed = hash("reach_rig")
	_engine = $Enemies/Engine
	_engine.phase_changed.connect(_on_engine_phase)
	_engine.died.connect(_on_engine_died)
	for p in [$Enemies/Pillar1, $Enemies/Pillar2, $Enemies/Pillar3]:
		_pillars.append(p)

func _process(delta: float) -> void:
	super._process(delta)
	if _over or _defeated or _engine == null:
		return
	if not _engaged:
		if _player.global_position.distance_to(_engine.global_position) < _ENGAGE_DIST:
			_engaged = true
			print("[Boss] The Engine registers you. It does not hurry.")
		return
	_beam_timer -= delta
	if _beam_timer <= 0.0:
		_beam_timer = _BEAM_PERIODS[_phase]
		_fire_harvest_beam()
	if _phase >= 2:
		_soak_timer -= delta
		if _soak_timer <= 0.0:
			_soak_timer = _SOAK_PERIOD
			_fire_siphon_zones()

# ── Harvest Beam ──────────────────────────────────────────────────────────────

## Five sequential line telegraphs sweeping half a turn around the Engine.
## Rotate with it — or put a pillar between you and the emitter.
func _fire_harvest_beam() -> void:
	var start := _beam_angle
	_beam_angle += 2.4  # next sweep starts elsewhere
	for i in _BEAM_STEPS:
		var ang := start + PI * i / (_BEAM_STEPS - 1)
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		var t = _Telegraph.show_line(self, _engine.global_position, dir,
			_BEAM_LEN, _BEAM_WIDTH, 1.0 + i * _BEAM_STEP_GAP)
		t.fired.connect(_on_beam_fired.bind(t))
	if _hud != null:
		_hud.show_toast_text("⚠ Harvest Beam — rotate with it or break line of sight!")

func _on_beam_fired(t) -> void:
	if _over:
		return
	for body in get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("companions"):
		if not body is Node3D or not t.contains((body as Node3D).global_position):
			continue
		if _pillar_shields(body as Node3D):
			_DamageNumber.spawn(self, (body as Node3D).global_position + Vector3(0, 1.8, 0),
				"BLOCKED", Color(0.6, 0.9, 1.0))
			continue
		_beam_damage(body as Node3D, _Dice.roll(10) + _Dice.roll(10))

## True if a surviving pillar stands between the Engine and the body.
func _pillar_shields(body: Node3D) -> bool:
	var a := _engine.global_position
	var b := body.global_position
	for pillar in _pillars:
		if not is_instance_valid(pillar) or not pillar.is_in_group("enemies"):
			continue
		var p: Vector3 = pillar.global_position
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var len2 := ab.length_squared()
		if len2 < 0.001:
			continue
		var frac := clampf(ap.dot(ab) / len2, 0.0, 1.0)
		if ap.distance_to(ab * frac) <= _PILLAR_BLOCK_DIST:
			return true
	return false

func _beam_damage(body: Node3D, dmg: int) -> void:
	var target_char = GameState.sarro if body.is_in_group("players") else GameState.liris
	if target_char == null or target_char.stats.current_hp <= 0:
		return
	target_char.stats.current_hp = max(0, target_char.stats.current_hp - dmg)
	_DamageNumber.hit(self, body.global_position, dmg, false)
	_Juice.impact_burst(self, body.global_position, Color(0.4, 0.9, 1.0))
	AudioManager.play_sfx("hit", -2.0)
	print("[Boss] Harvest Beam hits %s for %d" % [target_char.display_name, dmg])

# ── Siphon zones (phase 2) ────────────────────────────────────────────────────

## Two circle soaks: somebody must STAND in each when it fires, or the
## uncollected charge arcs through the whole party.
func _fire_siphon_zones() -> void:
	for i in 2:
		var ang := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(3.0, 8.0)
		var pos: Vector3 = _engine.global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var t = _Telegraph.show_circle(self, pos, _SOAK_RADIUS, 2.6)
		t.fired.connect(_on_siphon_fired.bind(t))
	if _hud != null:
		_hud.show_toast_text("⚠ Siphon zones — someone must stand in each!")

func _on_siphon_fired(t) -> void:
	if _over:
		return
	var party := get_tree().get_nodes_in_group("players") + get_tree().get_nodes_in_group("companions")
	for body in party:
		if body is Node3D and t.contains((body as Node3D).global_position):
			_DamageNumber.spawn(self, t.global_position + Vector3(0, 1.5, 0),
				"Grounded", Color(0.6, 0.9, 1.0))
			return  # soaked — no discharge
	for body in party:
		if body is Node3D:
			_beam_damage(body as Node3D, _Dice.roll(8) + _Dice.roll(8))
	if _hud != null:
		_hud.show_toast_text("⚠ Unsoaked siphon discharges through the party!")

# ── Phases / resolution ───────────────────────────────────────────────────────

func _on_engine_phase(phase: int) -> void:
	_phase = phase
	if phase == 1:
		_consume_pillar()
		print("[Boss] The Engine grinds one of its own pillars into itself.")
	elif phase == 2:
		while _consume_pillar():
			pass
		print("[Boss] The Engine consumes the rest. The arena is open.")
		if _hud != null:
			_hud.show_toast_text("⚠ No cover left — keep moving!")

## Destroy the nearest surviving pillar. Returns false when none remain.
func _consume_pillar() -> bool:
	for pillar in _pillars:
		if is_instance_valid(pillar) and pillar.is_in_group("enemies"):
			pillar.receive_damage(99999)
			_Juice.shake(get_viewport().get_camera_3d(), 0.18)
			return true
	return false

func _on_engine_died() -> void:
	_over = true
	GameState.set_flag("reach_rig_done")
	GameState.save_game()
	print("[Boss] The Engine stops. Nothing turns it back on.")
	if _hud != null:
		_hud.show_toast_text("The Engine is silent. The way to Old Kaveth is open.")
