## Scar tissue — the rigid, crystalline residue of Mender-stitched Veil.
## Reads as visibly WRONG against organic scenery: pale shards jutting at
## harsh angles in a rough patch. The Between's reveal (scar tissue vs.
## self-healing Veil) trades on the player having seen this for two acts, so
## every Mender-touched site places one of these.
##
## Attach to a bare Node3D; the patch builds itself in _ready, seeded from the
## node's position so layouts are stable.
class_name ScarTissue
extends Node3D

@export var patch_radius: float = 2.5
@export var shard_count: int = 9

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2(global_position.x, global_position.z))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.84, 0.9)
	mat.metallic = 0.4
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.78, 0.95)
	mat.emission_energy_multiplier = 0.35
	for i in shard_count:
		var prism := PrismMesh.new()
		var h := rng.randf_range(0.5, 1.7)
		prism.size = Vector3(rng.randf_range(0.12, 0.35), h, rng.randf_range(0.12, 0.3))
		var mi := MeshInstance3D.new()
		mi.mesh = prism
		mi.material_override = mat
		var ang := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.0, patch_radius)
		mi.position = Vector3(cos(ang) * r, h * 0.35, sin(ang) * r)
		mi.rotation_degrees = Vector3(rng.randf_range(-38.0, 38.0),
			rng.randf_range(0.0, 360.0), rng.randf_range(-38.0, 38.0))
		add_child(mi)
