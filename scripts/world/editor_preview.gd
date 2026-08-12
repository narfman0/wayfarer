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
const _Platform   = preload("res://scripts/world/platform_terrain.gd")

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

	# Platform-terrain preview: owner-less duplicate hovering just above the
	# saved slab so the editor shows the runtime fragment without touching
	# (or serializing) the real GroundMesh.
	if root.get("platform_terrain") == true and ground != null and ground.mesh is BoxMesh:
		var box: BoxMesh = ground.mesh
		var albedo := Color(0.3, 0.3, 0.32)
		var surf := ground.get_surface_override_material(0)
		if surf is StandardMaterial3D:
			albedo = (surf as StandardMaterial3D).albedo_color
		var style: Dictionary = _Platform.style_for(plane_id)
		var mat: ShaderMaterial = _Platform.grid_material(albedo, style["color"], style["strength"])
		var mi := MeshInstance3D.new()
		mi.mesh = _Platform.build_platform(box.size.x, box.size.z, hash(plane_id))
		mi.material_override = mat
		mi.global_transform = ground.global_transform
		mi.position.y += 0.12  # cover the slab's top face in the viewport
		add_child(mi)
		var walkable: bool = root.get("platform_walkable_pads") == true
		var hx := box.size.x * 0.5
		var hz := box.size.z * 0.5
		var idx := 0
		for child in root.get_node("Level").get_children():
			if not (child is Node3D) or child.get("target_plane") == null:
				continue
			var p: Vector3 = (child as Node3D).position
			var pad_center: Vector3
			var edge: Vector3
			if walkable:
				var east_west := absf(p.x) >= absf(p.z)
				var s := signf(p.x) if east_west else signf(p.z)
				var h := hx if east_west else hz
				var at := clampf(p.z if east_west else p.x, -(h - 6.0), h - 6.0)
				var pad_w := s * (h + 7.5)
				pad_center = Vector3(pad_w, 0, at) if east_west else Vector3(at, 0, pad_w)
				edge = Vector3(s * h, 0, at) if east_west else Vector3(at, 0, s * h)
			else:
				var outward := Vector3(p.x, 0.0, p.z).normalized()
				pad_center = p + outward * 7.0
				edge = p + outward * 0.5
			add_child(_Platform.pad(pad_center + Vector3(0, 0.12, 0), 7.0,
				hash(plane_id) + idx, mat, walkable))
			add_child(_Platform.causeway(edge + Vector3(0, 0.12, 0),
				pad_center + Vector3(0, 0.12, 0), mat))
			idx += 1
