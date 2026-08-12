## Combat game-feel helpers: hit-stop, camera shake, impact particles, death
## collapse. All static, all safe to call headless (plain nodes + tweens, no
## rendering-server reads).
class_name Juice
extends RefCounted

static var _hit_stop_active := false

## Freeze the action for a beat on a meaty connect. Real-time timer restores
## the clock, and re-entrant calls are ignored so overlapping hits can't stack
## slowdowns or strand time_scale low.
static func hit_stop(tree: SceneTree, secs := 0.05, time_scale := 0.05) -> void:
	if _hit_stop_active or tree == null:
		return
	_hit_stop_active = true
	Engine.time_scale = time_scale
	await tree.create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false

## Brief camera jitter (crits, heavy slams). Uses h/v_offset so it never
## fights the dialogue-camera tweens that own the camera's transform.
static func shake(camera: Camera3D, strength := 0.12, secs := 0.16) -> void:
	if camera == null:
		return
	var tween := camera.create_tween()
	var steps := 4
	for i in steps:
		var falloff := strength * (1.0 - float(i) / steps)
		tween.tween_property(camera, "h_offset",
			randf_range(-falloff, falloff), secs / (steps * 2.0))
		tween.tween_property(camera, "v_offset",
			randf_range(-falloff, falloff), secs / (steps * 2.0))
	tween.tween_property(camera, "h_offset", 0.0, secs / (steps * 2.0))
	tween.tween_property(camera, "v_offset", 0.0, secs / (steps * 2.0))

## Transient shadowless point light — impacts and spell apexes emit light.
## Dozens can run per fight; each frees itself after the fade.
static func flash_light(scene: Node, pos: Vector3, color := Color(1.0, 0.8, 0.5),
		energy := 2.4, secs := 0.25) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = Color(color.r, color.g, color.b)
	l.light_energy = energy
	l.omni_range = 4.5
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	scene.add_child(l)
	l.global_position = pos + Vector3(0, 1.2, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, secs).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)

## One-shot spark burst at a hit point.
static func impact_burst(scene: Node, pos: Vector3,
		color := Color(1.0, 0.75, 0.4)) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	flash_light(scene, pos, color)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.32
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos + Vector3(0, 1.0, 0)
	p.emitting = true
	scene.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(
		func():
			if is_instance_valid(p):
				p.queue_free())

## Fall over, linger a beat, sink through the ground, free. The body must be
## made inert (groups/collision/processing) by its controller BEFORE calling —
## this only owns the send-off. Replaces queue_free()-mid-swing disappearance.
static func death_collapse(body: CharacterBody3D, has_death_anim := false) -> void:
	var skin := body.get_node_or_null("Skin") as Node3D
	var tween := body.create_tween()
	if skin != null and not has_death_anim:
		# procedural fall — only when no real death clip is playing
		tween.tween_property(skin, "rotation:x", -PI / 2.0, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.6 if has_death_anim else 0.8)
	tween.tween_property(body, "position:y", body.position.y - 1.6, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(body.queue_free)
