extends CanvasLayer
## Reusable options modal used by both the title screen and the in-game HUD.
## Sliders control game brightness, music volume and SFX volume. Opening it
## pauses the tree; the node processes while paused. If `show_gear` is true it
## also draws a gear button on the UI edge that opens the modal.

@export var show_gear := true

var _overlay: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	if show_gear:
		var gear := Button.new()
		gear.text = "⚙"
		gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		gear.offset_left = -72.0
		gear.offset_top = 84.0
		gear.offset_right = -16.0
		gear.offset_bottom = 140.0
		gear.add_theme_font_size_override("font_size", 30)
		gear.add_theme_color_override("font_color", Palette.CYAN)
		gear.add_theme_stylebox_override("normal", _panel_style())
		gear.add_theme_stylebox_override("hover", _panel_style())
		gear.add_theme_stylebox_override("pressed", _panel_style())
		gear.pressed.connect(open)
		root.add_child(gear)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440.0, 0.0)
	panel.add_theme_stylebox_override("panel", _modal_style())
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Palette.CYAN)
	vb.add_child(title)

	vb.add_child(_slider("BRIGHTNESS", 0.5, 2.0, GameState.brightness, 0.05,
		func(v: float) -> void:
			GameState.brightness = v
			var g := get_tree().get_first_node_in_group("game")
			if g and g.has_method("set_brightness"):
				g.set_brightness(v)))
	vb.add_child(_slider("MUSIC VOLUME", 0.0, 1.0, 0.5, 0.05,
		func(v: float) -> void: Audio.set_music_volume(v)))
	vb.add_child(_slider("SFX VOLUME", 0.0, 1.0, 0.8, 0.05,
		func(v: float) -> void: Audio.set_sfx_volume(v)))

	var close := Button.new()
	close.text = "CLOSE"
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(_close)
	vb.add_child(close)

func open() -> void:
	_overlay.visible = true
	get_tree().paused = true

func _close() -> void:
	_overlay.visible = false
	get_tree().paused = false

func _slider(label_text: String, min_v: float, max_v: float, val: float, step: float, cb: Callable) -> Control:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = val
	slider.custom_minimum_size = Vector2(380.0, 24.0)
	slider.value_changed.connect(cb)
	box.add_child(slider)
	return box

func _modal_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.96)
	style.set_border_width_all(2)
	style.border_color = Palette.CYAN
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)
	return style

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.85)
	style.set_border_width_all(2)
	style.border_color = Palette.CYAN
	style.set_corner_radius_all(10)
	return style
