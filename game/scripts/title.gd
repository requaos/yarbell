extends Control
## Title screen: neon YARBELL wordmark with Play and Options. Play opens the
## game-selection screen; Options opens the shared options modal.

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

	vb.add_child(NeonUI.menu_button("PLAY", _on_play))
	vb.add_child(NeonUI.menu_button("OPTIONS", _on_options))

	_options = OptionsModalScene.instantiate()
	_options.show_gear = false
	add_child(_options)

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/select.tscn")

func _on_options() -> void:
	_options.open()
