@tool
## The Veil tear — the game's one recurring motif, so it looks like ONE thing
## everywhere: a slowly-turning ring around an inner distortion disc, drifting
## motes, a soft light, a low hum. Portals, rest points, story tears, and
## Cael's apparatus all reuse this at different scales/colors instead of
## hand-rolling emissive tori.
##
## Builds itself in _ready from exports, so scenes can attach this script to a
## bare Node3D, and code can `VeilTear.new()` + set exports before adding.
class_name VeilTear
extends Node3D

@export var color: Color = Color(0.55, 0.35, 1.0)
@export var ring_radius: float = 1.0
## 0..1 — mote count and spin speed scale with it (rest points are calm).
@export var intensity: float = 1.0
@export var hum: bool = true

var _ring: MeshInstance3D

func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = ring_radius * 0.82
	torus.outer_radius = ring_radius
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.rotation_degrees.x = 90.0
	_ring.material_override = _emissive(color, 2.2)
	add_child(_ring)

	var disc := CylinderMesh.new()
	disc.top_radius = ring_radius * 0.8
	disc.bottom_radius = ring_radius * 0.8
	disc.height = 0.02
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc
	disc_mi.rotation_degrees.x = 90.0
	var disc_mat := _emissive(Color(color.r, color.g, color.b, 0.35), 0.8)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mi.material_override = disc_mat
	add_child(disc_mi)

	var motes := CPUParticles3D.new()
	motes.amount = int(10 + 14 * intensity)
	motes.lifetime = 3.0
	motes.preprocess = 3.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = ring_radius * 1.1
	motes.direction = Vector3.ZERO
	motes.spread = 180.0
	motes.gravity = Vector3(0, 0.25 * intensity, 0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.2 * maxf(0.3, intensity)
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.025
	mote_mesh.height = 0.05
	mote_mesh.radial_segments = 6
	mote_mesh.rings = 3
	mote_mesh.material = _emissive(color, 2.5)
	motes.mesh = mote_mesh
	add_child(motes)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.9 * intensity
	light.omni_range = ring_radius * 4.0
	add_child(light)

	if hum and not Engine.is_editor_hint():
		var stream := load("res://assets/audio/veil_hum.wav")
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / 2
			var p := AudioStreamPlayer3D.new()
			p.stream = stream
			p.volume_db = -16.0
			p.max_distance = 12.0
			add_child(p)
			p.play()

func _process(delta: float) -> void:
	if _ring != null:
		_ring.rotation.y += delta * 0.4 * maxf(0.25, intensity)

static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = Color(c.r, c.g, c.b)
	mat.emission_energy_multiplier = energy
	return mat
