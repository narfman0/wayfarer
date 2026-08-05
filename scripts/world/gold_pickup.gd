## Gold coins dropped by enemies. Player walks over to collect.
extends Area3D

var gold_amount: int = 10

var _age: float = 0.0
var _mesh: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.18
	cyl.bottom_radius = 0.18
	cyl.height        = 0.06
	_mesh.mesh = cyl
	_mesh.position.y  = 0.3
	_mesh.rotation.x  = deg_to_rad(90.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color           = Color(1.0, 0.82, 0.1)
	mat.emission_enabled       = true
	mat.emission               = Color(1.0, 0.75, 0.0)
	mat.emission_energy_multiplier = 1.6
	mat.metallic               = 0.8
	mat.roughness              = 0.2
	_mesh.material_override = mat
	add_child(_mesh)

	var lbl := Label3D.new()
	lbl.text       = "%dg" % gold_amount
	lbl.position   = Vector3(0, 0.9, 0)
	lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size  = 40
	lbl.pixel_size = 0.004
	lbl.modulate   = Color(1.0, 0.9, 0.3)
	add_child(lbl)

	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_age += delta
	if _mesh != null:
		_mesh.rotation.z = _age * 2.8

func _on_body(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	GameState.add_gold(gold_amount)
	queue_free()
