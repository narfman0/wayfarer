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
	"tamori": {"sky_tint": Color(0.45, 0.30, 0.75), "sun_rot": Vector3(-55.0, 40.0, 0.0), "sun_energy": 1.2},
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
	"reach": {"sky_tint": Color(0.35, 0.35, 0.30), "sun_rot": Vector3(-58.0, 20.0, 0.0),
		"sun_color": Color(0.88, 0.9, 0.88), "sun_energy": 0.85,
		"particles": {"color": Color(0.6, 0.58, 0.52, 0.7), "amount": 34, "rise": -0.08,
			"drift": 0.45, "size": 0.035, "glow": 0.6}},
	# Old Kaveth: night. A low blue moon; the Veil's violet motes rise off the
	# ruins — the plane is lit by what broke it.
	"kaveth": {"sky_tint": Color(0.40, 0.20, 0.85), "ambient": Color(0.22, 0.20, 0.40), "ambient_energy": 0.5, "sun_rot": Vector3(-28.0, -120.0, 0.0),
		"sun_color": Color(0.5, 0.55, 0.95), "sun_energy": 0.3,
		"particles": {"color": Color(0.65, 0.4, 1.0, 0.9), "amount": 40, "rise": 0.25,
			"drift": 0.15, "size": 0.035, "glow": 2.5}},
	# Verath: overcast sea-glare, salt haze hanging in the air.
	"verath": {"sky_tint": Color(0.25, 0.45, 0.55), "sun_rot": Vector3(-50.0, -30.0, 0.0),
		"sun_color": Color(0.85, 0.9, 0.95), "sun_energy": 0.95,
		"particles": {"color": Color(0.85, 0.9, 0.92, 0.5), "amount": 30, "rise": 0.05,
			"drift": 0.6, "size": 0.05, "glow": 0.5}},
	# The Between: directionless — sun nearly vertical so shadows die, pale
	# motes falling upward.
	"between": {"sky_tint": Color(0.55, 0.50, 0.70), "ambient": Color(0.42, 0.40, 0.52), "ambient_energy": 0.7, "sun_rot": Vector3(-85.0, 0.0, 0.0),
		"sun_color": Color(0.75, 0.7, 0.9), "sun_energy": 0.3,
		"particles": {"color": Color(0.75, 0.7, 0.9, 0.7), "amount": 36, "rise": 0.3,
			"drift": 0.1, "size": 0.04, "glow": 1.5}},
	# Ashan: golden hour, forever — low warm sun, long shadows, gold pollen.
	"ashan": {"sky_tint": Color(0.80, 0.55, 0.30), "ambient": Color(0.48, 0.36, 0.22), "ambient_energy": 0.8, "sun_rot": Vector3(-14.0, -70.0, 0.0),
		"sun_color": Color(1.0, 0.72, 0.42), "sun_energy": 1.35,
		"particles": {"color": Color(1.0, 0.85, 0.5, 0.8), "amount": 34, "rise": -0.06,
			"drift": 0.25, "size": 0.035, "glow": 1.6}},
	# The Convergence: harsh violet — the Veil under strain, sparks climbing.
	"convergence": {"sky_tint": Color(0.75, 0.25, 0.90), "ambient": Color(0.36, 0.24, 0.46), "ambient_energy": 0.6, "sun_rot": Vector3(-55.0, 150.0, 0.0),
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

## Procedural cosmos: the flat void gradient plus a faint FBM nebula and a
## hash starfield — stars continue below the horizon because there is no
## ground out there, only more void. Planes tint the nebula via "sky_tint"
## in their PLANES spec.
const _SKY_SHADER := "
shader_type sky;

uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 ground_color : source_color;
uniform vec3 nebula_tint : source_color;
uniform float nebula_strength = 0.30;
uniform float star_density = 0.5;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void sky() {
	float h = EYEDIR.y;
	vec3 col;
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 2.4, 0.0, 1.0));
	} else {
		col = mix(horizon_color, top_color, clamp(h * 1.6, 0.0, 1.0));
	}

	// Nebula: two fbm layers, denser toward the horizon band.
	float n = fbm(EYEDIR * 3.0);
	float detail = fbm(EYEDIR * 7.0 + 13.7);
	float band = 1.0 - abs(h) * 0.7;
	float neb = smoothstep(0.42, 0.78, n) * nebula_strength * band;
	col += nebula_tint * neb * (0.55 + 0.45 * detail);

	// Stars: hashed cells over direction, sharpened to points, slight
	// per-star brightness variance. Everywhere — the void has no floor.
	vec3 sp = EYEDIR * 230.0;
	vec3 cell = floor(sp);
	float pick = hash13(cell);
	if (pick > 1.0 - star_density * 0.02) {
		vec3 f = fract(sp) - 0.5;
		float d = length(f);
		float tw = smoothstep(0.30, 0.05, d);
		col += vec3(0.85, 0.87, 1.0) * tw * (0.4 + 0.6 * hash13(cell + 7.0));
	}

	COLOR = col;
}
"

static func apply(level: Node3D, plane_id: String, sun: DirectionalLight3D,
		ground_mi: MeshInstance3D) -> void:
	var spec: Dictionary = _DEFAULT.duplicate()
	spec.merge(PLANES.get(_ALIASES.get(plane_id, plane_id), {}), true)

	_apply_void_sky(level, spec.get("sky_tint", Color(0.45, 0.25, 0.75)),
		spec.get("ambient", Color(0.30, 0.28, 0.42)),
		spec.get("ambient_energy", 0.55))

	if sun != null:
		sun.rotation_degrees = spec["sun_rot"]
		sun.light_color = spec["sun_color"]
		# Dim the sun to 75% — islands in the void aren't under a noon sky.
		# (Was 55% under ACES; AgX rolls highlights off gently enough to
		# afford brighter keys without clipping.)
		sun.light_energy = spec["sun_energy"] * 0.75

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
static func _apply_void_sky(level: Node3D, sky_tint: Color = Color(0.45, 0.25, 0.75),
		ambient: Color = Color(0.30, 0.28, 0.42), ambient_energy: float = 0.55) -> void:
	var we: WorldEnvironment = null
	for n in level.find_children("*", "WorldEnvironment", true, false):
		we = n
		break
	if we == null:
		return
	var env: Environment = we.environment.duplicate() if we.environment != null \
			else Environment.new()

	var shader := Shader.new()
	shader.code = _SKY_SHADER
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = shader
	sky_mat.set_shader_parameter("top_color", _VOID_SKY_TOP)
	sky_mat.set_shader_parameter("horizon_color", _VOID_SKY_HORIZON)
	sky_mat.set_shader_parameter("ground_color", _VOID_SKY_GROUND)
	sky_mat.set_shader_parameter("nebula_tint", sky_tint)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = ambient  # per-plane; default cool violet-dark
	env.ambient_light_energy = ambient_energy
	we.environment = env
	_add_fill_light(level)

## Soft cool fill light from below-opposite the sun — gives the underside of
## islands a faint blue-violet rim and stops lit materials going pure black.
static func _add_fill_light(level: Node3D) -> void:
	var fill := DirectionalLight3D.new()
	fill.name = "VoidFill"
	fill.light_color = Color(0.40, 0.45, 0.70)   # cool blue-violet
	fill.light_energy = 0.25
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(40.0, -145.0, 0.0)  # low angle, opposite sun
	level.add_child(fill)

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
