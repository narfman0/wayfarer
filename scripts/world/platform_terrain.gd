## Eroded-platform terrain: replaces the perfect flat BoxMesh slab with an
## irregular plane fragment — chamfered corners, noise-bitten edges, a craggy
## skirt falling away beneath — plus portal pads floating just beyond the
## bounds, connected by clean rectangular-prism causeways. The contrast is
## the point: eroded organic edges against precise Veil-cut geometry.
##
## The top face stays flat at y=0 (gameplay is untouched: click-to-move,
## pathfinding, boss arenas). A world-space grid glows faintly on top —
## spacing matches the 2 m movement tiles, so it reads tactically in TB.
##
## Deterministic per plane: seeded from plane_id, so the editor preview and
## every run agree.
class_name PlatformTerrain
extends RefCounted

## Per-plane grid identity: line colour + strength (whisper on warm daylight
## planes, assertive where the Veil is thick). Aliases mirror Atmosphere.
const GRID_STYLE := {
	"tamori":      {"color": Color(0.9, 0.85, 0.68), "strength": 0.03},
	"reach":       {"color": Color(0.6, 0.66, 1.0),  "strength": 0.07},
	"kaveth":      {"color": Color(0.65, 0.45, 1.0), "strength": 0.09},
	"verath":      {"color": Color(0.55, 0.75, 0.85),"strength": 0.05},
	"between":     {"color": Color(0.75, 0.72, 0.95),"strength": 0.10},
	"ashan":       {"color": Color(1.0, 0.8, 0.55),  "strength": 0.035},
	"convergence": {"color": Color(0.85, 0.5, 1.0),  "strength": 0.10},
}
const _ALIASES := {
	"tamori_road": "tamori", "tamori_fields": "tamori", "tamori_anchor": "tamori",
	"reach_rig": "reach", "kaveth_vault": "kaveth", "verath_seawall": "verath",
	"convergence_approach": "convergence",
}

static func style_for(plane_id: String) -> Dictionary:
	var key: String = _ALIASES.get(plane_id, plane_id)
	return GRID_STYLE.get(key, {"color": Color(0.62, 0.66, 1.0), "strength": 0.06})

const SKIRT_DEPTH := 3.0
const EDGE_SEG := 3.0        # metres per boundary segment
const BITE_MAX := 1.8        # deepest inward erosion
const CHAMFER := 4.0         # corner cut size

const _GRID_SHADER := "
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 line_color : source_color = vec4(0.6, 0.65, 1.0, 1.0);
uniform float grid_spacing = 2.0;
uniform float line_width = 0.03;
uniform float grid_strength = 0.07;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	// faint grid on upward faces only
	float topness = smoothstep(0.75, 0.95, wnorm.y);
	vec2 g = abs(fract(wpos.xz / grid_spacing - 0.5) - 0.5) * grid_spacing;
	float line = 1.0 - smoothstep(line_width * 0.4, line_width, min(g.x, g.y));
	EMISSION = line_color.rgb * (line * grid_strength * topness);
}
"

## Build the eroded platform mesh for a w×d footprint (centered on origin).
## Erosion is inward-only so the walkable bounds never exceed the visual edge.
static func build_platform(w: float, d: float, seed_val: int, bite_max := BITE_MAX) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var hw := w * 0.5
	var hd := d * 0.5

	# Outline: rectangle with chamfered corners, subdivided and bitten inward.
	var corners := [
		Vector2(-hw + CHAMFER, -hd), Vector2(hw - CHAMFER, -hd),
		Vector2(hw, -hd + CHAMFER), Vector2(hw, hd - CHAMFER),
		Vector2(hw - CHAMFER, hd), Vector2(-hw + CHAMFER, hd),
		Vector2(-hw, hd - CHAMFER), Vector2(-hw, -hd + CHAMFER),
	]
	var outline: PackedVector2Array = []
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var segs := maxi(1, int(a.distance_to(b) / EDGE_SEG))
		for s in segs:
			var p: Vector2 = a.lerp(b, float(s) / segs)
			# bite inward: pull toward center by noise amount (never outward)
			var toward := -p.normalized()
			var bite := rng.randf_range(0.0, bite_max)
			# keep some segments clean so it reads cut, not crumbled
			if rng.randf() < 0.35:
				bite = 0.0
			outline.append(p + toward * bite)

	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Top face at y=0. Winding depends on outline orientation — check the
	# first triangle's normal and flip if it faces down.
	var indices := Geometry2D.triangulate_polygon(outline)
	var order := [0, 1, 2]
	if indices.size() >= 3:
		var a3 := Vector3(outline[indices[0]].x, 0, outline[indices[0]].y)
		var b3 := Vector3(outline[indices[1]].x, 0, outline[indices[1]].y)
		var c3 := Vector3(outline[indices[2]].x, 0, outline[indices[2]].y)
		if (b3 - a3).cross(c3 - a3).y > 0.0:
			order = [0, 2, 1]
	for i in range(0, indices.size(), 3):
		for j in order:
			var v: Vector2 = outline[indices[i + j]]
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, 0.0, v.y))

	# Craggy skirt: each boundary edge extrudes down to an inset bottom ring.
	var n := outline.size()
	var bottom: Array[Vector3] = []
	for i in n:
		var p: Vector2 = outline[i]
		var inset: Vector2 = p - p.normalized() * rng.randf_range(1.0, 3.0)
		bottom.append(Vector3(inset.x, -SKIRT_DEPTH - rng.randf_range(0.0, 1.4), inset.y))
	for i in n:
		var j := (i + 1) % n
		var t0 := Vector3(outline[i].x, 0.0, outline[i].y)
		var t1 := Vector3(outline[j].x, 0.0, outline[j].y)
		var b0: Vector3 = bottom[i]
		var b1: Vector3 = bottom[j]
		var fn := (t1 - t0).cross(b0 - t0).normalized()
		var outward := Vector3(outline[i].x, 0, outline[i].y).normalized()
		var verts := [t0, t1, b1, t0, b1, b0]
		if fn.dot(outward) < 0.0:
			fn = -fn
			verts = [t0, b1, t1, t0, b0, b1]
		for v in verts:
			st.set_normal(fn)
			st.add_vertex(v)

	st.index()
	st.commit(mesh)
	return mesh

## Standard-material grid shader, tinted from the plane's old slab color.
static func grid_material(albedo: Color, line: Color, strength := 0.07) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = _GRID_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_color", albedo)
	mat.set_shader_parameter("line_color", line)
	mat.set_shader_parameter("grid_strength", strength)
	return mat

## A clean rectangular-prism causeway from `from_edge` toward `to_pad`
## (both XZ), top slightly below y=0 so it reads as separate structure.
static func causeway(from_pos: Vector3, to_pos: Vector3, mat: Material) -> MeshInstance3D:
	var dir := to_pos - from_pos
	dir.y = 0.0
	var length := dir.length()
	var box := BoxMesh.new()
	box.size = Vector3(2.6, 0.7, length)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = (from_pos + to_pos) * 0.5 + Vector3(0, -0.35, 0)  # top flush with feet
	mi.rotation.y = atan2(-dir.x, -dir.z)
	return mi

## A small eroded pad (for portals) floating at `center`. Walkable pads
## erode gently so the invisible rails never overhang a bite.
static func pad(center: Vector3, size: float, seed_val: int, mat: Material,
		walkable := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_platform(size, size, seed_val, 0.7 if walkable else BITE_MAX)
	mi.material_override = mat
	mi.position = center
	return mi
