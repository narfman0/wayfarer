## Drop-in replacement for interaction-prompt Label3Ds. World text rendered
## in 3D goes soft under the tilt-shift DOF and minifies into mush at wide
## zoom; this keeps the Label3D API every caller already uses (.text,
## .visible, .modulate, world position) but draws a crisp screen-space Label
## at the unprojected position instead. The 3D label itself is shrunk to
## invisibility; the proxy lives on its own CanvasLayer.
class_name ScreenPrompt
extends Label3D

var _canvas: CanvasLayer
var _proxy: Label

func _ready() -> void:
	pixel_size = 0.00001  # the 3D glyph quad is effectively invisible
	_canvas = CanvasLayer.new()
	_canvas.layer = 50
	add_child(_canvas)
	_proxy = Label.new()
	_proxy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_proxy.add_theme_font_size_override("font_size", clampi(font_size / 3, 13, 20))
	_proxy.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_proxy.add_theme_constant_override("outline_size", 6)
	_proxy.visible = false
	_canvas.add_child(_proxy)

func _process(_delta: float) -> void:
	if _proxy == null:
		return
	var cam := get_viewport().get_camera_3d()
	var show := visible and cam != null and is_inside_tree()
	if show:
		# behind-camera guard (ortho rarely, but cheap)
		show = not cam.is_position_behind(global_position)
	_proxy.visible = show
	if show:
		_proxy.text = text
		_proxy.modulate = modulate
		var sp := cam.unproject_position(global_position)
		_proxy.position = sp - Vector2(_proxy.size.x * 0.5, _proxy.size.y)
