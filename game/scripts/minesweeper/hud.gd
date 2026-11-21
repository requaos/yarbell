class_name MinesweeperHud
extends CanvasLayer
## Minesweeper HUD: a left-edge toolbar rail (New / Flag / Menu) — the
## collection's standard rail — with a MINES counter beneath it, plus win and
## loss overlays. The FLAG button toggles tap-to-flag mode and shows gold
## while active. Reuses the neon button styling from NeonUI. The board owns
## the game logic and connects to these signals.

signal new_game_pressed
signal menu_pressed

var flag_mode := false:
	set(v):
		flag_mode = v
		_sync_flag_button()

var _overlay: ColorRect
var _loss: ColorRect
var _flag_btn: Button
var _mines: Label

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Vertical rail in the board's left margin (buttons are 92 wide -> x 20..112).
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.position = Vector2(20.0, 20.0)
	root.add_child(bar)
	bar.add_child(_btn("NEW", func() -> void: new_game_pressed.emit()))
	_flag_btn = _btn("FLAG", func() -> void:
		flag_mode = not flag_mode
		Audio.play_sfx("card_flip"))
	bar.add_child(_flag_btn)
	bar.add_child(_btn("MENU", func() -> void: menu_pressed.emit()))

	_mines = Label.new()
	_mines.add_theme_font_size_override("font_size", 24)
	_mines.add_theme_color_override("font_color", Palette.GOLD)
	_mines.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	_mines.add_theme_constant_override("outline_size", 6)
	bar.add_child(_mines)

	# Win overlay.
	_overlay = _fullscreen_dim(0.6)
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

	# Loss overlay — lighter dim so the final board stays readable.
	_loss = _fullscreen_dim(0.45)
	_loss.visible = false
	root.add_child(_loss)
	var lcenter := CenterContainer.new()
	lcenter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loss.add_child(lcenter)
	var lvb := VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 28)
	lvb.alignment = BoxContainer.ALIGNMENT_CENTER
	lcenter.add_child(lvb)
	var ltitle := Label.new()
	ltitle.text = "BOOM"
	ltitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ltitle.add_theme_font_size_override("font_size", 88)
	ltitle.add_theme_color_override("font_color", Palette.RED)
	ltitle.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	ltitle.add_theme_constant_override("outline_size", 8)
	lvb.add_child(ltitle)
	lvb.add_child(NeonUI.menu_button("NEW GAME", func() -> void:
		hide_loss()
		new_game_pressed.emit()))

func show_win() -> void:
	_overlay.visible = true

func hide_win() -> void:
	_overlay.visible = false

func show_loss() -> void:
	_loss.visible = true

func hide_loss() -> void:
	_loss.visible = false

func is_prompting() -> bool:
	return _overlay.visible or _loss.visible

func set_mines(remaining: int) -> void:
	_mines.text = "MINES  %d" % remaining

func _sync_flag_button() -> void:
	if _flag_btn == null:
		return
	var style := NeonUI.button_style(0.4 if flag_mode else 0.12)
	_flag_btn.add_theme_stylebox_override("normal", style)
	_flag_btn.add_theme_color_override("font_color",
		Palette.GOLD if flag_mode else Palette.CYAN)

func _fullscreen_dim(alpha: float) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, alpha)
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
