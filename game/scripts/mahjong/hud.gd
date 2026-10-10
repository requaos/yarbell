class_name MahjongHud
extends CanvasLayer
## Mahjong HUD: a left-edge toolbar rail (New / Undo / Hint / Menu) — the same
## fix the Solitaire toolbar got, living in the board's left margin — plus a
## centred win overlay and a deadlock prompt (Shuffle / New Game). Reuses the
## neon button styling from NeonUI. The board owns the game logic and connects
## to these signals.

signal new_game_pressed
signal undo_pressed
signal hint_pressed
signal menu_pressed
signal shuffle_pressed

var _overlay: ColorRect
var _deadlock: ColorRect

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Vertical rail in the board's left margin (buttons are 92 wide -> x 20..112,
	# clear of the centered layout).
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.position = Vector2(20.0, 20.0)
	root.add_child(bar)
	bar.add_child(_btn("NEW", func() -> void: new_game_pressed.emit()))
	bar.add_child(_btn("UNDO", func() -> void: undo_pressed.emit()))
	bar.add_child(_btn("HINT", func() -> void: hint_pressed.emit()))
	bar.add_child(_btn("MENU", func() -> void: menu_pressed.emit()))

	# Win overlay.
	_overlay = _fullscreen_dim()
	root.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 28)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	var label := Label.new()
	label.text = "YOU WIN"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 88)
	label.add_theme_color_override("font_color", Palette.GOLD)
	label.add_theme_color_override("font_outline_color", Palette.MAGENTA)
	label.add_theme_constant_override("outline_size", 8)
	vb.add_child(label)
	vb.add_child(NeonUI.menu_button("NEW GAME", func() -> void:
		hide_win()
		new_game_pressed.emit()))

	# Deadlock prompt overlay.
	_deadlock = _fullscreen_dim()
	_deadlock.visible = false
	root.add_child(_deadlock)
	var dcenter := CenterContainer.new()
	dcenter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deadlock.add_child(dcenter)
	var dvb := VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 28)
	dvb.alignment = BoxContainer.ALIGNMENT_CENTER
	dcenter.add_child(dvb)
	var dtitle := Label.new()
	dtitle.text = "NO MOVES"
	dtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dtitle.add_theme_font_size_override("font_size", 56)
	dtitle.add_theme_color_override("font_color", Palette.CYAN)
	dtitle.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	dtitle.add_theme_constant_override("outline_size", 8)
	dvb.add_child(dtitle)
	dvb.add_child(NeonUI.menu_button("SHUFFLE", func() -> void:
		hide_deadlock()
		shuffle_pressed.emit()))
	dvb.add_child(NeonUI.menu_button("NEW GAME", func() -> void:
		hide_deadlock()
		new_game_pressed.emit()))

func show_win() -> void:
	_overlay.visible = true

func hide_win() -> void:
	_overlay.visible = false

func show_deadlock() -> void:
	_deadlock.visible = true

func hide_deadlock() -> void:
	_deadlock.visible = false

func is_prompting() -> bool:
	return _deadlock.visible or _overlay.visible

func _fullscreen_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	return dim

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(92.0, 44.0)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Palette.CYAN)
	b.add_theme_stylebox_override("normal", NeonUI.button_style(0.12))
	b.add_theme_stylebox_override("hover", NeonUI.button_style(0.25))
	b.add_theme_stylebox_override("pressed", NeonUI.button_style(0.4))
	b.pressed.connect(cb)
	return b
