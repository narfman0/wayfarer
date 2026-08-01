## Floating combat text: spawns a Label3D that drifts up and fades.
class_name DamageNumber
extends RefCounted

static func spawn(scene: Node, world_pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.004
	label.outline_size = 8
	label.no_depth_test = true
	scene.add_child(label)
	label.global_position = world_pos + Vector3(randf_range(-0.3, 0.3), 1.9, 0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.2, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)

static func hit(scene: Node, world_pos: Vector3, amount: int, crit: bool = false) -> void:
	if crit:
		spawn(scene, world_pos, "%d!" % amount, Color(1.0, 0.85, 0.2))
	else:
		spawn(scene, world_pos, str(amount), Color(1.0, 0.45, 0.35))

static func miss(scene: Node, world_pos: Vector3) -> void:
	spawn(scene, world_pos, "miss", Color(0.75, 0.75, 0.8))
