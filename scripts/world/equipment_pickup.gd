## Loot drop — spawned on boss death. Player walks over it to auto-equip.
class_name EquipmentPickup
extends Area3D

const _SLOT_SKINS := {
	"main_hand": "res://assets/meshes/POLYGON_Fantasy_Characters_SourceFiles_v3/Source_Files/FBX/SM_Prop_SwordOrnate_01.gltf",
	"armor":     "res://assets/meshes/POLYGON_Fantasy_Characters_SourceFiles_v3/Source_Files/FBX/SM_Prop_Sceptre_01.gltf",
}
const _SLOT_COLORS := {
	"main_hand": Color(0.95, 0.8, 0.2),
	"armor":     Color(0.5, 0.65, 0.95),
}

## "main_hand" or "armor"
var slot: String = "main_hand"
## WeaponData or ArmorData instance set by the spawner.
var item = null

var _age: float = 0.0
var _visual: Node3D

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1  # player layer

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)

	var glow_color: Color = _SLOT_COLORS.get(slot, Color(1, 1, 1))
	var skin_path: String = _SLOT_SKINS.get(slot, "")
	var skin_loaded := false
	if skin_path != "" and FileAccess.file_exists(skin_path + ".import"):
		var ps := load(skin_path) as PackedScene
		if ps != null:
			_visual = ps.instantiate()
			_visual.position.y = 0.45
			add_child(_visual)
			skin_loaded = true

	if not skin_loaded:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		(mi.mesh as BoxMesh).size = Vector3(0.25, 0.38, 0.08)
		mi.position.y = 0.55
		var mat := StandardMaterial3D.new()
		mat.albedo_color = glow_color
		mat.emission_enabled = true
		mat.emission = glow_color * 0.5
		mat.emission_energy_multiplier = 1.4
		mi.material_override = mat
		_visual = mi
		add_child(_visual)

	# Point light so the pickup reads clearly from a distance.
	var light := OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 1.2
	light.omni_range = 2.5
	light.position.y = 0.5
	add_child(light)

	var prompt := preload("res://scripts/ui/screen_prompt.gd").new()
	prompt.text = "[Walk over to equip]"
	prompt.position = Vector3(0, 1.3, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 36
	prompt.pixel_size = 0.004
	add_child(prompt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_age += delta
	if _visual != null:
		_visual.rotation.y = _age * 2.2

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
