## Retargets Base Locomotion (classic Polygon rig) clips onto Fantasy
## Characters skeletons. Position/scale tracks are dropped (different unit
## conventions between the rigs); rotations are retargeted per joint.
##
## For each mapped bone we take the clip's motion as a delta from the source
## rig's T-pose rest, expressed in that bone's LOCAL frame, then rotate that
## delta into the DESTINATION bone's local frame before laying it on top of
## the target rest. The frame change matters because the two rigs orient their
## bone-local axes ~90° apart; skipping it (an earlier version did) applied
## every rotation around the wrong axis and corkscrewed the whole skeleton.
##
##   delta_src = src_rest⁻¹ · q                       (delta from rest, src frame)
##   delta_dst = C · delta_src · C⁻¹,  C = G_dst⁻¹ · G_src   (reframe into dst)
##   q_out     = dst_rest · delta_dst                 (dst local pose rotation)
##
## where src_rest/dst_rest are LOCAL rest rotations and G_src/G_dst are the
## bones' GLOBAL (world) rest rotations. Both rigs have unmirrored, unit-scale
## rests, so quaternion extraction from the accumulated global bases is valid.
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

## True T-pose rest rotations of the classic rig, from the animation pack's
## reference character. The clip GLBs' own skeleton rests are baked to the
## animation stance (Blender export), so they can't serve as the reference.
const REF_CHARACTER := "res://assets/meshes/ANIMATION_Base_Locomotion_SourceFiles_v3/SourceFiles/Character/PolygonSyntyCharacter.glb"

static var _clip_cache: Dictionary = {}
static var _ref_rests: Dictionary = {}         # bone name → LOCAL rest quaternion
static var _ref_global_rests: Dictionary = {}  # bone name → GLOBAL rest quaternion

## Global (world-space) rest rotation of a bone: accumulate local rest bases up
## the parent chain. Safe as a quaternion here because every rest basis is an
## unmirrored rotation with unit scale (verified for both rigs).
static func _global_rest_quat(skel: Skeleton3D, idx: int) -> Quaternion:
	var b: Basis = skel.get_bone_rest(idx).basis
	var p := skel.get_bone_parent(idx)
	while p >= 0:
		b = skel.get_bone_rest(p).basis * b
		p = skel.get_bone_parent(p)
	return b.orthonormalized().get_rotation_quaternion()

static func _load_reference() -> void:
	if not _ref_rests.is_empty():
		return
	var inst = load(REF_CHARACTER).instantiate()
	var skels: Array = inst.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		inst.free()
		return
	var skel: Skeleton3D = skels[0]
	for i in skel.get_bone_count():
		var name := skel.get_bone_name(i)
		_ref_rests[name] = skel.get_bone_rest(i).basis.get_rotation_quaternion()
		_ref_global_rests[name] = _global_rest_quat(skel, i)
	inst.free()

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

	_load_reference()

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
		if not _ref_rests.has(bone):
			continue
		var src_rest: Quaternion = _ref_rests[bone]
		var src_global: Quaternion = _ref_global_rests[bone]
		var dst_rest: Quaternion = target_skeleton.get_bone_rest(dst_idx).basis.get_rotation_quaternion()
		var dst_global: Quaternion = _global_rest_quat(target_skeleton, dst_idx)
		# Change-of-basis that carries a source-bone-local rotation into the
		# destination bone's local frame (see class comment).
		var c := dst_global.inverse() * src_global
		var c_inv := c.inverse()
		var idx := out.get_track_count()
		out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(idx, "%s:%s" % [skeleton_path, BONE_MAP[bone]])
		out.track_set_interpolation_type(idx, src.track_get_interpolation_type(t))
		for k in src.track_get_key_count(t):
			var q: Quaternion = src.track_get_key_value(t, k)
			var delta_src := src_rest.inverse() * q
			var q_out := dst_rest * (c * delta_src * c_inv)
			out.rotation_track_insert_key(idx, src.track_get_key_time(t, k), q_out)
	inst.free()
	_clip_cache[cache_key] = out
	return out
