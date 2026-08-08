## Wayfarer UI Theme — builds and exposes a shared Theme resource.
## Add UITheme as an autoload (singleton).  Every UI node that calls
##   self.theme = UITheme.theme
## or is a descendant of a node that does so will pick up the fantasy styling.
extends Node

## The shared theme — built once at startup.
var theme: Theme

## Colour palette
const C_BG        := Color(0.06, 0.05, 0.08, 0.96)   # near-black panel
const C_BG_LIGHT  := Color(0.10, 0.08, 0.14, 0.96)   # slightly lighter panels
const C_BORDER    := Color(0.62, 0.50, 0.28)           # antique gold border
const C_BORDER_DIM:= Color(0.38, 0.30, 0.15, 0.7)     # dimmed border (inactive)
const C_GOLD      := Color(1.00, 0.85, 0.35)           # gold text / labels
const C_BODY      := Color(0.88, 0.82, 0.72)           # parchment body text
const C_MUTED     := Color(0.55, 0.52, 0.48)           # muted / secondary text
const C_HP        := Color(0.20, 0.72, 0.38)           # health green
const C_HP_BG     := Color(0.10, 0.18, 0.12)           # health bar trough
const C_FOCUS     := Color(0.75, 0.60, 0.30, 0.55)    # hover / focus highlight
const C_PRESS     := Color(0.50, 0.38, 0.14, 0.80)    # pressed state

func _ready() -> void:
	theme = _build()

func _build() -> Theme:
	var t := Theme.new()

	var fnt_head := _load_font("res://assets/fonts/Cinzel-Regular.ttf")
	var fnt_body := _load_font("res://assets/fonts/CrimsonPro-Regular.ttf")

	# ── Default font ─────────────────────────────────────────────────────────
	if fnt_body != null:
		t.default_font      = fnt_body
		t.default_font_size = 15

	# ── Panel ────────────────────────────────────────────────────────────────
	t.set_stylebox("panel", "Panel", _panel_box(C_BG, C_BORDER, 2, 4))

	# ── PanelContainer ────────────────────────────────────────────────────────
	t.set_stylebox("panel", "PanelContainer", _panel_box(C_BG, C_BORDER, 2, 4))

	# ── Label ────────────────────────────────────────────────────────────────
	if fnt_body != null:
		t.set_font("font",      "Label", fnt_body)
		t.set_font_size("font_size", "Label", 15)
	t.set_color("font_color",         "Label", C_BODY)
	t.set_color("font_shadow_color",  "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	# ── Button ────────────────────────────────────────────────────────────────
	if fnt_head != null:
		t.set_font("font",      "Button", fnt_head)
		t.set_font_size("font_size", "Button", 14)
	t.set_color("font_color",          "Button", C_GOLD)
	t.set_color("font_hover_color",    "Button", C_GOLD.lightened(0.15))
	t.set_color("font_pressed_color",  "Button", C_GOLD.darkened(0.15))
	t.set_color("font_disabled_color", "Button", C_MUTED)
	t.set_stylebox("normal",   "Button", _btn_box(C_BG_LIGHT, C_BORDER,    2, 4))
	t.set_stylebox("hover",    "Button", _btn_box(C_FOCUS,    C_BORDER,    2, 4))
	t.set_stylebox("pressed",  "Button", _btn_box(C_PRESS,    C_BORDER_DIM,2, 4))
	t.set_stylebox("disabled", "Button", _btn_box(C_BG,       C_BORDER_DIM,1, 4))
	t.set_stylebox("focus",    "Button", _empty_box())

	# ── ProgressBar (HP / enemy bars) ─────────────────────────────────────────
	t.set_stylebox("background", "ProgressBar", _panel_box(C_HP_BG, C_BORDER_DIM, 1, 2))
	t.set_stylebox("fill",       "ProgressBar", _fill_box(C_HP))
	t.set_color("font_color", "ProgressBar", C_BODY)

	# ── ScrollContainer ───────────────────────────────────────────────────────
	t.set_stylebox("panel", "ScrollContainer", _panel_box(Color(0,0,0,0), Color(0,0,0,0), 0, 0))

	# ── LineEdit ─────────────────────────────────────────────────────────────
	if fnt_body != null:
		t.set_font("font", "LineEdit", fnt_body)
	t.set_stylebox("normal", "LineEdit", _panel_box(C_BG_LIGHT, C_BORDER, 1, 3))
	t.set_color("font_color",           "LineEdit", C_BODY)
	t.set_color("font_placeholder_color","LineEdit", C_MUTED)
	t.set_color("caret_color",          "LineEdit", C_GOLD)
	t.set_color("selection_color",      "LineEdit", C_FOCUS)

	# ── HSeparator ────────────────────────────────────────────────────────────
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER_DIM
	sep_style.set_content_margin_all(1)
	t.set_stylebox("separator", "HSeparator", sep_style)

	return t

# ── StyleBox helpers ─────────────────────────────────────────────────────────

static func _panel_box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(6)
	return s

static func _btn_box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin(SIDE_LEFT,  12)
	s.set_content_margin(SIDE_RIGHT, 12)
	s.set_content_margin(SIDE_TOP,   6)
	s.set_content_margin(SIDE_BOTTOM,6)
	return s

static func _fill_box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	s.set_content_margin_all(0)
	return s

static func _empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

# ── Font loader ───────────────────────────────────────────────────────────────

static func _load_font(path: String) -> FontFile:
	if not FileAccess.file_exists(path):
		return null
	return load(path) as FontFile
