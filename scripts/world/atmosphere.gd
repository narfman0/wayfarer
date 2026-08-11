## Per-plane atmosphere: deliberate sun angle/color/energy plus one signature
## ambient particle field. Data-driven counterpart to Scenery.RECIPES — the
## env_*.tres resources own sky/fog/glow; this owns the Sun (a scene node,
## outside Environment's reach) and the ambient motes, so the eight planes stop
## sharing one noon lighting rig.
##
## The particle field is a single CPUParticles3D (headless-safe, same reasoning
## as juice.gd) spanning the arena: pollen over Tamori, ash on the Reach, veil
## motes at night in Kaveth, sea haze in Verath, and so on. One system per
## plane, ever — it's an identity accent, not weather.
class_name Atmosphere
extends RefCounted

const _DEFAULT := {
	"sun_rot": Vector3(-50.0, 35.0, 0.0),
	"sun_color": Color(1.0, 0.97, 0.9),
	"sun_energy": 1.1,
	"particles": {"color": Color(1.0, 0.95, 0.7, 0.8), "amount": 30, "rise": -0.12,
		"drift": 0.3, "size": 0.03, "glow": 1.2},
}

## plane_id → overrides on _DEFAULT. Sun pitch tells the time of day; the
## particle field is the plane's signature dust.
const PLANES := {
	# Tamori: late morning at home — warm sun, drifting pollen.
	"tamori": {"sun_rot": Vector3(-55.0, 40.0, 0.0), "sun_energy": 1.2},
	"tamori_road": {"sun_rot": Vector3(-50.0, 45.0, 0.0), "sun_energy": 1.15},
	# The frontier planes push the sun lower and the light dustier as Act 1
	# walks toward the anchor.
	"tamori_fields": {"sun_rot": Vector3(-40.0, 55.0, 0.0),
		"sun_color": Color(1.0, 0.9, 0.78), "sun_energy": 0.95},
	"tamori_anchor": {"sun_rot": Vector3(-35.0, 60.0, 0.0),
		"sun_color": Color(0.95, 0.85, 0.75), "sun_energy": 0.85,
		"particles": {"color": Color(0.8, 0.7, 0.95, 0.8), "amount": 26, "rise": 0.15,
			"drift": 0.2, "size": 0.03, "glow": 2.0}},
	# The Reach: flat overcast glare over scarred grassland; grey ash drifts.
	"reach": {"sun_rot": Vector3(-58.0, 20.0, 0.0),
		"sun_color": Color(0.88, 0.9, 0.88), "sun_energy": 0.85,
		"particles": {"color": Color(0.6, 0.58, 0.52, 0.7), "amount": 34, "rise": -0.08,
			"drift": 0.45, "size": 0.035, "glow": 0.6}},
	# Old Kaveth: night. A low blue moon; the Veil's violet motes rise off the
	# ruins — the plane is lit by what broke it.
	"kaveth": {"sun_rot": Vector3(-28.0, -120.0, 0.0),
		"sun_color": Color(0.5, 0.55, 0.95), "sun_energy": 0.3,
		"particles": {"color": Color(0.65, 0.4, 1.0, 0.9), "amount": 40, "rise": 0.25,
			"drift": 0.15, "size": 0.035, "glow": 2.5}},
	# Verath: overcast sea-glare, salt haze hanging in the air.
	"verath": {"sun_rot": Vector3(-50.0, -30.0, 0.0),
		"sun_color": Color(0.85, 0.9, 0.95), "sun_energy": 0.95,
		"particles": {"color": Color(0.85, 0.9, 0.92, 0.5), "amount": 30, "rise": 0.05,
			"drift": 0.6, "size": 0.05, "glow": 0.5}},
	# The Between: directionless — sun nearly vertical so shadows die, pale
	# motes falling upward.
	"between": {"sun_rot": Vector3(-85.0, 0.0, 0.0),
		"sun_color": Color(0.75, 0.7, 0.9), "sun_energy": 0.3,
		"particles": {"color": Color(0.75, 0.7, 0.9, 0.7), "amount": 36, "rise": 0.3,
			"drift": 0.1, "size": 0.04, "glow": 1.5}},
	# Ashan: golden hour, forever — low warm sun, long shadows, gold pollen.
	"ashan": {"sun_rot": Vector3(-14.0, -70.0, 0.0),
		"sun_color": Color(1.0, 0.72, 0.42), "sun_energy": 1.05,
		"particles": {"color": Color(1.0, 0.85, 0.5, 0.8), "amount": 34, "rise": -0.06,
			"drift": 0.25, "size": 0.035, "glow": 1.6}},
	# The Convergence: harsh violet — the Veil under strain, sparks climbing.
	"convergence": {"sun_rot": Vector3(-55.0, 150.0, 0.0),
		"sun_color": Color(0.8, 0.5, 1.0), "sun_energy": 0.75,
		"particles": {"color": Color(0.85, 0.45, 1.0, 0.9), "amount": 44, "rise": 0.5,
			"drift": 0.3, "size": 0.03, "glow": 3.0}},
}

## Apply the plane's sun and ambient particles to a level. `sun` is the scene's
## DirectionalLight3D; `ground_mi` sizes the particle field from its mesh AABB.
## Split scenes share their plane's atmosphere.
const _ALIASES := {
	"reach_rig": "reach",
	"kaveth_vault": "kaveth",
	"verath_seawall": "verath",
	"convergence_approach": "convergence",
}

## The void sky wrapped around every floating island: deep cosmic blue-purple
## fading to near-black below the horizon, no sun disk, no fog. Applied over
## whatever Environment the scene's WorldEnvironment carries (the env_*.tres
## still own glow/tonemap; background and fog are overridden here so islands
## read as platforms adrift in a void rather than ground stretching forever).
const _VOID_SKY_TOP     := Color(0.05, 0.03, 0.12)
const _VOID_SKY_HORIZON := Color(0.12, 0.10, 0.20)
const _VOID_SKY_GROUND  := Color(0.02, 0.01, 0.05)

static func apply(level: Node3D, plane_id: String, sun: DirectionalLight3D,
		ground_mi: MeshInstance3D) -> void:
	var spec: Dictionary = _DEFAULT.duplicate()
	spec.merge(PLANES.get(_ALIASES.get(plane_id, plane_id), {}), true)

	_apply_void_sky(level)

	if sun != null:
		sun.rotation_degrees = spec["sun_rot"]
		sun.light_color = spec["sun_color"]
		sun.light_energy = spec["sun_energy"]

	var hx := 20.0
	var hz := 20.0
	if ground_mi != null and ground_mi.mesh != null:
		var ab := ground_mi.mesh.get_aabb()
		hx = ab.size.x * 0.5
		hz = ab.size.z * 0.5
	level.add_child(_make_field(spec["particles"], hx, hz))

## Replace the level Environment's background with the void sky and kill fog.
## The scene's env resource is duplicated first — glow/tonemap/adjustments
## survive; only background, fog, and ambient are overridden. Ambient comes
## from a fixed soft colour (not the sky) so the near-black void doesn't crush
## island lighting.
static func _apply_void_sky(level: Node3D) -> void:
	var we: WorldEnvironment = null
	for n in level.find_children("*", "WorldEnvironment", true, false):
		we = n
		break
	if we == null:
		return
	var env: Environment = we.environment.duplicate() if we.environment != null \
			else Environment.new()

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = _VOID_SKY_TOP
	sky_mat.sky_horizon_color    = _VOID_SKY_HORIZON
	sky_mat.ground_horizon_color = _VOID_SKY_HORIZON
	sky_mat.ground_bottom_color  = _VOID_SKY_GROUND
	sky_mat.sun_angle_max = 0.0  # no sun disk in the void
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.45, 0.42, 0.55)
	env.ambient_light_energy = 0.6
	we.environment = env

static func _make_field(p: Dictionary, hx: float, hz: float) -> CPUParticles3D:
	var field := CPUParticles3D.new()
	field.name = "AmbientMotes"
	field.amount = p["amount"]
	field.lifetime = 8.0
	field.preprocess = 6.0  # field is already alive on fade-in
	field.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	field.emission_box_extents = Vector3(hx, 2.5, hz)
	field.position.y = 2.0
	field.direction = Vector3.ZERO
	field.spread = 180.0
	field.gravity = Vector3(0.0, p["rise"], 0.0)
	field.initial_velocity_min = p["drift"] * 0.4
	field.initial_velocity_max = p["drift"]
	field.scale_amount_min = 0.7
	field.scale_amount_max = 1.0

	var mesh := SphereMesh.new()
	mesh.radius = p["size"]
	mesh.height = p["size"] * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var color: Color = p["color"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = p["glow"]
	mesh.material = mat
	field.mesh = mesh
	return field
