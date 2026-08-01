## Stable tear / shrine — press F to rest: full party heal.
## The setting's rest rule (setting-classes.md): recovery happens at
## stable tears, welding resource pacing to the world structure.
class_name RestPoint
extends Node3D

@export var display_name: String = "Stable Tear"

var _player_near := false
var _prompt: Label3D

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	mesh.mesh = torus
	mesh.position.y = 0.9
	mesh.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.95, 0.7)
	mat.emission_energy_multiplier = 1.6
	mesh.material_override = mat
	add_child(mesh)

	_prompt = Label3D.new()
	_prompt.position = Vector3(0, 2.2, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 44
	_prompt.pixel_size = 0.004
	_prompt.text = "[F] Rest — %s" % display_name
	_prompt.visible = false
	add_child(_prompt)

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	shape.shape = sphere
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		_rest()

func _rest() -> void:
	for c in GameState.party():
		c.stats.current_hp = c.stats.max_hp
	_prompt.text = "The current steadies you."
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_instance_valid(_prompt):
			_prompt.text = "[F] Rest — %s" % display_name)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = true
		_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_near = false
		_prompt.visible = false
