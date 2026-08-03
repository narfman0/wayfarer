## Ambush zone (A2): the listed enemies vanish at load and spring — visible,
## hostile, already alerted — the moment the player crosses this Area3D.
## Place under Level, size via the child CollisionShape3D (a default 4 m
## sphere is created when the scene provides none).
class_name AmbushTrigger
extends Area3D

## EnemyController nodes that lie in wait.
@export var ambushers: Array[NodePath] = []

var _sprung := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # player layer
	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 4.0
		shape.shape = sphere
		add_child(shape)
	body_entered.connect(_on_body_entered)
	# Hide after the enemies' own _ready has run (they register groups there).
	_hide_ambushers.call_deferred()

func _hide_ambushers() -> void:
	for path in ambushers:
		var e := get_node_or_null(path)
		if e != null and e.has_method("ambush_hide"):
			e.ambush_hide()

func _on_body_entered(body: Node3D) -> void:
	if _sprung or not body.is_in_group("players"):
		return
	_sprung = true
	for path in ambushers:
		var e := get_node_or_null(path)
		if e != null and e.has_method("ambush_activate"):
			e.ambush_activate(body as CharacterBody3D)
	set_deferred("monitoring", false)
