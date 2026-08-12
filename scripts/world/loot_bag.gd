## Searchable loot bag dropped by enemies on death.
## Player walks up and presses [F] to open a pick-up overlay.
## Contents can be pre-set or generated at runtime via a seeded LootTable roll.
class_name LootBag
extends Area3D

const _LootTable    = preload("res://scripts/items/loot_table.gd")
const _BagScreen    = preload("res://scripts/ui/loot_bag_screen.gd")

const _SACK_PATHS := [
	"res://assets/meshes/POLYGON_Western_Pack_Source_Files_v4/SourceFiles/FBX/SM_Prop_Sack_01.gltf",
	"res://assets/meshes/POLYGON_Western_Pack_Source_Files_v4/SourceFiles/FBX/SM_Prop_Sack_02.gltf",
]

## Pre-populated gold (overridden by loot_table_key if set).
var gold_amount: int = 0
## Pre-populated items (overridden by loot_table_key if set).
var items: Array = []

## When non-empty, generate contents from this table during _ready().
@export var loot_table_key: String = ""
## Seed for the loot roll — 0 = hash of world position (same spot same loot).
@export var loot_seed: int = 0
## Bag disappears after this many seconds of being unclaimed (0 = never).
@export var despawn_after: float = 120.0

var _label: Label3D
var _bob_root: Node3D
var _player_inside: bool = false
var _open: bool = false
var _age: float = 0.0

func _ready() -> void:
	add_to_group("loot_bags")
	collision_layer = 0
	collision_mask  = 1

	if loot_table_key != "" and _LootTable.has_table(loot_table_key):
		var rng := RandomNumberGenerator.new()
		rng.seed = loot_seed if loot_seed != 0 else hash(str(global_position))
		var result: Dictionary = _LootTable.roll(rng, loot_table_key)
		gold_amount = result.get("gold", 0)
		items       = result.get("items", []).duplicate(true)

	var sphere_shape := CollisionShape3D.new()
	var sphere       := SphereShape3D.new()
	sphere.radius    = 1.1
	sphere_shape.shape = sphere
	add_child(sphere_shape)

	_build_mesh()

	_label             = preload("res://scripts/ui/screen_prompt.gd").new()
	_label.text        = "[F] Search Bag"
	_label.position    = Vector3(0, 1.0, 0)
	_label.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size   = 36
	_label.pixel_size  = 0.004
	_label.modulate    = Color(1.0, 0.9, 0.55)
	_label.visible     = false
	add_child(_label)

	body_entered.connect(_on_body_in)
	body_exited.connect(_on_body_out)

func _build_mesh() -> void:
	_bob_root = Node3D.new()
	add_child(_bob_root)

	# Try real sack mesh; vary by position hash so not every bag looks identical.
	var skin_path: String = _SACK_PATHS[hash(str(global_position)) % _SACK_PATHS.size()]
	var skin_loaded := false
	if FileAccess.file_exists(skin_path + ".import"):
		var ps := load(skin_path) as PackedScene
		if ps != null:
			var inst := ps.instantiate()
			_bob_root.add_child(inst)
			skin_loaded = true

	if not skin_loaded:
		# Fallback: procedural box + knot sphere
		var mi   := MeshInstance3D.new()
		var box  := BoxMesh.new()
		box.size  = Vector3(0.34, 0.30, 0.30)
		mi.mesh   = box
		mi.position = Vector3(0, 0.32, 0)
		var mat  := StandardMaterial3D.new()
		mat.albedo_color = Color(0.52, 0.40, 0.24)
		mat.roughness    = 0.88
		mi.material_override = mat
		_bob_root.add_child(mi)
		var knot   := MeshInstance3D.new()
		var ksph   := SphereMesh.new()
		ksph.radius   = 0.08; ksph.height = 0.16
		knot.mesh     = ksph
		knot.position = Vector3(0, 0.50, 0)
		var kmat      := StandardMaterial3D.new()
		kmat.albedo_color = Color(0.35, 0.25, 0.14)
		knot.material_override = kmat
		_bob_root.add_child(knot)

	# Gold glow ring always — players need to read this as "loot here".
	var ring_mi  := MeshInstance3D.new()
	var torus    := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.30
	ring_mi.mesh  = torus
	ring_mi.scale.y = 0.14
	ring_mi.position = Vector3(0, 0.06, 0)
	var rmat     := StandardMaterial3D.new()
	rmat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color              = Color(1.0, 0.82, 0.2)
	rmat.emission_enabled          = true
	rmat.emission                  = Color(1.0, 0.82, 0.2)
	rmat.emission_energy_multiplier = 1.5
	ring_mi.material_override = rmat
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bob_root.add_child(ring_mi)

func _process(delta: float) -> void:
	_age += delta
	if _bob_root != null:
		_bob_root.position.y = sin(_age * 2.1) * 0.05
	if despawn_after > 0.0 and _age >= despawn_after:
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and not _open and event.is_action_pressed("interact"):
		_open_bag()
		get_viewport().set_input_as_handled()

func _on_body_in(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = true
		_label.visible  = true

func _on_body_out(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = false
		_label.visible  = false

func _open_bag() -> void:
	_open          = true
	_label.visible = false
	var screen: CanvasLayer = _BagScreen.new()
	screen.gold_amount = gold_amount
	screen.items       = items.duplicate(true)
	screen.source_bag  = self
	get_tree().current_scene.add_child(screen)
	screen.closed.connect(_on_bag_closed)

func _on_bag_closed() -> void:
	_open = false
	# Auto-despawn if emptied
	if gold_amount <= 0 and items.is_empty():
		queue_free()
	elif _player_inside:
		_label.visible = true
