## Graphics quality tiers. The lighting stack (MSAA, SSAO/SSIL, volumetric
## fog, DOF, shadow resolution) scales across low/medium/high; glow, the rim
## rig, and impact lights are cheap enough to keep everywhere. The tier
## persists in user://settings.cfg and applies per level at ready (and live
## from the pause menu).
class_name Graphics
extends RefCounted

const TIERS: Array[String] = ["low", "medium", "high"]
const _CFG := "user://settings.cfg"

static func tier() -> String:
	var cf := ConfigFile.new()
	if cf.load(_CFG) == OK:
		var t: String = cf.get_value("graphics", "tier", "high")
		if t in TIERS:
			return t
	return "high"

static func set_tier(t: String) -> void:
	if not t in TIERS:
		return
	var cf := ConfigFile.new()
	cf.load(_CFG)  # keep other sections if present
	cf.set_value("graphics", "tier", t)
	cf.save(_CFG)

static func next_tier() -> String:
	var t := TIERS[(TIERS.find(tier()) + 1) % TIERS.size()]
	set_tier(t)
	return t

## Apply the persisted tier to a running level's rendering surfaces.
## env is the level's ACTIVE Environment (post-atmosphere duplicate);
## attrs may be null on scenes without the iso camera.
static func apply(viewport: Viewport, env: Environment,
		attrs: CameraAttributesPractical) -> void:
	match tier():
		"low":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			if env != null:
				env.ssao_enabled = false
				env.ssil_enabled = false
				env.volumetric_fog_enabled = false
			if attrs != null:
				attrs.dof_blur_far_enabled = false
				attrs.dof_blur_near_enabled = false
		"medium":
			viewport.msaa_3d = Viewport.MSAA_2X
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			if env != null:
				env.ssao_enabled = true
				env.ssil_enabled = false
				env.volumetric_fog_enabled = true
			if attrs != null:
				attrs.dof_blur_far_enabled = true
				attrs.dof_blur_near_enabled = true
		"high":
			viewport.msaa_3d = Viewport.MSAA_4X
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			if env != null:
				env.ssao_enabled = true
				env.ssil_enabled = true
				env.volumetric_fog_enabled = true
			if attrs != null:
				attrs.dof_blur_far_enabled = true
				attrs.dof_blur_near_enabled = true
