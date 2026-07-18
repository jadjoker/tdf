extends RefCounted

# Murmuration's shared UI look, built entirely in code (no theme assets).
# Principle: dark translucent panels, thin accent borders that go HDR on
# hover/focus so the glow environment makes interactive elements bloom.

const TEXT := Color(0.85, 0.92, 1.0)
const TEXT_DIM := Color(0.58, 0.65, 0.76)
const BG := Color(0.045, 0.06, 0.11, 0.92)
const BG_HOVER := Color(0.07, 0.10, 0.17, 0.95)

const MINT := Color(0.55, 2.4, 1.3)      # the game's signature accent
const GOLD := Color(2.2, 1.8, 0.6)
const VIOLET := Color(1.8, 0.7, 2.2)


static func dim(accent: Color, f: float = 0.45) -> Color:
	return Color(accent.r * f, accent.g * f, accent.b * f, 1.0)


static func box(bg: Color, border: Color, border_w: int = 1, radius: int = 10, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func style_button(btn: Button, accent: Color, font_size: int = 20) -> void:
	btn.add_theme_stylebox_override("normal", box(BG, dim(accent), 1))
	btn.add_theme_stylebox_override("hover", box(BG_HOVER, accent, 2))
	btn.add_theme_stylebox_override("pressed", box(Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.95), accent, 2))
	btn.add_theme_stylebox_override("focus", box(BG_HOVER, accent, 2))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)


static func style_slider(s: HSlider, accent: Color) -> void:
	var track := box(Color(0.10, 0.13, 0.20), Color(0.2, 0.26, 0.36), 1, 4, 0)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	var fill := box(dim(accent, 0.8), dim(accent, 0.8), 0, 4, 0)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)


static func outline(lbl: Label, size: int = 6) -> void:
	lbl.add_theme_constant_override("outline_size", size)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.85))


static func centered_panel(accent: Color) -> PanelContainer:
	# Anchored center + grow-both = stays centered while sizing to content
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(BG, dim(accent, 0.6), 1, 14, 26))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	return panel


static func add_vignette(parent: Node, strength: float = 0.42) -> void:
	# Soft radial darkening — pulls focus to the center, deepens the neon
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = %f;
void fragment() {
	float d = length(UV - vec2(0.5)) * 1.4142;
	COLOR = vec4(0.0, 0.0, 0.02, smoothstep(0.55, 1.05, d) * strength);
}""" % strength
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	parent.add_child(rect)
