## Loot drop — spawned on boss death. Player walks over it to auto-equip.
class_name EquipmentPickup
extends Area3D

## "main_hand" or "armor"
var slot: String = "main_hand"
## WeaponData or ArmorData instance set by the spawner.
var item = null

var _age: float = 0.0
var _mesh: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1  # player layer

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)

	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	(_mesh.mesh as BoxMesh).size = Vector3(0.25, 0.38, 0.08)
	_mesh.position.y = 0.55
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.8, 0.2) if slot == "main_hand" else Color(0.5, 0.65, 0.95)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.5
	mat.emission_energy_multiplier = 1.4
	_mesh.material_override = mat
	add_child(_mesh)

	var prompt := Label3D.new()
	prompt.text = "[Walk over to equip]"
	prompt.position = Vector3(0, 1.3, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 36
	prompt.pixel_size = 0.004
	add_child(prompt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_age += delta
	if _mesh != null:
		_mesh.rotation.y = _age * 2.2

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players") or item == null or GameState.sarro == null:
		return
	match slot:
		"main_hand": GameState.sarro.equipment.equip_main_hand(item)
		"armor":     GameState.sarro.equipment.equip_armor(item)
	var n = item.get("weapon_name")
	if n == null:
		n = item.get("armor_name")
	print("[Loot] Equipped: %s" % str(n))
	queue_free()
