extends Control
## Title screen: neon YARBELL wordmark with Play and Options. Play resets state
## and loads the game; Options opens the shared options modal.

const OptionsModalScene := preload("res://scenes/ui/options_modal.tscn")

var _options

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 28)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "YARBELL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Palette.CYAN)
	title.add_theme_color_override("font_outline_color", Palette.MAGENTA)
	title.add_theme_constant_override("outline_size", 8)
	vb.add_child(title)

	vb.add_child(_menu_button("PLAY", _on_play))
	vb.add_child(_menu_button("OPTIONS", _on_options))

	_options = OptionsModalScene.instantiate()
	_options.show_gear = false
	add_child(_options)

func _on_play() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_options() -> void:
	_options.open()

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260.0, 56.0)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Palette.CYAN)
	b.add_theme_stylebox_override("normal", _btn_style(0.12))
	b.add_theme_stylebox_override("hover", _btn_style(0.25))
	b.add_theme_stylebox_override("pressed", _btn_style(0.4))
	b.pressed.connect(cb)
	return b

func _btn_style(fill: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, fill)
	s.set_border_width_all(2)
	s.border_color = Palette.CYAN
	s.set_corner_radius_all(10)
	s.set_content_margin_all(10)
	return s
