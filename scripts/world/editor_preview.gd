@tool
## Editor-only WYSIWYG preview: generates the same procedural layers the game
## builds at load — scenery scatter/backdrop (Scenery.RECIPES), the plane's
## sun override, and ambient motes — so the editor viewport matches runtime.
##
## Preview children are created with no owner, so NOTHING here is ever saved
## into the scene file; the node is inert in a running game (the level base
## does the real generation). Toggle `refresh` after moving props to
## re-scatter around their new positions (same seed → same layout).
class_name EditorPreview
extends Node3D

const _Scenery    = preload("res://scripts/world/scenery.gd")
const _Atmosphere = preload("res://scripts/world/atmosphere.gd")

## Must match the scene root's plane_id (the root's script isn't running in
## the editor, so this can't always be read from it reliably).
@export var plane_id: String = "tamori"

## Tick to regenerate the preview (checkbox acts as a button).
@export var refresh: bool = false:
	set(_v):
		if Engine.is_editor_hint():
			_regenerate.call_deferred()

func _ready() -> void:
	if Engine.is_editor_hint():
		_regenerate.call_deferred()

func _regenerate() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for child in get_children():
		child.free()
	var root := get_parent()
	if root == null:
		return
	var ground := root.get_node_or_null("Level/Ground/GroundMesh") as MeshInstance3D
	# Scenery is opt-in per scene now (generate_scenery, default false) —
	# only preview it when the scene will actually generate it at runtime,
	# or the editor would show dressing the game doesn't have. The root's
	# export is readable via its placeholder script instance.
	if root.get("generate_scenery") == true:
		# Scenery parents a "Scenery" node under whatever it's given — give
		# it this preview node so children stay owner-less (unserialized).
		_Scenery.generate(self, ground, _Scenery.avoid_points_for(root),
			_Scenery.clear_centers_for(root), plane_id)
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	_Atmosphere.apply(self, plane_id, sun, ground)
