## Combat VFX library — every effect is a fire-and-forget static that builds
## its nodes in code, plays, and frees itself. Sits above juice.gd (which owns
## hit-stop/shake/impact sparks/lights); this file owns the readable shapes:
## slash arcs, flying spell bolts, heal auras, buff flares, death dissolves.
## All effects position via global coordinates after entering the tree.
class_name Vfx
extends RefCounted

# ── Slash arc ─────────────────────────────────────────────────────────────────

## A crescent slash that sweeps from `from_pos` toward `to_pos` and fades.
## Reads as the blade's wake; spawned at swing start so it leads the contact.
static func slash_arc(scene: Node, from_pos: Vector3, to_pos: Vector3,
		color := Color(1.0, 0.95, 0.8), heavy := false) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var dir := to_pos - from_pos
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	var reach := 1.5 if heavy else 1.15
	torus.inner_radius = reach * 0.72
	torus.outer_radius = reach
	torus.rings = 24
	torus.ring_segments = 8
	mi.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
	mi.global_position = from_pos + Vector3(0, 1.1, 0) + dir * 0.35
	# Lay the arc flat-ish, faced along the swing, slightly tilted into it.
	mi.rotation.y = atan2(-dir.x, -dir.z)
	mi.rotation.x = deg_to_rad(64.0)
	mi.scale = Vector3(0.4, 0.4, 0.4)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", mi.rotation.y + (0.9 if not heavy else 1.3), 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18).set_delay(0.06)
	tw.chain().tween_callback(mi.queue_free)

# ── Spell bolt ────────────────────────────────────────────────────────────────

## A glowing bolt that flies from caster to target, trailing motes, and calls
## `on_arrive` when it lands (the caller applies damage there). Flight time is
## distance-scaled but short — spells stay snappy.
static func spell_bolt(scene: Node, from_pos: Vector3, to_pos: Vector3,
		color := Color(0.95, 0.85, 0.4), on_arrive := Callable()) -> void:
	if scene == null or not scene.is_inside_tree():
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var bolt := Node3D.new()
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 10
	sphere.rings = 5
	core.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 3.5
	sphere.material = mat
	bolt.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(color.r, color.g, color.b)
	light.light_energy = 1.6
	light.omni_range = 3.5
	light.shadow_enabled = false
	bolt.add_child(light)
	var trail := CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.direction = Vector3.ZERO
	trail.spread = 180.0
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.5
	trail.scale_amount_min = 0.4
	trail.scale_amount_max = 1.0
	var tm := SphereMesh.new()
	tm.radius = 0.05
	tm.height = 0.1
	tm.radial_segments = 6
	tm.rings = 3
	tm.material = mat
	trail.mesh = tm
	bolt.add_child(trail)
	scene.add_child(bolt)
	var start := from_pos + Vector3(0, 1.4, 0)
	var end := to_pos + Vector3(0, 1.0, 0)
	bolt.global_position = start
	var flight := clampf(start.distance_to(end) / 22.0, 0.12, 0.4)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "global_position", end, flight) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if on_arrive.is_valid():
			on_arrive.call()
		var burst := scene.get_tree() if scene.is_inside_tree() else null
		if burst != null:
			_arrival_burst(scene, end, color)
		bolt.queue_free())

static func _arrival_burst(scene: Node, pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.direction = Vector3.ZERO
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	scene.get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())

# ── Heal aura ─────────────────────────────────────────────────────────────────

## Soft rising motes + an expanding ground ring — mending flowing upward.
static func heal_aura(scene: Node, pos: Vector3, color := Color(0.45, 1.0, 0.55)) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.9
	p.explosiveness = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.55
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.2
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos + Vector3(0, 0.4, 0)
	p.emitting = true
	_ground_ring(scene, pos, color, 1.4)
	scene.get_tree().create_timer(1.3).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())

## Expanding, fading ring on the ground — shared by heals and buffs.
static func _ground_ring(scene: Node, pos: Vector3, color: Color, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	mi.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.12, 0)
	mi.scale = Vector3(0.2, 0.06, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.06, radius), 0.45) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)

# ── Buff flare ────────────────────────────────────────────────────────────────

## Quick upward flare + ring for self-buffs (Action Surge, Heavy Strike prime,
## Second Wind). Color carries the identity.
static func buff_flare(scene: Node, pos: Vector3, color := Color(1.0, 0.8, 0.2)) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	_ground_ring(scene, pos, color, 1.1)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.22, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.6
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos + Vector3(0, 0.6, 0)
	p.emitting = true
	scene.get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())

# ── Death dissolve ────────────────────────────────────────────────────────────

## Dark motes pulled upward — the Veil tugging the fallen through. Plays
## alongside the corpse collapse.
static func death_dissolve(scene: Node, pos: Vector3,
		color := Color(0.45, 0.3, 0.7)) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 26
	p.lifetime = 1.4
	p.explosiveness = 0.35
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 1.6, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.9
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 1.8
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos + Vector3(0, 0.8, 0)
	p.emitting = true
	scene.get_tree().create_timer(1.8).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())
