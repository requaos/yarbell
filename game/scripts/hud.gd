extends CanvasLayer
## 2D overlay HUD. Top bar: level / coins / enemies remaining. A primary-tower
## HP bar sits below it. A center overlay shows level-cleared / game-over. Binds
## to the GameState autoload signals.

var _level: Label
var _wave: Label
var _coins: Label
var _enemies: Label
var _hp: ProgressBar
var _overlay: Label
var _toast: Label

func _ready() -> void:
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
	_wave = _stat(Palette.CYAN)
	_coins = _stat(Palette.GOLD)
	_enemies = _stat(Palette.RED)
	top.add_child(_level)
	top.add_child(_spacer())
	top.add_child(_wave)
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

	_on_coins(GameState.coins)
	_on_level(GameState.level)
	_on_wave(0, 0)
	_on_enemies(0, 0)

	GameState.coins_changed.connect(_on_coins)
	GameState.level_changed.connect(_on_level)
	GameState.wave_changed.connect(_on_wave)
	GameState.enemies_changed.connect(_on_enemies)
	GameState.primary_hp_changed.connect(_on_hp)
	GameState.game_over.connect(func() -> void: _show_overlay("PRIMARY DESTROYED", Palette.RED))
	GameState.level_cleared.connect(func() -> void: _show_overlay("LEVEL CLEARED", Palette.CYAN))

# --- signal handlers ----------------------------------------------------------

func _on_coins(value: int) -> void:
	_coins.text = "COINS  %d" % value

func _on_level(value: int) -> void:
	_level.text = "LEVEL  %d" % value

func _on_wave(current: int, total: int) -> void:
	if total <= 0:
		_wave.text = "WAVE  -"
	else:
		_wave.text = "WAVE  %d / %d" % [current, total]

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
