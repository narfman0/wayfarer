## Graphics quality settings. Individual settings (MSAA, SSAO, SSIL,
## volumetric fog, DOF, shadow resolution) persist in user://settings.cfg;
## presets are just bundles that write them all at once. Glow, the rim rig,
## and impact lights are cheap enough to stay on everywhere. Settings apply
## per level at ready and live from the settings screen.
class_name Graphics
extends RefCounted

const _CFG := "user://settings.cfg"

## The High preset doubles as the defaults. msaa stores Viewport.MSAA_*.
const DEFAULTS := {
	"msaa": Viewport.MSAA_4X,
	"ssao": true,
	"ssil": true,
	"volumetrics": true,
	"dof": true,
	"shadow_size": 4096,
}

const PRESETS := {
	"low": {"msaa": Viewport.MSAA_DISABLED, "ssao": false, "ssil": false,
		"volumetrics": false, "dof": false, "shadow_size": 2048},
	"medium": {"msaa": Viewport.MSAA_2X, "ssao": true, "ssil": false,
		"volumetrics": true, "dof": true, "shadow_size": 4096},
	"high": DEFAULTS,
}

static func get_setting(key: String) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(_CFG) == OK:
		if cf.has_section_key("graphics", key):
			return cf.get_value("graphics", key)
		# Migration: pre-settings-screen configs stored only a tier name.
		var tier: String = cf.get_value("graphics", "tier", "")
		if tier in PRESETS:
			return PRESETS[tier].get(key, DEFAULTS[key])
	return DEFAULTS[key]

static func set_setting(key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(_CFG)  # keep other sections/keys
	cf.set_value("graphics", key, value)
	cf.save(_CFG)

static func apply_preset(preset: String) -> void:
	if not preset in PRESETS:
		return
	for key: String in PRESETS[preset]:
		set_setting(key, PRESETS[preset][key])

## Which preset the stored settings match exactly, or "custom".
static func current_preset() -> String:
	for preset: String in PRESETS:
		var hit := true
		for key: String in PRESETS[preset]:
			if get_setting(key) != PRESETS[preset][key]:
				hit = false
				break
		if hit:
			return preset
	return "custom"

## Apply the persisted settings to a running level's rendering surfaces.
## env is the level's ACTIVE Environment (post-atmosphere duplicate);
## attrs may be null on scenes without the iso camera.
static func apply(viewport: Viewport, env: Environment,
		attrs: CameraAttributesPractical) -> void:
	viewport.msaa_3d = get_setting("msaa")
	RenderingServer.directional_shadow_atlas_set_size(get_setting("shadow_size"), true)
	if env != null:
		env.ssao_enabled = get_setting("ssao")
		env.ssil_enabled = get_setting("ssil")
		env.volumetric_fog_enabled = get_setting("volumetrics")
	if attrs != null:
		attrs.dof_blur_far_enabled = get_setting("dof")
		attrs.dof_blur_near_enabled = get_setting("dof")
