## Dodgeable enemy projectile: flies in a straight line toward where the
## target WAS at fire time, so strafing sidesteps it — travel time is the
## counterplay. On overlapping any living party body it hands that body to
## `on_hit` (the shooter resolves the SRD attack) and frees itself.
class_name Projectile
extends Node3D

const SPEED       := 9.0
const HIT_RADIUS  := 0.55   # metres, XZ
const MAX_LIFE    := 2.5    # seconds before fizzling

## func(body: CharacterBody3D) -> void — resolve the attack on this body.
var on_hit: Callable

var _dir: Vector3 = Vector3.FORWARD
var _age: float = 0.0

# (Untyped return: a class_name can't reference itself in static methods —
# same Godot 4.7 limitation noted in character_factory.gd.)
static func fire(parent: Node, from: Vector3, toward: Vector3,
		hit_cb: Callable, color := Color(0.55, 0.95, 1.0)):
	var p = load("res://scripts/combat/projectile.gd").new()
	p.on_hit = hit_cb
	parent.add_child(p)
	p.global_position = from + Vector3(0, 1.2, 0)
	var d := toward - from
	d.y = 0.0
	p._dir = d.normalized() if d.length_squared() > 0.0001 else Vector3.FORWARD
	p._add_visual(color)
	return p

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > MAX_LIFE:
		queue_free()
		return
	global_position += _dir * SPEED * delta
	var bodies: Array = get_tree().get_nodes_in_group("players") \
		+ get_tree().get_nodes_in_group("companions")
	for body in bodies:
		if not body is CharacterBody3D:
			continue
		var to_body: Vector3 = (body as Node3D).global_position - global_position
		if absf(to_body.y) > 1.6:
			continue
		to_body.y = 0.0
		if to_body.length() <= HIT_RADIUS:
			if on_hit.is_valid():
				on_hit.call(body)
			queue_free()
			return

func _add_visual(color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	sphere.material = mat
	mi.mesh = sphere
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.6
	light.omni_range = 2.0
	add_child(light)
