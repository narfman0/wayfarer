## Telegraphed-AoE ground warning (bosses.md vocabulary: circle / cone / line /
## donut). A faint base shape appears immediately; a brighter fill grows to the
## full shape over `duration`, then `fired` is emitted and the node frees
## itself. Damage is the caller's job on `fired` — the dodge IS the defense, so
## standing outside the shape when it fires must always mean "no hit"; use
## contains() for that test so every ability resolves against the same shape
## the player saw.
##
## Usage:
##   var t := Telegraph.show_circle(scene, pos, 2.5, 1.1)
##   t.fired.connect(func(): _slam(t))       # or: await t.fired
class_name Telegraph
extends Node3D

signal fired

enum Shape { CIRCLE, LINE, CONE, DONUT }

const _COLOR_BASE := Color(1.0, 0.42, 0.12, 0.25)
const _COLOR_FILL := Color(1.0, 0.30, 0.08, 0.5)
const _Y_LIFT := 0.06  # above the ground plane so it never z-fights

## Semantic tints for the optional `tint` constructor arg — a color grammar
## for the correct RESPONSE, kept consistent across every fight:
##   orange (default) — get out of the shape; footwork is the answer
##   SOAK   (cyan)    — someone must STAND here when it fires
##   HOLD   (green)   — stand here to claim it / healing lands here
##   VEIL   (violet)  — channel projection: footwork won't help, stop the
##                      cast (interrupt, kill the caster, break the rig)
const TINT_SOAK := Color(0.30, 0.85, 1.0)
const TINT_HOLD := Color(0.40, 1.0, 0.60)
const TINT_VEIL := Color(0.72, 0.40, 1.0)

var _color_base := _COLOR_BASE
var _color_fill := _COLOR_FILL

var shape: Shape = Shape.CIRCLE
var duration: float = 1.2
## CIRCLE: {radius}  LINE: {length, width}  CONE: {radius, angle_deg}
## DONUT: {inner, outer}. LINE/CONE extend along the node's -Z (use `direction`
## in the constructors to aim them).
var params: Dictionary = {}

var _fill_pivot: Node3D

# ── Constructors ──────────────────────────────────────────────────────────────
# (Return the Telegraph node untyped: a class_name can't reference itself in
# static methods — same Godot 4.7 limitation noted in character_factory.gd.)

static func show_circle(parent: Node, origin: Vector3, radius: float,
		secs: float, tint := Color(0, 0, 0, 0)):
	return _spawn(parent, Shape.CIRCLE, origin, {"radius": radius}, secs,
		Vector3.FORWARD, tint)

static func show_line(parent: Node, origin: Vector3, direction: Vector3,
		length: float, width: float, secs: float, tint := Color(0, 0, 0, 0)):
	return _spawn(parent, Shape.LINE, origin,
		{"length": length, "width": width}, secs, direction, tint)

static func show_cone(parent: Node, origin: Vector3, direction: Vector3,
		radius: float, angle_deg: float, secs: float, tint := Color(0, 0, 0, 0)):
	return _spawn(parent, Shape.CONE, origin,
		{"radius": radius, "angle_deg": angle_deg}, secs, direction, tint)

static func show_donut(parent: Node, origin: Vector3, inner: float,
		outer: float, secs: float, tint := Color(0, 0, 0, 0)):
	return _spawn(parent, Shape.DONUT, origin,
		{"inner": inner, "outer": outer}, secs, Vector3.FORWARD, tint)

static func _spawn(parent: Node, s: Shape, origin: Vector3, p: Dictionary,
		secs: float, direction: Vector3, tint := Color(0, 0, 0, 0)):
	var t = load("res://scripts/combat/telegraph.gd").new()
	t.shape = s
	t.params = p
	t.duration = maxf(0.1, secs)
	if tint.a > 0.0:
		t._color_base = Color(tint.r, tint.g, tint.b, _COLOR_BASE.a)
		t._color_fill = Color(tint.r, tint.g, tint.b, _COLOR_FILL.a)
	parent.add_child(t)
	t.global_position = origin + Vector3(0, _Y_LIFT, 0)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		t.rotation.y = atan2(-direction.x, -direction.z)  # -Z faces `direction`
	return t

# ── Hit test ──────────────────────────────────────────────────────────────────

## True if a world-space point stands in the telegraphed area (XZ only).
func contains(world_point: Vector3) -> bool:
	var lp := to_local(world_point)
	lp.y = 0.0
	match shape:
		Shape.CIRCLE:
			return lp.length() <= float(params["radius"])
		Shape.DONUT:
			var d := lp.length()
			return d >= float(params["inner"]) and d <= float(params["outer"])
		Shape.LINE:
			# extends along -Z from the origin
			return -lp.z >= 0.0 and -lp.z <= float(params["length"]) \
				and absf(lp.x) <= float(params["width"]) * 0.5
		Shape.CONE:
			var d := lp.length()
			if d < 0.001 or d > float(params["radius"]):
				return d < 0.001  # apex counts as inside
			var ang := rad_to_deg(Vector3.FORWARD.angle_to(lp / d))
			return ang <= float(params["angle_deg"]) * 0.5
	return false

# ── Visuals ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.play_sfx("telegraph")
	var base := _make_mesh_instance(_flat_material(_color_base))
	add_child(base)
	_fill_pivot = Node3D.new()
	add_child(_fill_pivot)
	var fill := _make_mesh_instance(_flat_material(_color_fill))
	_fill_pivot.add_child(fill)

	# The warning casts real light that intensifies toward the impact — the
	# ground-projection read bosses will lean on. Shadowless, freed with us.
	var warn_light := OmniLight3D.new()
	warn_light.light_color = Color(_color_fill.r, _color_fill.g, _color_fill.b)
	warn_light.light_energy = 0.4
	warn_light.omni_range = _light_range()
	warn_light.omni_attenuation = 1.2
	warn_light.shadow_enabled = false
	warn_light.position = _light_center() + Vector3(0, 0.8, 0)
	add_child(warn_light)
	var lt := create_tween()
	lt.tween_property(warn_light, "light_energy", 1.8, duration)

	# The fill sweeps outward and lands exactly on the base at fire time —
	# classic "leave before it fills" read. Donuts pulse instead (scaling a
	# torus would change both radii).
	var tween := create_tween()
	if shape == Shape.DONUT:
		_fill_pivot.scale = Vector3.ONE
		fill.transparency = 1.0
		tween.tween_property(fill, "transparency", 0.2, duration)
	else:
		_fill_pivot.scale = Vector3(0.01, 1.0, 0.01)
		tween.tween_property(_fill_pivot, "scale", Vector3.ONE, duration)
	tween.tween_callback(_fire)

func _fire() -> void:
	fired.emit()
	# brief flash so the impact frame reads, then clean up
	var flash := create_tween()
	flash.tween_property(self, "scale", Vector3(1.06, 1.0, 1.06), 0.08)
	flash.tween_callback(queue_free)

## Light reach scaled to the warned area so big slams glow bigger.
func _light_range() -> float:
	match shape:
		Shape.CIRCLE:
			return float(params["radius"]) * 2.2
		Shape.DONUT:
			return float(params["outer"]) * 2.2
		Shape.LINE:
			return float(params["length"]) * 0.9
		Shape.CONE:
			return float(params["radius"]) * 1.8
	return 5.0

## LINE extends along -Z; center the glow on the strip, not the caster.
func _light_center() -> Vector3:
	if shape == Shape.LINE:
		return Vector3(0, 0, -float(params["length"]) * 0.5)
	return Vector3.ZERO

func _make_mesh_instance(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match shape:
		Shape.LINE:
			# BoxMesh is centered — push it so it extends along -Z from origin
			mi.position.z = -float(params["length"]) * 0.5
		Shape.DONUT:
			mi.scale.y = 0.05  # flatten the torus onto the ground plane
	return mi

func _build_mesh() -> Mesh:
	match shape:
		Shape.CIRCLE:
			var cyl := CylinderMesh.new()
			cyl.top_radius = float(params["radius"])
			cyl.bottom_radius = float(params["radius"])
			cyl.height = 0.02
			return cyl
		Shape.LINE:
			var box := BoxMesh.new()
			box.size = Vector3(float(params["width"]), 0.02, float(params["length"]))
			return box
		Shape.DONUT:
			var torus := TorusMesh.new()
			torus.inner_radius = float(params["inner"])
			torus.outer_radius = float(params["outer"])
			return torus
		Shape.CONE:
			return _fan_mesh(float(params["radius"]), float(params["angle_deg"]))
	return null

## Flat triangle fan in the XZ plane, apex at origin, opening toward -Z.
func _fan_mesh(radius: float, angle_deg: float) -> ArrayMesh:
	var half := deg_to_rad(angle_deg * 0.5)
	var segs := maxi(6, int(angle_deg / 10.0))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in segs:
		var a0 := -half + (2.0 * half) * i / segs
		var a1 := -half + (2.0 * half) * (i + 1) / segs
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a0), 0.0, -cos(a0)) * radius)
		verts.append(Vector3(sin(a1), 0.0, -cos(a1)) * radius)
		for j in 3:
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 1.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
