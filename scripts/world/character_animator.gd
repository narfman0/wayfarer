## Plays retargeted Base Locomotion clips on a character's Synty skin.
## Attach via setup(); switches idle/run from the parent body's velocity.
class_name CharacterAnimator
extends Node

const _Retarget = preload("res://scripts/world/anim_retarget.gd")

const _ANIM_ROOT := "res://assets/meshes/ANIMATION_Base_Locomotion_SourceFiles_v3/SourceFiles/Animations/Polygon/"
const CLIPS := {
	"masc": {
		"idle": _ANIM_ROOT + "Masculine/Idle/A_Idle_Standing_Masc.glb",
		"run": _ANIM_ROOT + "Masculine/Locomotion/Run/A_Run_F_Masc.glb",
	},
	"femn": {
		"idle": _ANIM_ROOT + "Feminine/Idle/A_Idle_Standing_Femn.glb",
		"run": _ANIM_ROOT + "Feminine/Locomotion/Run/A_Run_F_Femn.glb",
	},
}

## Sword Combat pack one-shots, shared by every humanoid (neutral rig).
## Full res:// literals on purpose — fetch_assets.sh's used-only scan picks
## up complete assets/meshes paths anywhere in the project.
const COMBAT_CLIPS := {
	"attack": "res://assets/meshes/ANIMATION_Sword_Combat_SourceFiles_v5/SourceFiles/Animations/Polygon/Attack/LightCombo01/A_Attack_LightCombo01A_Sword.gltf",
	"attack_heavy": "res://assets/meshes/ANIMATION_Sword_Combat_SourceFiles_v5/SourceFiles/Animations/Polygon/Attack/HeavyCombo01/A_Attack_HeavyCombo01A_Sword.gltf",
	"hit": "res://assets/meshes/ANIMATION_Sword_Combat_SourceFiles_v5/SourceFiles/Animations/Polygon/Hit/HitReact/A_Hit_F_React_Sword.gltf",
	"death": "res://assets/meshes/ANIMATION_Sword_Combat_SourceFiles_v5/SourceFiles/Animations/Polygon/Death/A_Death_F_01_Sword.gltf",
}

## Marks a skin whose 180° facing correction has been applied, and caches the
## animator built for it. Both guards keep attach() idempotent — the spin is a
## relative `+= PI`, so a second call would cancel it and render the character
## back-to-front (and stack a second AnimationPlayer on the skin).
const _SPUN_META := "wayfarer_skin_spun"
const _ANIM_META := "wayfarer_animator"

var _body: CharacterBody3D = null  # null → static idle (NPCs)
var _ap: AnimationPlayer
var _current := ""
var _oneshot_until_ms := 0  # locomotion won't stomp a playing combat clip

## Build an animator under `skin` (a Synty character GLB instance).
## body: pass the CharacterBody3D to drive idle/run from velocity, or null.
## Safe to call more than once per skin — repeat calls return the first animator.
static func attach(skin: Node, body: CharacterBody3D = null, set_key: String = "masc") -> CharacterAnimator:
	if skin.has_meta(_ANIM_META):
		return skin.get_meta(_ANIM_META) as CharacterAnimator
	_orient_skin(skin)
	var skels: Array = skin.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var anim := CharacterAnimator.new()
	anim._body = body
	anim._ap = AnimationPlayer.new()
	skin.add_child(anim._ap)
	skin.add_child(anim)
	var skel_path := str(skin.get_path_to(skels[0]))
	var lib := AnimationLibrary.new()
	for clip_name in CLIPS[set_key]:
		var clip: Animation = _Retarget.load_clip(CLIPS[set_key][clip_name], skel_path, skels[0])
		if clip != null:
			lib.add_animation(clip_name, clip)
	for clip_name in COMBAT_CLIPS:
		var clip: Animation = _Retarget.load_clip(COMBAT_CLIPS[clip_name], skel_path, skels[0])
		if clip != null:
			lib.add_animation(clip_name, clip)
	anim._ap.add_animation_library("", lib)
	anim._play("idle")
	skin.set_meta(_ANIM_META, anim)
	return anim

## Fire-and-forget combat clip on a body's skin ("attack", "attack_heavy",
## "hit", "death"). Returns false when the body has no animator or the clip
## didn't load (callers keep their procedural fallback in that case).
static func oneshot(body: Node, clip_name: String) -> bool:
	if body == null:
		return false
	var skin := body.get_node_or_null("Skin")
	if skin == null or not skin.has_meta(_ANIM_META):
		return false
	var anim := skin.get_meta(_ANIM_META) as CharacterAnimator
	if anim == null:
		return false
	return anim.play_oneshot(clip_name)

## Synty POLYGON meshes are authored facing +Z, but Godot's facing/movement
## convention is -Z forward (see PlayerController's atan2 yaw). Left as-is the
## skin shows its back; spin it 180° so the visible front matches body facing.
## Guarded by meta so it lands exactly once even if attach() bails early below
## (a skin with no Skeleton3D still needs the correct facing).
static func _orient_skin(skin: Node) -> void:
	if not (skin is Node3D) or skin.has_meta(_SPUN_META):
		return
	(skin as Node3D).rotation.y += PI
	skin.set_meta(_SPUN_META, true)

func _process(_delta: float) -> void:
	if _body == null or Time.get_ticks_msec() < _oneshot_until_ms:
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	_play("run" if speed > 0.5 else "idle")

## Play a combat clip once, then let locomotion resume. "death" locks the
## animator on its final frame forever (the collapse owns what follows).
func play_oneshot(clip_name: String) -> bool:
	if _ap == null or not _ap.has_animation(clip_name):
		return false
	var length := _ap.get_animation(clip_name).get_length()
	_current = clip_name
	_ap.play(clip_name, 0.1)
	if clip_name == "death":
		_oneshot_until_ms = Time.get_ticks_msec() + 3600 * 1000
	else:
		_oneshot_until_ms = Time.get_ticks_msec() + int(length * 1000.0) - 80
	return true

func _play(clip_name: String) -> void:
	if _current == clip_name or _ap == null or not _ap.has_animation(clip_name):
		return
	_current = clip_name
	_ap.play(clip_name, 0.2)
