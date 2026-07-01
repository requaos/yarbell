extends CanvasLayer
## 2D overlay HUD. Top bar: level / coins / enemies remaining. A primary-tower
## HP bar sits below it. A center overlay shows level-cleared / game-over. Binds
## to the GameState autoload signals.

var _level: Label
var _coins: Label
var _enemies: Label
var _hp: ProgressBar
var _overlay: Label
var _toast: Label
var _options: ColorRect

func _ready() -> void:
	# Keep the HUD (and its options modal) responsive while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24.0
	top.offset_right = -24.0
	top.offset_top = 14.0
	root.add_child(top)

	_level = _stat(Palette.PURPLE)
	_coins = _stat(Palette.GOLD)
	_enemies = _stat(Palette.RED)
	top.add_child(_level)
	top.add_child(_spacer())
	top.add_child(_coins)
	top.add_child(_spacer())
	top.add_child(_enemies)

	_hp = ProgressBar.new()
	_hp.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hp.offset_left = 24.0
	_hp.offset_right = -24.0
	_hp.offset_top = 56.0
	_hp.custom_minimum_size = Vector2(0.0, 16.0)
	_hp.show_percentage = false
	_hp.min_value = 0.0
	_hp.max_value = GameState.primary_max_hp
	_hp.value = GameState.primary_hp
	_hp.add_theme_stylebox_override("background", _bar_style(Color(0.10, 0.10, 0.16, 0.7)))
	_hp.add_theme_stylebox_override("fill", _bar_style(Palette.CYAN))
	root.add_child(_hp)

	_overlay = Label.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_theme_font_size_override("font_size", 52)
	_overlay.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	_overlay.add_theme_constant_override("outline_size", 8)
	_overlay.visible = false
	root.add_child(_overlay)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -140.0
	_toast.offset_left = -200.0
	_toast.offset_right = 200.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.visible = false
	root.add_child(_toast)

	_build_options(root)

	_on_coins(GameState.coins)
	_on_level(GameState.level)
	_on_enemies(0, 0)

	GameState.coins_changed.connect(_on_coins)
	GameState.level_changed.connect(_on_level)
	GameState.enemies_changed.connect(_on_enemies)
	GameState.primary_hp_changed.connect(_on_hp)
	GameState.game_over.connect(func() -> void: _show_overlay("PRIMARY DESTROYED", Palette.RED))
	GameState.level_cleared.connect(func() -> void: _show_overlay("LEVEL CLEARED", Palette.CYAN))

# --- signal handlers ----------------------------------------------------------

func _on_coins(value: int) -> void:
	_coins.text = "COINS  %d" % value

func _on_level(value: int) -> void:
	_level.text = "LEVEL  %d" % value

func _on_enemies(alive: int, total: int) -> void:
	_enemies.text = "ENEMIES  %d / %d" % [alive, total]

func _on_hp(current: int, maximum: int) -> void:
	_hp.max_value = maximum
	_hp.value = current

func _show_overlay(text: String, color: Color) -> void:
	_overlay.text = text
	_overlay.add_theme_color_override("font_color", color)
	_overlay.visible = true

func hide_overlay() -> void:
	_overlay.visible = false

## Brief fading message near the bottom of the screen.
func flash(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	_toast.visible = true
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.5)

# --- options modal ------------------------------------------------------------

func _build_options(root: Control) -> void:
	var gear := Button.new()
	gear.text = "⚙"   # gear
	# Top-right, just below the HUD bars — clear of the bottom system-gesture zone.
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
	gear.pressed.connect(_open_options)
	root.add_child(gear)

	_options = ColorRect.new()
	_options.color = Color(0.0, 0.0, 0.0, 0.6)
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	root.add_child(_options)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.add_child(center)

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

	vb.add_child(_make_option_slider("BRIGHTNESS", 0.5, 1.5, 1.0, 0.05,
		func(v: float) -> void:
			var game := get_parent()
			if game and game.has_method("set_brightness"):
				game.set_brightness(v)))
	vb.add_child(_make_option_slider("MUSIC VOLUME", 0.0, 1.0, 0.5, 0.05,
		func(v: float) -> void: Audio.set_music_volume(v)))
	vb.add_child(_make_option_slider("SFX VOLUME", 0.0, 1.0, 0.8, 0.05,
		func(v: float) -> void: Audio.set_sfx_volume(v)))

	var close := Button.new()
	close.text = "CLOSE"
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(_close_options)
	vb.add_child(close)

func _make_option_slider(label_text: String, min_v: float, max_v: float, val: float, step: float, cb: Callable) -> Control:
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

func _open_options() -> void:
	_options.visible = true
	get_tree().paused = true

func _close_options() -> void:
	_options.visible = false
	get_tree().paused = false

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

# --- widget factories ---------------------------------------------------------

func _stat(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	label.add_theme_constant_override("outline_size", 6)
	return label

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	return style
