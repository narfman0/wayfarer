## Headless smoke test for the phase-1 combat feel pass. Loads the Reach,
## shoves Sarro at a skirmisher and then a heavy, and asserts that:
##   1. skirmishers fire projectiles,
##   2. heavies put a telegraph on the ground,
##   3. a killed enemy leaves the "enemies" group immediately and its body
##      frees after the death collapse.
## Run: godot --headless res://future/tests/harnesses/phase1_smoke.tscn
extends Node

const _ProjectileScript = preload("res://scripts/combat/projectile.gd")
const _TelegraphScript  = preload("res://scripts/combat/telegraph.gd")

var _level: Node
var _player: CharacterBody3D
var _failures: Array[String] = []

func _ready() -> void:
	_level = load("res://scenes/world/reach.tscn").instantiate()
	add_child(_level)
	await get_tree().process_frame
	_player = _level.get_node("Characters/Sarro")
	# The debug party is level 5 in a level-6/7 plane — pad HP so a party wipe
	# can't reload the scene mid-test.
	GameState.sarro.stats.max_hp = 900
	GameState.sarro.stats.current_hp = 900
	GameState.liris.stats.max_hp = 900
	GameState.liris.stats.current_hp = 900
	_run()

func _run() -> void:
	await _test_camera_zoom()
	_test_combat_clips()
	await _test_spellcasting()
	await _test_skirmisher_fires()
	await _test_death_collapse()
	await _test_heavy_telegraphs()
	if _failures.is_empty():
		print("PHASE1 SMOKE: ALL PASS")
	else:
		for f in _failures:
			print("PHASE1 SMOKE FAIL: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)

## Zoom is orthographic now: the wheel tweens Camera3D.size between the
## min/max ortho extents.
func _test_camera_zoom() -> void:
	var cam: Camera3D = _level.get_node("CameraPivot/Camera3D")
	var rest: float = cam.size
	_level._adjust_zoom(-2.0)
	await get_tree().create_timer(0.4).timeout
	_check(cam.size < rest - 0.5, "wheel zoom narrows the ortho view")
	for i in 10:
		_level._adjust_zoom(-2.0)
	await get_tree().create_timer(0.4).timeout
	_check(cam.size >= 13.9 and cam.size <= 14.5, "zoom clamps at the close limit")
	for i in 12:
		_level._adjust_zoom(2.0)
	await get_tree().create_timer(0.4).timeout
	_check(cam.size >= 25.5 and cam.size <= 26.1, "zoom clamps at the far limit")

## Sword Combat clips retarget and load onto every humanoid animator.
func _test_combat_clips() -> void:
	var skin := _player.get_node_or_null("Skin")
	_check(skin != null and skin.has_meta("wayfarer_animator"), "player skin has an animator")
	if skin != null and skin.has_meta("wayfarer_animator"):
		var anim = skin.get_meta("wayfarer_animator")
		for clip in ["attack", "attack_heavy", "hit", "death"]:
			_check(anim._ap.has_animation(clip), "sword clip '%s' loaded" % clip)

## Spells cast through the public cast_spell path: damage lands, slots spend,
## cantrips don't, heals restore the caster.
func _test_spellcasting() -> void:
	var spell_data = preload("res://addons/srd/resources/spell_data.gd")
	var guard := _level.get_node("Enemies/PenGuard2") as CharacterBody3D
	var liris = GameState.liris

	# damage spell from Liris (Warden — has slots) at Sarro's target
	_player.target_enemy = guard
	var hp_before: int = guard.character.stats.current_hp
	var slots_before: int = liris.energy_slots.slots_remaining_at(1)
	_level.cast_spell(spell_data.make_guiding_bolt(), liris)
	_check(guard.character.stats.current_hp < hp_before, "damage spell hurts the target")
	_check(liris.energy_slots.slots_remaining_at(1) == slots_before - 1,
		"L1 spell spends a slot")

	# cantrip: no slot spent
	slots_before = liris.energy_slots.slots_remaining_at(1)
	_level.cast_spell(spell_data.make_sacred_flame(), liris)
	_check(liris.energy_slots.slots_remaining_at(1) == slots_before,
		"cantrip spends no slot")

	# heal spell restores the caster
	liris.stats.current_hp = 20
	_level.cast_spell(spell_data.make_cure_wounds(), liris)
	_check(liris.stats.current_hp > 20, "heal spell restores the caster")
	_player.target_enemy = null

	# Liris's auto Healing Word — regression: passed the character SHEET as
	# the position source and crashed on Resource.global_position.
	var companion := _level.get_node("Characters/Liris") as CharacterBody3D
	var sarro = GameState.sarro
	var hp_low: int = maxi(1, int(sarro.stats.max_hp * 0.2))
	sarro.stats.current_hp = hp_low
	liris.healing_word_charges = maxi(1, liris.healing_word_charges)
	companion._heal_cooldown = 0.0
	companion._try_auto_heal()
	_check(sarro.stats.current_hp > hp_low, "Liris auto Healing Word heals Sarro without crashing")
	sarro.stats.current_hp = sarro.stats.max_hp

func _test_skirmisher_fires() -> void:
	var guard := _level.get_node("Enemies/PenGuard1") as CharacterBody3D
	_teleport_party(guard.global_position + Vector3(6.0, 0, 0))

	# targeting shows the gold ring at the enemy's feet; clearing hides it
	_player.target_enemy = guard
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_level._target_ring.visible and
		_level._target_ring.global_position.distance_to(guard.global_position) < 1.0,
		"target ring appears under the clicked enemy")
	_player.target_enemy = null
	await get_tree().process_frame
	_check(not _level._target_ring.visible, "target ring hides on deselect")
	var ok := await _wait_for_script_node(_ProjectileScript, 6.0)
	_check(ok, "skirmisher fired a projectile within 6s")

## Heavies moved to reach_rig in the Act 2 split — swap scenes for this one.
func _test_heavy_telegraphs() -> void:
	_level.queue_free()
	await get_tree().process_frame
	GameState.sarro = null
	GameState.liris = null
	_level = load("res://scenes/world/reach_rig.tscn").instantiate()
	add_child(_level)
	await get_tree().process_frame
	GameState.sarro.stats.max_hp = 900
	GameState.sarro.stats.current_hp = 900
	GameState.liris.stats.max_hp = 900
	GameState.liris.stats.current_hp = 900
	_player = _level.get_node("Characters/Sarro")
	var heavy := _level.get_node("Enemies/Enforcer1") as CharacterBody3D
	_teleport_party(heavy.global_position + Vector3(1.2, 0, 0))
	var ok := await _wait_for_script_node(_TelegraphScript, 8.0)
	_check(ok, "heavy showed a slam telegraph within 8s")

func _test_death_collapse() -> void:
	var guard := _level.get_node_or_null("Enemies/PenGuard2")
	if guard == null:
		_check(false, "PenGuard2 present for death test")
		return
	guard.receive_damage(9999, _player.global_position)
	_check(not guard.is_in_group("enemies"), "dead enemy leaves 'enemies' group immediately")
	_check(guard.collision_layer == 0, "dead enemy stops colliding immediately")
	await get_tree().create_timer(3.0).timeout
	_check(not is_instance_valid(guard), "corpse frees after death collapse")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _teleport_party(pos: Vector3) -> void:
	_player.global_position = pos
	var liris := _level.get_node("Characters/Liris") as CharacterBody3D
	liris.global_position = pos + Vector3(1.0, 0, 1.0)

## True if a node with the given script appears in the tree within `secs`.
func _wait_for_script_node(script: Script, secs: float) -> bool:
	var waited := 0.0
	while waited < secs:
		if _find_script_node(get_tree().root, script) != null:
			return true
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	return false

func _find_script_node(root: Node, script: Script) -> Node:
	if root.get_script() == script:
		return root
	for child in root.get_children():
		var found := _find_script_node(child, script)
		if found != null:
			return found
	return null

func _check(cond: bool, label: String) -> void:
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures.append(label)
