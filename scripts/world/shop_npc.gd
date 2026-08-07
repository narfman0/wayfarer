## A world-space shop trigger: Area3D that prompts [F] Shop when the player is near.
## Add as a child of the Level node; position it at the merchant's feet.
class_name ShopNPC
extends Area3D

const _ShopScreen = preload("res://scripts/ui/shop_screen.gd")

@export var npc_name: String  = "Merchant"
@export var interact_radius: float = 2.0

var _label: Label3D
var _player_inside: bool = false
var _shop_open: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interact_radius
	shape.shape = sphere
	add_child(shape)

	# Floating prompt label
	_label = Label3D.new()
	_label.text      = "[F] Shop  (%s)" % npc_name
	_label.position  = Vector3(0, 2.4, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 38
	_label.pixel_size = 0.004
	_label.modulate  = Color(1.0, 0.9, 0.55)
	_label.visible   = false
	add_child(_label)

	const _NPC_SKIN := "res://assets/meshes/POLYGON_Fantasy_Characters_SourceFiles_v3/Source_Files/Characters/Unreal_Characters/SK_Chr_Female_Gypsy.gltf"
	var skin_scene = load(_NPC_SKIN) if ResourceLoader.exists(_NPC_SKIN) else null
	if skin_scene != null:
		var mi: Node3D = skin_scene.instantiate()
		add_child(mi)
	else:
		var mi := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.height = 1.8; cap.radius = 0.35
		mi.mesh = cap
		mi.position = Vector3(0, 0.9, 0)
		add_child(mi)

	body_entered.connect(_on_body_in)
	body_exited.connect(_on_body_out)

func _on_body_in(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = true
		_label.visible  = true

func _on_body_out(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = false
		_label.visible  = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and not _shop_open \
			and event.is_action_pressed("interact"):
		_open_shop()
		get_viewport().set_input_as_handled()

func _open_shop() -> void:
	if _shop_open:
		return
	_shop_open = true
	_label.visible = false
	var player := get_tree().get_first_node_in_group("players")
	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	var screen: CanvasLayer = _ShopScreen.new()
	get_tree().current_scene.add_child(screen)
	screen.closed.connect(_on_shop_closed)

func _on_shop_closed() -> void:
	_shop_open = false
	var player := get_tree().get_first_node_in_group("players")
	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(true)
	if _player_inside:
		_label.visible = true
