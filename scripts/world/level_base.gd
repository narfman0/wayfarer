## Base for all world levels. Expects the standard level scene skeleton:
##   Level/Props, Characters/Sarro, Characters/Liris, CameraPivot, HUD,
##   optional Enemies and portals (group "portals").
## Subclass for level-specific behavior via _on_level_ready().
class_name WayfarerLevel
extends Node3D

const _Factory       = preload("res://scripts/characters/character_factory.gd")
const _MeleeAttacker = preload("res://scripts/combat/melee_attacker.gd")
const _Scenery       = preload("res://scripts/world/scenery.gd")
const _Atmosphere    = preload("res://scripts/world/atmosphere.gd")
const _DamageNumber  = preload("res://scripts/world/damage_number.gd")
const _Dice          = preload("res://addons/srd/dice.gd")
const _Experience    = preload("res://addons/srd/systems/experience.gd")
const _Progression   = preload("res://scripts/characters/character_progression.gd")
const _CharAnim      = preload("res://scripts/world/character_animator.gd")
const _Juice         = preload("res://scripts/combat/juice.gd")
const _Vfx           = preload("res://scripts/combat/vfx.gd")
const _Maneuvers     = preload("res://scripts/combat/maneuvers.gd")
const _Platform      = preload("res://scripts/world/platform_terrain.gd")

## Seconds from cast gesture start to the effect landing (the gesture's
## apex). Spells read deliberately weightier than sword wind-ups.
const CAST_APEX := 0.4

## Key into SceneManager.LEVELS — also stored as GameState.current_plane.
@export var plane_id: String = "tamori"

## Half-size of the playable area in metres — used by _setup_bounds() to place
## invisible walls. Auto-detected from Level/Ground/GroundCollision if present
## (legacy flat BoxMesh levels); set explicitly for TiledTerrain levels.
@export var bounds_half_size: float = 40.0

## When this scene is run in isolation (no party in GameState — e.g. "Run
## Current Scene" in the editor), the fallback debug party is boosted to this
## level so late-game planes are actually testable. Ignored in normal play.
@export_range(1, 20) var debug_party_level: int = 1

## Generate procedural scenery on load (backdrop ring, ground-cover, grass,
## bushes, rocks). Off by default — place props manually in each scene instead.
## Set true to re-enable the procedural pass for a specific plane.
@export var generate_scenery: bool = false
## Replace the flat rectangular ground slab with an eroded plane-fragment
## platform (faint tactical grid on top, portal pads on causeways beyond
## the edge). Top stays flat at y=0 — gameplay untouched.
@export var platform_terrain: bool = false
## Move portals onto their causeway pads and open rail-guarded corridors
## through the boundary walls — leaving the plane means physically crossing
## a bridge. Requires platform_terrain.
@export var platform_walkable_pads: bool = false

## Corridor records for _setup_bounds: {side, at} per relocated portal.
var _pad_corridors: Array[Dictionary] = []

## True when this run spawned its own debug party — autosave is skipped so an
## isolated test never overwrites the real save slot.
var _debug_party := false

@onready var _player    = $Characters/Sarro     # PlayerController
@onready var _companion = $Characters/Liris     # CompanionFollow
@onready var _cam_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _hud_root:  Control = $HUD

var _hud = null       # HUD
var _attacker = null  # MeleeAttacker
var _target_ring: MeshInstance3D = null  # gold ring under the clicked enemy
var _outlined: Node3D = null                     # enemy carrying the outline overlay
var _outline_mat: StandardMaterial3D = null      # shared inverted-hull material

# ── Isometric camera ──────────────────────────────────────────────────────────
# Locked "game isometric" framing: pivot yawed 45°, camera pitched −30°,
# orthographic projection. The pivot follows the player each frame; the camera
# sits back along its own view axis far enough that near-plane clipping never
# bites (distance is irrelevant to ortho framing — only `size` is).
const _ISO_YAW   := deg_to_rad(45.0)
const _ISO_PITCH := deg_to_rad(-30.0)
const _ISO_DIST  := 30.0   # metres back along the view ray

# ── Dialogue camera ───────────────────────────────────────────────────────────
# During dialogue we tighten the orthographic size for a close-up and lift the
# focus to torso height; on dialogue end we ease back to the player's zoom.
# TODO: the old perspective camera also swung the yaw 28° for a 3/4 angle —
# that made no sense for a locked isometric view, so it was dropped.
const _CAM_DIALOGUE_ZOOM  := 0.5           # fraction of the resting ortho size
const _CAM_DIALOGUE_FOCUS := Vector3(0.0, 1.1, 0.0)  # pivot lift toward the torso
const _CAM_BLEND_SECS      := 0.7
var _cam_rest_pos: Vector3 = Vector3.ZERO  # resting Camera3D local position
var _cam_focus: Vector3 = Vector3.ZERO     # extra pivot offset (dialogue framing)
var _cam_tween: Tween = null
var _cam_attrs: CameraAttributesPractical = null

# ── Walk-around zoom ──────────────────────────────────────────────────────────
# Mouse wheel adjusts the orthographic size (clamped) instead of dollying.
# Ignored during dialogue so the two never fight; the dialogue camera returns
# to the player's chosen zoom when the conversation ends.
const _ZOOM_MIN  := 14.0
const _ZOOM_MAX  := 26.0
const _ZOOM_STEP := 2.0
var _zoom: float = 20.0    # current orthographic size
var _zoom_tween: Tween = null
var _dialogue_active := false

## Actions queued during pause; fired on resume.
var _queued_sarro: String = ""
var _queued_liris: String = ""

func _ready() -> void:
	_player.camera_pivot = _cam_pivot
	_companion.follow_target = _player
	_setup_isometric_camera()
	_cam_rest_pos = _camera.position
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_setup_hud()
	_sync_party_to_scene()
	GameState.travel_to(plane_id)
	AudioManager.play_ambient(plane_id)
	_setup_combat()
	_setup_enemies()
	_setup_prop_collision()
	_setup_platform()
	_setup_bounds()  # after platform swap so walls hug the eroded silhouette
	_setup_pathfinding()
	_apply_loaded_state()
	_setup_scenery()  # after _apply_loaded_state so avoid-points use final positions
	_setup_atmosphere()
	if not _debug_party:
		GameState.save_game()  # autosave on plane entry
	_on_level_ready()
	SceneManager.fade_in()

## Force the scene camera into the locked isometric framing regardless of how
## the .tscn positioned it (legacy scenes carry the old perspective transform).
func _setup_isometric_camera() -> void:
	_cam_pivot.rotation = Vector3(0.0, _ISO_YAW, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _zoom
	_camera.rotation = Vector3(_ISO_PITCH, 0.0, 0.0)
	_camera.position = Vector3(0.0, sin(-_ISO_PITCH) * _ISO_DIST, cos(_ISO_PITCH) * _ISO_DIST)
	_camera.near = 0.5
	_camera.far = 150.0
	# Tilt-shift DOF: focus band around the party (the camera sits _ISO_DIST
	# from the pivot), gentle blur past and before it — the isometric
	# "miniature diorama" read. Dialogue tightens it via _set_dof_strength.
	_cam_attrs = CameraAttributesPractical.new()
	_cam_attrs.dof_blur_far_enabled = true
	_cam_attrs.dof_blur_far_distance = _ISO_DIST + 16.0
	_cam_attrs.dof_blur_far_transition = 14.0
	_cam_attrs.dof_blur_near_enabled = true
	_cam_attrs.dof_blur_near_distance = _ISO_DIST - 14.0
	_cam_attrs.dof_blur_near_transition = 12.0
	_cam_attrs.dof_blur_amount = 0.05
	_camera.attributes = _cam_attrs

## Dialogue pulls focus: shallower field while talking, restored after.
func _set_dof_strength(amount: float) -> void:
	if _cam_attrs == null:
		return
	var tw := create_tween()
	tw.tween_property(_cam_attrs, "dof_blur_amount", amount, _CAM_BLEND_SECS)

## Override for level-specific setup (opening dialogue, triggers, ...).
func _on_level_ready() -> void:
	_player.set_control_enabled(true)

## World props ship as Synty GLTFs with no collision. Generate a trimesh
## collider per prop mesh at load so the player can't walk through them.
##
## Colliders go on a dedicated layer (not the ground/enemy layers), and the
## player is told to collide with it — but click-to-move's raycast (CLICK_MASK
## = ground + enemies) deliberately omits this layer, so clicking past a prop
## still targets the ground instead of stopping on the prop's surface.
##
## Trimesh (not a box) matters for tall props: the player capsule tops out at
## 1.8 m, so a tree only blocks at its trunk while its canopy — and any box
## drawn around it — would otherwise wall off the ground around it.
const _PROP_LAYER := 1 << 3  # value 8; unused by ground(1)/enemies(2)/companion(4)
## Boundary walls and pad rails: blocks bodies, invisible to click rays
## (CLICK_MASK = ground|enemies) — a 10 m wall must never eat an attack click.
const _BARRIER_LAYER := 1 << 4  # value 16
## Everything a moving body must collide with beyond its scene defaults:
## world props (trimesh) + boundary walls/rails. ONE constant so a new
## mover can't silently miss a layer again (enemies used to walk through
## trees because only the player's mask was extended).
const _MOVER_MASK_EXTRA := _PROP_LAYER | _BARRIER_LAYER

func _setup_prop_collision() -> void:
	var props := get_node_or_null("Level/Props")
	if props == null:
		return
	for mi: MeshInstance3D in props.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		mi.create_trimesh_collision()
		var body := _generated_static_body(mi)
		if body != null:
			body.collision_layer = _PROP_LAYER
			body.collision_mask = 0
	_player.collision_mask |= _MOVER_MASK_EXTRA
	_companion.collision_mask |= _MOVER_MASK_EXTRA

## The StaticBody3D that create_trimesh_collision() just parented under `mi`
## (Synty prop meshes carry no collision of their own, so it's the only one).
func _generated_static_body(mi: Node) -> StaticBody3D:
	for i in range(mi.get_child_count() - 1, -1, -1):
		if mi.get_child(i) is StaticBody3D:
			return mi.get_child(i)
	return null

## Create invisible wall colliders at each edge of the playable area.
## Size detection order: GroundCollision BoxShape3D → GroundMesh AABB (the
## legacy scenes pair a visual BoxMesh with an infinite WorldBoundaryShape3D,
## so the MESH is the real arena footprint — 36-56 m, not one default) →
## the exported bounds_half_size.
func _setup_bounds() -> void:
	var hx := bounds_half_size
	var hz := bounds_half_size
	var col_node := get_node_or_null("Level/Ground/GroundCollision") as CollisionShape3D
	var ground_mi := get_node_or_null("Level/Ground/GroundMesh") as MeshInstance3D
	if col_node != null and col_node.shape is BoxShape3D:
		var gs: Vector3 = (col_node.shape as BoxShape3D).size
		hx = gs.x * 0.5
		hz = gs.z * 0.5
	elif ground_mi != null and ground_mi.mesh != null:
		var ab := ground_mi.mesh.get_aabb()
		hx = ab.size.x * 0.5
		hz = ab.size.z * 0.5
	const H := 10.0   # wall height — well above any jump
	const T := 1.0    # wall thickness
	var level := get_node_or_null("Level")
	if level == null:
		return
	# Each side is a run along one axis at a fixed edge. Pad corridors split
	# the run and grow a rail-guarded pocket around their pad.
	for side_def in [
		["north", false, -1.0, hz, hx], ["south", false, 1.0, hz, hx],
		["west",  true,  -1.0, hx, hz], ["east",  true,  1.0, hx, hz],
	]:
		var side: String = side_def[0]
		var east_west: bool = side_def[1]   # wall run is along Z
		var s: float = side_def[2]
		var h: float = side_def[3]          # distance of wall from centre
		var run: float = side_def[4]        # half-length of the run
		var gaps: Array[float] = []
		for c in _pad_corridors:
			if c["side"] == side:
				gaps.append(c["at"])
		gaps.sort()
		# wall segments between gaps
		var cursor := -run - T
		var stops := gaps.duplicate()
		stops.append(run + T + 999.0)
		for at in stops:
			var seg_end: float = minf(at - _GAP_HALF, run + T)
			if seg_end > cursor:
				_add_wall(level, east_west, s * (h + T * 0.5),
					(cursor + seg_end) * 0.5, seg_end - cursor, H, T)
			cursor = at + _GAP_HALF
		# corridor pocket: rails along the causeway, ring around the pad
		for at in gaps:
			var pad_c := s * (h + _PAD_REACH)
			var pad_near := s * (h + _PAD_REACH - _PAD_HALF)
			var pad_far := s * (h + _PAD_REACH + _PAD_HALF)
			for u_sign in [-1.0, 1.0]:
				# causeway rail
				_add_wall_uw(level, east_west, at + u_sign * (_GAP_HALF + T * 0.5),
					(s * h + pad_near) * 0.5, T, absf(pad_near - s * h) + T, H)
				# pad side wall
				_add_wall_uw(level, east_west, at + u_sign * (_PAD_HALF + T * 0.5),
					pad_c, T, _PAD_SIZE + T * 2.0, H)
				# shoulder closing the L-corner at the pad's near edge
				var mid := (_GAP_HALF + _PAD_HALF) * 0.5
				_add_wall_uw(level, east_west, at + u_sign * mid,
					pad_near - s * T * 0.5, _PAD_HALF - _GAP_HALF + T, T, H)
			# far wall
			_add_wall_uw(level, east_west, at, pad_far + s * T * 0.5,
				_PAD_SIZE + T * 2.0, T, H)

## Wall box along a side run: u = coordinate along the run, w = fixed edge.
func _add_wall(level: Node, east_west: bool, w: float, u_center: float,
		u_len: float, height: float, thickness: float) -> void:
	_add_wall_uw(level, east_west, u_center, w, u_len, thickness, height)

## Wall box in run/out coordinates: east_west means the run axis is Z.
func _add_wall_uw(level: Node, east_west: bool, u: float, w: float,
		u_len: float, w_len: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = _BARRIER_LAYER
	body.collision_mask  = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w_len, height, u_len) if east_west else Vector3(u_len, height, w_len)
	shape_node.shape = shape
	shape_node.position = Vector3(w, height * 0.5, u) if east_west else Vector3(u, height * 0.5, w)
	body.add_child(shape_node)
	level.add_child(body)

## Feed the terrain height map to the player's AStarGrid2D so click-to-walk
## can route around cliffs and void. Levels that regenerate terrain later
## (DungeonRun) call _player.rebuild_pathfinding(map) again themselves.
func _setup_pathfinding() -> void:
	var terrain = get_node_or_null("Level/TiledTerrain")
	if terrain != null and terrain.has_method("active_map") \
			and _player.has_method("rebuild_pathfinding"):
		_player.rebuild_pathfinding(terrain.active_map())

func _setup_scenery() -> void:
	if not generate_scenery:
		return
	var level := get_node_or_null("Level")
	if level == null:
		return
	var ground := get_node_or_null("Level/Ground/GroundMesh") as MeshInstance3D
	_Scenery.generate(level, ground, _Scenery.avoid_points_for(self),
		_Scenery.clear_centers_for(self), plane_id)

## Swap the BoxMesh slab for the eroded platform + pads + causeways.
## Runs before _setup_bounds so the walls follow the new silhouette
## (erosion is inward-only, so players never walk past the visual edge).
func _setup_platform() -> void:
	if not platform_terrain:
		return
	var gm := get_node_or_null("Level/Ground/GroundMesh") as MeshInstance3D
	if gm == null or not (gm.mesh is BoxMesh):
		return
	var box: BoxMesh = gm.mesh
	var albedo := Color(0.3, 0.3, 0.32)
	var surf := gm.get_surface_override_material(0)
	if surf is StandardMaterial3D:
		albedo = (surf as StandardMaterial3D).albedo_color
	var style := _Platform.style_for(plane_id)
	var mat := _Platform.grid_material(albedo, style["color"], style["strength"])
	gm.mesh = _Platform.build_platform(box.size.x, box.size.z, hash(plane_id))
	gm.material_override = mat
	# The open double-sided shell would self-shadow its own top face into
	# uniform darkness; nothing sits below the platform to receive shadows
	# anyway, so casting is off (props still cast onto the platform).
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Portals get their own pads beyond the edge, joined by causeway prisms.
	# Walkable mode snaps each pad to the dominant axis, moves the portal
	# onto it, and records a corridor so _setup_bounds opens the wall there.
	var ground := get_node("Level/Ground")
	var hx: float = box.size.x * 0.5
	var hz: float = box.size.z * 0.5
	var idx := 0
	for child in get_node("Level").get_children():
		if not (child is Node3D) or child.get("target_plane") == null:
			continue
		var p: Vector3 = (child as Node3D).position
		if platform_walkable_pads:
			var east_west := absf(p.x) >= absf(p.z)
			var s := signf(p.x) if east_west else signf(p.z)
			var h := hx if east_west else hz
			var at := clampf(p.z if east_west else p.x,
				-(h - 6.0), h - 6.0)
			var pad_w := s * (h + _PAD_REACH)
			var pad_center := Vector3(pad_w, 0, at) if east_west else Vector3(at, 0, pad_w)
			var edge := Vector3(s * h, 0, at) if east_west else Vector3(at, 0, s * h)
			ground.add_child(_Platform.pad(pad_center, _PAD_SIZE, hash(plane_id) + idx, mat, true))
			ground.add_child(_Platform.causeway(edge - (edge - pad_center).normalized() * 0.5, pad_center, mat))
			(child as Node3D).position = Vector3(pad_center.x, p.y, pad_center.z)
			_pad_corridors.append({
				"side": ("east" if s > 0 else "west") if east_west else ("south" if s > 0 else "north"),
				"at": at,
			})
		else:
			var outward := Vector3(p.x, 0.0, p.z).normalized()
			var pad_center := p + outward * 7.0
			ground.add_child(_Platform.pad(pad_center, 7.0, hash(plane_id) + idx, mat))
			ground.add_child(_Platform.causeway(p + outward * 0.5, pad_center, mat))
		idx += 1

## Walkable-pad geometry (metres): corridor half-width, causeway length,
## pad footprint, and how far the pad centre sits beyond the wall.
const _GAP_HALF := 1.6
const _CAUSEWAY_LEN := 5.0
const _PAD_SIZE := 7.0
const _PAD_HALF := 3.5
const _PAD_REACH := 7.5   # CAUSEWAY_LEN + PAD_HALF - 1.0 overlap

func _setup_atmosphere() -> void:
	var ground := get_node_or_null("Level/Ground/GroundMesh") as MeshInstance3D
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	_Atmosphere.apply(self, plane_id, sun, ground)
	apply_graphics_tier()

## Scale the lighting stack to the persisted quality tier. Public so the
## pause menu can re-apply live when the player cycles the setting.
func apply_graphics_tier() -> void:
	var env: Environment = null
	for n in find_children("*", "WorldEnvironment", true, false):
		env = (n as WorldEnvironment).environment
		break
	Graphics.apply(get_viewport(), env, _cam_attrs)

# Animators are attached by each body's own controller in _ready()
# (PlayerController, CompanionFollow, EnemyController, NPC), which picks a more
# specific clip set than this node can — e.g. EnemyController uses the feminine
# set for witches and shades. A second level-side pass used to run here and
# double-applied CharacterAnimator's 180° skin spin, rendering everyone
# back-to-front; see CharacterAnimator.attach().

## Apply world state staged by GameState.load_game() or a portal transition.
func _apply_loaded_state() -> void:
	if GameState.pending_player_pos != null:
		_player.global_position = GameState.pending_player_pos
		GameState.pending_player_pos = null
	elif SceneManager.pending_spawn_id != "":
		for portal in get_tree().get_nodes_in_group("portals"):
			if portal.spawn_id == SceneManager.pending_spawn_id:
				_player.global_position = portal.spawn_position()
				_companion.global_position = portal.spawn_position() + Vector3(-1.2, 0, 1.2)
				break
		SceneManager.pending_spawn_id = ""

var _defeated := false

func _process(_delta: float) -> void:
	_cam_pivot.global_position = _player.global_position + _cam_focus
	_check_player_targeting()
	_update_target_ring(_delta)
	if GameState.sarro != null and GameState.sarro.shield_bash_cd > 0.0:
		GameState.sarro.shield_bash_cd = maxf(0.0, GameState.sarro.shield_bash_cd - _delta)
	if GameState.sarro != null and GameState.sarro.action_surge_cd > 0.0:
		GameState.sarro.action_surge_cd = maxf(0.0, GameState.sarro.action_surge_cd - _delta)
	if GameState.sarro != null and GameState.sarro.heavy_strike_cd > 0.0:
		GameState.sarro.heavy_strike_cd = maxf(0.0, GameState.sarro.heavy_strike_cd - _delta)
	if GameState.sarro != null:
		GameState.sarro.shove_cd = maxf(0.0, GameState.sarro.shove_cd - _delta)
		GameState.sarro.grapple_cd = maxf(0.0, GameState.sarro.grapple_cd - _delta)
		GameState.sarro.flavor_cd = maxf(0.0, GameState.sarro.flavor_cd - _delta)
	if not _defeated and GameState.sarro != null and GameState.sarro.stats.current_hp <= 0:
		_on_party_defeated()

## Sarro at 0 HP — show death overlay then let the player choose.
func _on_party_defeated() -> void:
	_defeated = true
	_player.set_control_enabled(false)
	if _attacker != null:
		_attacker.stop()
	CombatManager.exit_combat()
	print("[Combat] The Veil pulls you back...")
	_show_death_screen()

func _show_death_screen() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 300
	get_tree().current_scene.add_child(overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	var tw := get_tree().create_tween()
	tw.tween_property(backdrop, "color:a", 0.72, 0.8)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 20)
	panel.offset_left   = -200
	panel.offset_top    = -120
	panel.offset_right  =  200
	panel.offset_bottom =  120
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "You Fell..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.3, 0.25))
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "The Veil pulls you back."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.65, 0.55, 0.65))
	panel.add_child(sub)

	panel.add_child(HSeparator.new())

	var btn_retry := Button.new()
	btn_retry.text = "Try Again"
	btn_retry.custom_minimum_size = Vector2(180, 44)
	btn_retry.pressed.connect(func():
		overlay.queue_free()
		_respawn_party())
	panel.add_child(btn_retry)

	var btn_menu := Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.custom_minimum_size = Vector2(180, 44)
	btn_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	panel.add_child(btn_menu)

func _respawn_party() -> void:
	GameState.sarro.stats.current_hp = GameState.sarro.stats.max_hp
	if GameState.liris != null:
		GameState.liris.stats.current_hp = GameState.liris.stats.max_hp
	GameState.pending_player_pos = null
	SceneManager.change_level(plane_id)

## Ease the camera into the closer conversation framing (ortho size shrink).
func _on_dialogue_started(_resource) -> void:
	_dialogue_active = true
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_blend_camera(_zoom * _CAM_DIALOGUE_ZOOM, _CAM_DIALOGUE_FOCUS)
	_set_dof_strength(0.14)  # cinematic pull while talking

## Ease the camera back to the resting gameplay framing (at the zoom the
## player had dialed in before the conversation).
func _on_dialogue_ended(_resource) -> void:
	_dialogue_active = false
	_blend_camera(_zoom, Vector3.ZERO)
	_set_dof_strength(0.05)

func _blend_camera(cam_size: float, focus: Vector3) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_camera, "size", cam_size, _CAM_BLEND_SECS)
	_cam_tween.tween_property(self, "_cam_focus", focus, _CAM_BLEND_SECS)

func _setup_hud() -> void:
	var hud_scene := load("res://scenes/ui/hud.tscn")
	if hud_scene:
		_hud = hud_scene.instantiate()
		_hud_root.add_child(_hud)
	_setup_target_ring()

## The in-world half of targeting feedback: a slowly spinning gold ring at
## the clicked enemy's feet (the HUD row is the other half). Gold, so it
## never reads as a telegraph (orange) or a rest tear (green).
func _setup_target_ring() -> void:
	_target_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	_target_ring.mesh = torus
	_target_ring.scale.y = 0.18  # flatten onto the ground plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 1.8
	_target_ring.material_override = mat
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring.visible = false
	add_child(_target_ring)

func _update_target_ring(delta: float) -> void:
	if _target_ring == null:
		return
	var tgt = _player.target_enemy
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_in_group("enemies"):
		_target_ring.visible = false
		return
	_target_ring.visible = true
	_target_ring.global_position = tgt.global_position + Vector3(0, 0.08, 0)
	_target_ring.rotation.y += 1.6 * delta

func _setup_combat() -> void:
	_attacker = _MeleeAttacker.new()
	_attacker.owner_body = _player
	_attacker.character  = GameState.sarro
	_attacker.rate_scale = _Progression.base_rate_scale(GameState.sarro)
	_player.speed_mult = _Progression.speed_multiplier(GameState.sarro)
	add_child(_attacker)
	var liris_attacker = _MeleeAttacker.new()
	liris_attacker.owner_body = _companion
	liris_attacker.character  = GameState.liris
	add_child(liris_attacker)
	_companion.attacker = liris_attacker


func _setup_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var ec = enemy if enemy.get_script() != null and enemy.has_method("receive_damage") else null
		if ec == null:
			continue
		register_enemy(ec)

## Give an enemy everything a scene enemy gets at level load: its factory
## character sheet and death/phase wiring. Dynamic spawners (DungeonRun)
## MUST call this for enemies created after _ready, or they walk around as
## sheetless shells that can never attack.
func register_enemy(ec) -> void:
	if ec.character != null:
		return
	ec.character = _Factory.make_enemy(ec.enemy_type)
	ec.collision_mask |= _MOVER_MASK_EXTRA
	ec.died.connect(_on_enemy_died.bind(ec))
	if ec.is_boss:
		ec.phase_changed.connect(_on_boss_phase.bind(ec))

## Inverted-hull outline: gold while targeted, red when the attack loop is
## in range and landing — the "who will my attack impact" read.
func _update_target_outline(tgt: Node3D) -> void:
	if _outlined != tgt:
		if _outlined != null and is_instance_valid(_outlined):
			_set_skin_overlay(_outlined, null)
		_outlined = tgt
		if tgt != null:
			if _outline_mat == null:
				_outline_mat = StandardMaterial3D.new()
				_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
				_outline_mat.grow = true
				_outline_mat.grow_amount = 0.035
			_set_skin_overlay(tgt, _outline_mat)
	if tgt != null and _outline_mat != null:
		var in_range: bool = _attacker != null and _attacker.is_attacking(tgt)
		_outline_mat.albedo_color = Color(1.0, 0.25, 0.15) if in_range else Color(1.0, 0.82, 0.3)

func _set_skin_overlay(enemy: Node3D, mat: Material) -> void:
	var skin := enemy.get_node_or_null("Skin")
	if skin == null:
		return
	for mi: MeshInstance3D in skin.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = mat

func _check_player_targeting() -> void:
	var tgt = _player.target_enemy
	_update_target_outline(tgt if tgt != null and tgt.has_method("receive_damage") else null)
	if tgt == null:
		return
	var ec = tgt if tgt != null and tgt.has_method("receive_damage") else null
	if ec == null:
		return
	if _hud != null:
		_hud.track_enemy(ec)
	var dist: float = _player.global_position.distance_to(ec.global_position)
	if dist <= 1.6:
		if not _attacker.is_attacking(ec):
			_attacker.start(ec)

func _on_enemy_died(ec) -> void:
	if _attacker != null:
		_attacker.stop()
	_player.target_enemy = null
	if _hud != null:
		_hud.track_enemy(null)
	print("[Combat] Enemy defeated!")
	# Check if all enemies are now dead
	var remaining := get_tree().get_nodes_in_group("enemies").filter(
		func(e): return e.has_method("receive_damage") and (e.character == null or e.character.stats.current_hp > 0))
	if remaining.is_empty() and CombatManager.in_combat:
		_on_encounter_won()

func _on_encounter_won() -> void:
	CombatManager.exit_combat()
	if _hud != null:
		_hud.show_encounter_result(true)
	# Grant XP for the encounter (sum of enemy XP values)
	var total_xp := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("receive_damage") and enemy.character != null:
			total_xp += _Experience.xp_for_level(enemy.character.stats.level) / 4
	if total_xp > 0:
		GameState.grant_xp(total_xp)
	print("[Combat] Encounter won! +%d XP" % total_xp)

func _on_boss_phase(phase: int, _ec) -> void:
	if _hud != null:
		_hud.show_boss_phase(phase)

func _sync_party_to_scene() -> void:
	if GameState.sarro == null:
		_debug_party = true
		GameState.debug_session = true
		GameState.set_party(_Factory.make_sarro(), _Factory.make_liris())
		if debug_party_level > 1:
			GameState.grant_xp(_Experience.xp_for_level(debug_party_level))
		# Debug parties spend their build choices deterministically so
		# isolated scene runs and harnesses never stall on pending state.
		_Progression.auto_resolve(GameState.sarro)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()
	elif event.is_action_pressed("ability_1"):
		_use_second_wind()
	elif event.is_action_pressed("ability_2"):
		_use_guiding_bolt()
	elif event.is_action_pressed("ability_3"):
		_use_healing_word()
	elif event.is_action_pressed("ability_4"):
		_use_channel_divinity()
	elif event.is_action_pressed("ability_5"):
		_use_shield_bash()
	elif event.is_action_pressed("ability_6"):
		_use_action_surge()
	elif event.is_action_pressed("ability_7"):
		_use_heavy_strike()
	elif event.is_action_pressed("ability_8"):
		_use_shove()
	elif event.is_action_pressed("ability_9"):
		_use_grapple()
	elif event.is_action_pressed("ability_10"):
		_use_class_flavor()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(-_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(_ZOOM_STEP)

func _adjust_zoom(step: float) -> void:
	if _dialogue_active:
		return
	var target := clampf(_zoom + step, _ZOOM_MIN, _ZOOM_MAX)
	if is_equal_approx(target, _zoom):
		return
	_zoom = target
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_camera, "size", _zoom, 0.18)

# ── Sarro Abilities ───────────────────────────────────────────────────────────

## [Q] Heavy Strike — prime the next swing: +2d6 damage and a stagger.
## Sarro's baseline level-1 active; the cooldown starts when the swing lands.
func _use_heavy_strike() -> void:
	var c = GameState.sarro
	if c == null or _defeated or c.heavy_strike_primed or c.heavy_strike_cd > 0.0:
		return
	c.heavy_strike_primed = true
	AudioManager.play_sfx("telegraph", -6.0)
	_Vfx.buff_flare(self, _player.global_position, Color(1.0, 0.6, 0.25))
	_DamageNumber.spawn(self, _player.global_position + Vector3(0, 2.0, 0),
		"HEAVY STRIKE", Color(1.0, 0.6, 0.25))
	print("[Combat] Heavy Strike primed")

# ── Maneuvers (any player character) ─────────────────────────────────────────

## The current melee-range target, or null (maneuvers need your hands on them).
func _maneuver_target(reach := 2.2) -> Node3D:
	var tgt = _player.target_enemy
	if tgt == null or not tgt.has_method("receive_damage"):
		return null
	if _player.global_position.distance_to(tgt.global_position) > reach:
		_DamageNumber.spawn(self, _player.global_position + Vector3(0, 2, 0),
			"Too far!", Color(1.0, 0.5, 0.3))
		return null
	return tgt

## [E] Shove — contested STR vs STR: knock the target away (edges are fair
## game). The bread-and-butter forced-movement maneuver.
func _use_shove() -> void:
	var c = GameState.sarro
	if c == null or _defeated or c.shove_cd > 0.0:
		return
	var tgt := _maneuver_target()
	if tgt == null:
		return
	c.shove_cd = _Maneuvers.SHOVE_CD
	_CharAnim.oneshot(_player, "attack", 2.2, 0.6)
	if not _Maneuvers.contest(c, tgt.character, 0, 0):
		_Maneuvers.feedback(self, tgt.global_position, "resisted", Color(0.75, 0.75, 0.8))
		return
	_Maneuvers.apply_shove(self, tgt, _player.global_position)

## [G] Grapple — contested STR vs STR: hold the target in place. They get one
## escape attempt halfway through; bosses shrug it off.
func _use_grapple() -> void:
	var c = GameState.sarro
	if c == null or _defeated or c.grapple_cd > 0.0:
		return
	var tgt := _maneuver_target()
	if tgt == null:
		return
	c.grapple_cd = _Maneuvers.GRAPPLE_CD
	if _Maneuvers.resists(tgt):
		_Maneuvers.feedback(self, tgt.global_position, "RESISTED", Color(0.8, 0.8, 0.85))
		return
	if not _Maneuvers.contest(c, tgt.character, 0, 0):
		_Maneuvers.feedback(self, tgt.global_position, "slipped free", Color(0.75, 0.75, 0.8))
		return
	tgt.root(_Maneuvers.GRAPPLE_HOLD)
	_Maneuvers.feedback(self, tgt.global_position, "GRAPPLED", Color(1.0, 0.85, 0.4))
	# one escape attempt at the midpoint
	get_tree().create_timer(_Maneuvers.GRAPPLE_HOLD * 0.5).timeout.connect(func() -> void:
		if tgt == null or not is_instance_valid(tgt) or not tgt.is_rooted():
			return
		if _Maneuvers.contest(tgt.character, GameState.sarro, 0, 0):
			tgt.break_root()
			_Maneuvers.feedback(self, tgt.global_position, "breaks free!", Color(0.9, 0.7, 0.5)))

## [R] Class flavor — Soldier Trip / Ghost Feint / Warden Ward / Psion Repel.
func _use_class_flavor() -> void:
	var c = GameState.sarro
	if c == null or _defeated or c.flavor_cd > 0.0:
		return
	var cls := ""
	if c.class_data != null:
		cls = String(c.class_data.class_name_str).to_lower()
	match cls:
		"ghost":
			c.flavor_cd = _Maneuvers.FLAVOR_CD
			c.riposte_until_ms = Time.get_ticks_msec() + 3000
			_Vfx.buff_flare(self, _player.global_position, Color(0.7, 0.75, 0.95))
			_Maneuvers.feedback(self, _player.global_position, "FEINT", Color(0.7, 0.75, 0.95))
		"warden":
			c.flavor_cd = _Maneuvers.FLAVOR_CD
			c.ward_hp = 8 + c.stats.level
			_Vfx.buff_flare(self, _player.global_position, Color(0.5, 0.8, 1.0))
			_Maneuvers.feedback(self, _player.global_position, "WARD %d" % c.ward_hp, Color(0.5, 0.8, 1.0))
		"psion":
			c.flavor_cd = _Maneuvers.FLAVOR_CD
			_Vfx.buff_flare(self, _player.global_position, Color(0.8, 0.55, 1.0))
			var pushed := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and e.has_method("receive_damage") \
						and _player.global_position.distance_to(e.global_position) <= 4.5:
					if _Maneuvers.apply_shove(self, e, _player.global_position):
						pushed += 1
			_Maneuvers.feedback(self, _player.global_position, "REPEL ×%d" % pushed, Color(0.8, 0.55, 1.0))
		_:  # soldier and everyone else: Trip
			var tgt := _maneuver_target()
			if tgt == null:
				return
			c.flavor_cd = _Maneuvers.FLAVOR_CD
			_CharAnim.oneshot(_player, "attack", 2.2, 0.6)
			if _Maneuvers.resists(tgt):
				_Maneuvers.feedback(self, tgt.global_position, "RESISTED", Color(0.8, 0.8, 0.85))
				return
			if not _Maneuvers.contest(c, tgt.character, 0, 1):  # STR vs DEX
				_Maneuvers.feedback(self, tgt.global_position, "kept footing", Color(0.75, 0.75, 0.8))
				return
			tgt.stun(_Maneuvers.TRIP_PRONE)
			_Maneuvers.feedback(self, tgt.global_position, "TRIPPED", Color(1.0, 0.7, 0.3))

## [1] Second Wind: heal 1d10 + level, once per rest. (Bonus action in TB.)
func _use_second_wind() -> void:
	var c = GameState.sarro
	if c == null or c.second_wind_used or _defeated:
		return
	if c.stats.current_hp >= c.stats.max_hp or c.stats.current_hp <= 0:
		return
	c.second_wind_used = true
	var heal: int = _Dice.roll(10) + c.stats.level
	c.stats.current_hp = mini(c.stats.max_hp, c.stats.current_hp + heal)
	_Vfx.heal_aura(self, _player.global_position)
	_DamageNumber.spawn(self, _player.global_position, "+%d" % heal, Color(0.4, 1.0, 0.5))
	print("[Combat] Second Wind: +%d HP" % heal)

## [6] Action Surge — Sarro pushes past his limit (unlocked at level 2):
## attacks land twice as fast for 6 s. Once per rest — unless he's a
## Freeblade (Surge Mastery): then it recharges on a short cooldown.
const _ACTION_SURGE_SECS := 6.0
const _SURGE_MASTERY_CD := 8.0

func _use_action_surge() -> void:
	var c = GameState.sarro
	if c == null or _defeated or c.stats.level < 2:
		return
	if c.subclass_key == "freeblade":
		if c.action_surge_cd > 0.0:
			return
		c.action_surge_cd = _SURGE_MASTERY_CD + _ACTION_SURGE_SECS
	else:
		if c.action_surge_used:
			return
		c.action_surge_used = true
	var base: float = _Progression.base_rate_scale(c)
	_attacker.rate_scale = base * 0.5
	AudioManager.play_sfx("crit", 0.0)
	_Vfx.buff_flare(self, _player.global_position, Color(1.0, 0.8, 0.2))
	_DamageNumber.spawn(self, _player.global_position + Vector3(0, 2.0, 0),
		"ACTION SURGE!", Color(1.0, 0.8, 0.2))
	print("[Combat] Action Surge: attack speed doubled for %.0fs" % _ACTION_SURGE_SECS)
	get_tree().create_timer(_ACTION_SURGE_SECS).timeout.connect(func():
		if _attacker != null and GameState.sarro != null:
			_attacker.rate_scale = _Progression.base_rate_scale(GameState.sarro))

## [5] Shield Bash — Sarro's interrupt (unlocked at level 3). Slam the current
## target: cancels a channeled cast (long punish stun) or briefly staggers a
## non-casting enemy. 8 s cooldown, melee range.
const _SHIELD_BASH_CD := 8.0
const _SHIELD_BASH_RANGE := 2.5

func _use_shield_bash() -> void:
	var c = GameState.sarro
	if c == null or c.shield_bash_cd > 0.0 or _defeated or c.stats.level < 3:
		return
	var tgt = _player.target_enemy
	if tgt == null or not tgt.has_method("interrupt_cast"):
		return
	if _player.global_position.distance_to(tgt.global_position) > _SHIELD_BASH_RANGE:
		return
	c.shield_bash_cd = _SHIELD_BASH_CD
	_MeleeAttacker.lunge(_player, tgt.global_position)
	AudioManager.play_sfx("hit", 1.0)
	if tgt.is_casting():
		tgt.interrupt_cast(2.5)
		_DamageNumber.spawn(self, tgt.global_position + Vector3(0, 2.0, 0),
			"INTERRUPTED!", Color(1.0, 0.55, 0.15))
		print("[Combat] Shield Bash interrupts %s" % tgt.name)
	else:
		tgt.stun(1.0)
		_DamageNumber.spawn(self, tgt.global_position + Vector3(0, 2.0, 0),
			"Bash", Color(0.9, 0.8, 0.5))

# ── Liris Abilities ───────────────────────────────────────────────────────────

## [2] Guiding Bolt: mark the current target so the next attack hits with advantage. (Action in TB.)
func _use_guiding_bolt() -> void:
	var c = GameState.liris
	if c == null or not c.guiding_bolt_ready or _defeated:
		return
	var tgt = _player.target_enemy
	if tgt == null or not tgt.has_method("receive_damage"):
		return
	c.guiding_bolt_ready = false
	tgt.guiding_bolt_active = true
	_DamageNumber.spawn(self, tgt.global_position + Vector3(0, 1.5, 0),
		"Guiding Bolt!", Color(0.95, 0.85, 0.3))
	print("[Spell] Liris: Guiding Bolt on %s" % tgt.name)

## [3] Healing Word: heal Sarro for 1d4 + WIS mod (short-rest charge). (Bonus action in TB.)
func _use_healing_word() -> void:
	var c = GameState.liris
	var sarro = GameState.sarro
	if c == null or sarro == null or c.healing_word_charges <= 0 or _defeated:
		return
	if sarro.stats.current_hp <= 0:
		return
	c.healing_word_charges -= 1
	var heal: int = maxi(1, _Dice.roll(4) + c.stats.ability_modifier(4))  # 4 = WIS
	sarro.stats.current_hp = mini(sarro.stats.max_hp, sarro.stats.current_hp + heal)
	_Vfx.heal_aura(self, _player.global_position)
	_DamageNumber.spawn(self, _player.global_position + Vector3(0, 1.5, 0),
		"+%d HW" % heal, Color(0.4, 1.0, 0.5))
	print("[Spell] Liris: Healing Word — Sarro +%d HP" % heal)

## [4] Channel Divinity — Sacred Flame burst on all enemies within 8 m of Liris. (Action in TB.)
func _use_channel_divinity() -> void:
	var c = GameState.liris
	if c == null or not c.channel_divinity_ready or _defeated:
		return
	c.channel_divinity_ready = false
	_CharAnim.oneshot(_companion, "cast_raise", 1.2, 0.8)  # arms-raised invocation
	var dc: int = 8 + c.stats.ability_modifier(4) + c.stats.proficiency_bonus()
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or not enemy.has_method("receive_damage"):
			continue
		var dist: float = _companion.global_position.distance_to(enemy.global_position)
		if dist > 8.0:
			continue
		var save_roll: int = _Dice.roll_d20()
		if enemy.character != null:
			save_roll += enemy.character.stats.ability_modifier(1)  # 1 = DEX
		if save_roll < dc:
			var dmg: int = _Dice.roll(8)
			enemy.receive_damage(dmg)
			_DamageNumber.hit(self, enemy.global_position, dmg, false)
			hit_count += 1
	_DamageNumber.spawn(self, _companion.global_position + Vector3(0, 2.0, 0),
		"Sacred Flame ×%d" % hit_count, Color(0.95, 0.85, 0.3))
	print("[Spell] Liris: Channel Divinity — %d enemies hit (DC %d)" % [hit_count, dc])

# ── Spell casting ────────────────────────────────────────────────────────────

## Public entry point for the skill bar (AbilityRegistry spell slots call
## this on the current scene). `caster` defaults to Sarro; Liris's known
## spells pass her explicitly.
func cast_spell(spell, caster = null) -> void:
	_cast_spell(spell, caster)

func _cast_spell(spell, caster = null) -> void:
	var c = caster if caster != null else GameState.sarro
	if c == null or _defeated:
		return
	# The body performing the gesture (spells belong to a sheet, not a node).
	var caster_body: Node3D = _companion if c == GameState.liris else _player

	# Damage spell — needs a target
	if spell.damage_dice > 0:
		var tgt = _player.target_enemy
		if tgt == null or not tgt.has_method("receive_damage"):
			_DamageNumber.spawn(self, _player.global_position + Vector3(0, 2, 0),
				"Select a target first!", Color(1.0, 0.5, 0.3))
			return
		var dmg: int = 0
		for _i in spell.damage_count:
			dmg += _Dice.roll(spell.damage_dice)
		# Point at the apex, then a bolt FLIES to the target and damage lands
		# on arrival. Deliberately weightier than a sword wind-up.
		_CharAnim.oneshot(caster_body, "cast_bolt", 1.4, 0.8)
		get_tree().create_timer(CAST_APEX).timeout.connect(func() -> void:
			if tgt == null or not is_instance_valid(tgt) or tgt.character == null \
					or tgt.character.stats.current_hp <= 0:
				return  # target fell during the cast — the bolt fizzles
			var from: Vector3 = caster_body.global_position if is_instance_valid(caster_body) \
				else _player.global_position
			_Vfx.spell_bolt(self, from, tgt.global_position, Color(0.7, 0.65, 1.0),
				func() -> void:
					if tgt == null or not is_instance_valid(tgt) or tgt.character == null \
							or tgt.character.stats.current_hp <= 0:
						return
					tgt.receive_damage(dmg)
					_DamageNumber.hit(self, tgt.global_position, dmg, false)
					_DamageNumber.spawn(self, tgt.global_position + Vector3(0, 2.0, 0),
						spell.spell_name, Color(0.7, 0.7, 1.0))
					print("[Spell] %s → %s: %d dmg" % [spell.spell_name, tgt.name, dmg])))

	# Heal spell — restores the caster
	elif spell.heal_dice > 0:
		var heal: int = 0
		for _i in spell.heal_count:
			heal += _Dice.roll(spell.heal_dice)
		heal += c.stats.ability_modifier(4)  # WIS
		_CharAnim.oneshot(caster_body, "cast_heal", 1.4, 0.8)
		get_tree().create_timer(CAST_APEX).timeout.connect(func() -> void:
			c.stats.current_hp = mini(c.stats.max_hp, c.stats.current_hp + heal)
			var at: Vector3 = caster_body.global_position if is_instance_valid(caster_body) \
				else _player.global_position
			_Juice.flash_light(self, at, Color(0.45, 1.0, 0.55), 2.0, 0.4)
			_Vfx.heal_aura(self, at)
			_DamageNumber.spawn(self, at + Vector3(0, 1.5, 0),
				"+%d %s" % [heal, spell.spell_name], Color(0.4, 1.0, 0.5))
			print("[Spell] %s: +%d HP to %s" % [spell.spell_name, heal, c.display_name]))

	# Buff / utility — arms raised, announce at the apex
	else:
		_CharAnim.oneshot(caster_body, "cast_raise", 1.4, 0.8)
		get_tree().create_timer(CAST_APEX).timeout.connect(func() -> void:
			var at: Vector3 = caster_body.global_position if is_instance_valid(caster_body) \
				else _player.global_position
			_Juice.flash_light(self, at, Color(0.75, 0.6, 1.0), 2.0, 0.4)
			_Vfx.buff_flare(self, at, Color(0.75, 0.6, 1.0))
			_DamageNumber.spawn(self, at + Vector3(0, 2.0, 0),
				spell.spell_name, Color(0.85, 0.75, 1.0))
			print("[Spell] %s cast" % spell.spell_name))

	# Slot + action economy spend stays at cast time (only the effect waits).
	if spell.spell_level > 0 and c.energy_slots != null:
		c.energy_slots.use_slot(spell.spell_level)

# ── Pause / queue ─────────────────────────────────────────────────────────────

func _open_pause_menu() -> void:
	get_tree().paused = true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		var pm = pause_scene.instantiate()
		pm.queued.connect(_on_actions_queued)
		add_child(pm)

func _on_actions_queued(sarro_action: String, liris_action: String) -> void:
	_queued_sarro = sarro_action
	_queued_liris = liris_action
	_execute_queued_actions()

func _execute_queued_actions() -> void:
	match _queued_sarro:
		"ability_1": _use_second_wind()
	_queued_sarro = ""
	match _queued_liris:
		"ability_2": _use_guiding_bolt()
		"ability_3": _use_healing_word()
		"ability_4": _use_channel_divinity()
	_queued_liris = ""
