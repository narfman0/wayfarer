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

var _body: CharacterBody3D = null  # null → static idle (NPCs)
var _ap: AnimationPlayer
var _current := ""

## Build an animator under `skin` (a Synty character GLB instance).
## body: pass the CharacterBody3D to drive idle/run from velocity, or null.
static func attach(skin: Node, body: CharacterBody3D = null, set_key: String = "masc") -> CharacterAnimator:
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
	anim._ap.add_animation_library("", lib)
	anim._play("idle")
	return anim

func _process(_delta: float) -> void:
	if _body == null:
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	_play("run" if speed > 0.5 else "idle")

func _play(clip_name: String) -> void:
	if _current == clip_name or _ap == null or not _ap.has_animation(clip_name):
		return
	_current = clip_name
	_ap.play(clip_name, 0.2)
