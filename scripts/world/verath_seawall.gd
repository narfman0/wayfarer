## The Seawall — Verath part 2. Two beats: a glimpse of Cael at the far
## crane (StoryEvent), and SARRO'S PORTAL — a tear that resonates with his
## sister's trace. Walking up to it starts the choice dialogue
## (dialogue/sarro_portal.dialogue) once, ever; the flag it sets is one of the
## six meaningful choices (overview.md).
class_name VerathSeawallScene
extends WayfarerLevel

func _on_level_ready() -> void:
	super._on_level_ready()
	var tear := get_node_or_null("Level/SarrosTear")
	if tear == null:
		return
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape.shape = sphere
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 1
	tear.add_child(area)
	area.body_entered.connect(_on_tear_approached)

func _on_tear_approached(body: Node3D) -> void:
	if not body.is_in_group("players") or GameState.get_flag("sarro_portal") != null \
			or GameState.has_flag("sarro_portal_seen"):
		return
	GameState.set_flag("sarro_portal_seen")  # guard against re-trigger while talking
	_player.set_control_enabled(false)
	DialogueManager.show_dialogue_balloon(
		load("res://dialogue/sarro_portal.dialogue"), "portal")
	await DialogueManager.dialogue_ended
	_player.set_control_enabled(true)
