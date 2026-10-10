class_name SolitaireHud
extends CanvasLayer
## Solitaire HUD: a left-edge toolbar rail (New / Undo / Hint / Menu) and a
## centred win overlay. The rail lives in the board's empty left margin (piles
## start at x=142) so it never overlaps the placeholders. Reuses the neon button
## styling from NeonUI. The board owns the game logic and connects to these
## signals.

signal new_game_pressed
signal undo_pressed
signal hint_pressed
signal menu_pressed

var _overlay: ColorRect

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Vertical rail in the board's left margin (buttons are 92 wide -> x 20..112,
	# clear of the first pile at x 142).
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.position = Vector2(20.0, 20.0)
	root.add_child(bar)
	bar.add_child(_btn("NEW", func() -> void: new_game_pressed.emit()))
	bar.add_child(_btn("UNDO", func() -> void: undo_pressed.emit()))
	bar.add_child(_btn("HINT", func() -> void: hint_pressed.emit()))
	bar.add_child(_btn("MENU", func() -> void: menu_pressed.emit()))

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
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

func show_win() -> void:
	_overlay.visible = true

func hide_win() -> void:
	_overlay.visible = false

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
