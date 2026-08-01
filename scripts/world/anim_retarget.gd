## Retargets Base Locomotion (classic Polygon rig) clips onto Fantasy
## Characters skeletons: bone-name mapping plus rest-pose delta compensation.
## Position/scale tracks are dropped (different unit conventions between the
## rigs); rotation deltas from the clip rig's rest are re-applied on top of
## the target skeleton's rest rotations.
class_name AnimRetarget
extends RefCounted

## classic-rig bone → SK_Character_* bone. Unmapped bones are dropped.
const BONE_MAP := {
	"Hips": "Pelvis",
	"Spine_01": "spine_01", "Spine_02": "spine_02", "Spine_03": "spine_03",
	"Neck": "neck_01", "Head": "head",
	"Clavicle_L": "clavicle_l", "Shoulder_L": "UpperArm_L", "Elbow_L": "lowerarm_l", "Hand_L": "Hand_L",
	"Clavicle_R": "clavicle_r", "Shoulder_R": "UpperArm_R", "Elbow_R": "lowerarm_r", "Hand_R": "Hand_R",
	"UpperLeg_L": "Thigh_L", "LowerLeg_L": "calf_l", "Ankle_L": "Foot_L", "Ball_L": "ball_l", "Toes_L": "toes_l",
	"UpperLeg_R": "Thigh_R", "LowerLeg_R": "calf_r", "Ankle_R": "Foot_R", "Ball_R": "ball_r", "Toes_R": "toes_r",
}

static var _clip_cache: Dictionary = {}

## Build a retargeted Animation for `target_skeleton` (path used for tracks
## must be the path from the future AnimationPlayer root to that skeleton).
static func load_clip(glb_path: String, skeleton_path: String, target_skeleton: Skeleton3D) -> Animation:
	var cache_key := glb_path + "|" + skeleton_path
	if _clip_cache.has(cache_key):
		return _clip_cache[cache_key]
	var scene = load(glb_path)
	if scene == null:
		return null
	var inst = scene.instantiate()
	var players: Array = inst.find_children("*", "AnimationPlayer", true, false)
	var skels: Array = inst.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skels.is_empty():
		inst.free()
		return null
	var src_player: AnimationPlayer = players[0]
	var src_skel: Skeleton3D = skels[0]
	var list := src_player.get_animation_list()
	if list.is_empty():
		inst.free()
		return null
	var src: Animation = src_player.get_animation(list[0])

	var out := Animation.new()
	out.length = src.length
	out.loop_mode = Animation.LOOP_LINEAR
	for t in src.get_track_count():
		if src.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(src.track_get_path(t)).get_slice(":", 1)
		if not BONE_MAP.has(bone):
			continue
		var src_idx := src_skel.find_bone(bone)
		var dst_idx := target_skeleton.find_bone(BONE_MAP[bone])
		if src_idx < 0 or dst_idx < 0:
			continue
		var src_rest: Quaternion = src_skel.get_bone_rest(src_idx).basis.get_rotation_quaternion()
		var dst_rest: Quaternion = target_skeleton.get_bone_rest(dst_idx).basis.get_rotation_quaternion()
		var delta_fix := dst_rest * src_rest.inverse()
		var idx := out.get_track_count()
		out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(idx, "%s:%s" % [skeleton_path, BONE_MAP[bone]])
		out.track_set_interpolation_type(idx, src.track_get_interpolation_type(t))
		for k in src.track_get_key_count(t):
			var q: Quaternion = src.track_get_key_value(t, k)
			out.rotation_track_insert_key(idx, src.track_get_key_time(t, k), delta_fix * q)
	inst.free()
	_clip_cache[cache_key] = out
	return out
