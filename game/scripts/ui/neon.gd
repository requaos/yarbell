class_name NeonUI
extends RefCounted
## Shared neon UI widget factory. Used by the title and game-select menus so the
## menu look is defined in one place. Lifted from the original title.gd helpers.

const _BTN_SIZE := Vector2(260.0, 56.0)

## A live neon menu button wired to `cb`.
static func menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = _BTN_SIZE
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Palette.CYAN)
	b.add_theme_stylebox_override("normal", button_style(0.12))
	b.add_theme_stylebox_override("hover", button_style(0.25))
	b.add_theme_stylebox_override("pressed", button_style(0.4))
	b.pressed.connect(cb)
	return b

## A dimmed, non-interactive button — used for games that aren't built yet.
static func disabled_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = _BTN_SIZE
	b.disabled = true
	b.add_theme_font_size_override("font_size", 30)
	var dim := Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.35)
	b.add_theme_color_override("font_color", dim)
	b.add_theme_color_override("font_disabled_color", dim)
	var s := button_style(0.05)
	s.border_color = dim
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("disabled", s)
	return b

static func button_style(fill: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, fill)
	s.set_border_width_all(2)
	s.border_color = Palette.CYAN
	s.set_corner_radius_all(10)
	s.set_content_margin_all(10)
	return s
