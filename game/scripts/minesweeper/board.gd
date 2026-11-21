extends Node2D
## Minesweeper board: owns a MinesweeperState and draws the whole grid itself
## (one canvas item — the expert board is 480 cells). Tap reveals (or floods /
## chords); the HUD FLAG toggle switches taps to flagging. Win/loss overlays
## come from the HUD. In group "game" so the shared Options modal can drive
## brightness and add the difficulty section. See docs/minesweeper-requirements.md.

const OptionsModalScene := preload("res://scenes/ui/options_modal.tscn")

# Classic 1-8 count colours, neon remapped.
const NUM_COLORS: Array = [
	Color(0.35, 0.9, 0.9),   # 1 cyan
	Color(0.35, 0.9, 0.55),  # 2 green
	Color(1.0, 0.35, 0.4),   # 3 red
	Color(0.7, 0.45, 1.0),   # 4 purple
	Color(1.0, 0.65, 0.25),  # 5 amber
	Color(0.3, 0.8, 0.85),   # 6 teal
	Color(0.95, 0.95, 1.0),  # 7 white
	Color(0.6, 0.6, 0.68),   # 8 grey
]

# Board area: right of the HUD rail, with margins. The right bound stops
# short of the shared options gear button (top-right, x >= 1208).
const AREA_X := 140.0
const AREA_Y := 30.0
const AREA_W := 1050.0
const AREA_H := 660.0
const MAX_CELL := 64.0

var state: MinesweeperState
var _hud: MinesweeperHud
var _canvas_modulate: CanvasModulate

var _cell := 64.0
var _origin := Vector2.ZERO

func _ready() -> void:
	add_to_group("game")

	_canvas_modulate = CanvasModulate.new()
	add_child(_canvas_modulate)
	set_brightness(Settings.brightness)

	_hud = MinesweeperHud.new()
	add_child(_hud)
	_hud.new_game_pressed.connect(new_game)
	_hud.menu_pressed.connect(_to_menu)

	var options := OptionsModalScene.instantiate()
	options.show_gear = true
	add_child(options)

	new_game()

# --- game lifecycle -----------------------------------------------------------

func new_game() -> void:
	state = MinesweeperState.new()
	state.new_game(Settings.minesweeper_difficulty)
	state.changed.connect(func() -> void: queue_redraw())
	_compute_geometry()
	_hud.hide_win()
	_hud.hide_loss()
	_hud.set_mines(state.remaining_mines())
	queue_redraw()

func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/select.tscn")

func _compute_geometry() -> void:
	_cell = floorf(minf(AREA_W / float(state.width), minf(AREA_H / float(state.height), MAX_CELL)))
	var bw := _cell * float(state.width)
	var bh := _cell * float(state.height)
	_origin = Vector2(AREA_X + (AREA_W - bw) * 0.5, AREA_Y + (AREA_H - bh) * 0.5)

# --- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if state == null or _hud.is_prompting() or state.has_lost() or state.is_won():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tap(event.position)

func _handle_tap(point: Vector2) -> void:
	var local := point - _origin
	var cx := int(local.x / _cell)
	var cy := int(local.y / _cell)
	if not state.in_bounds(cx, cy):
		return
	var i := cy * state.width + cx
	if _hud.flag_mode:
		state.toggle_flag(i)
		Audio.play_sfx("card_place")
		_after_action(false)
	elif state.is_revealed(i) and state.adjacent_count(i) > 0:
		var hit: bool = state.chord(i)
		Audio.play_sfx("card_deal" if not hit else "boom")
		_after_action(hit)
	else:
		var hit: bool = state.reveal(i)
		Audio.play_sfx("card_flip" if not hit else "boom")
		_after_action(hit)

func _after_action(hit: bool) -> void:
	_hud.set_mines(state.remaining_mines())
	queue_redraw()
	if state.is_won():
		Audio.play_sfx("win")
		_hud.set_mines(0)
		_hud.show_win()
	elif hit:
		_hud.show_loss()

# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(-100.0, -100.0, 1480.0, 920.0), Palette.BG_DEEP)
	var lost := state.has_lost()
	var won := state.is_won()
	for i in state.width * state.height:
		_draw_cell(i, lost, won)

func _cell_rect(i: int) -> Rect2:
	var x := i % state.width
	var y := i / state.width
	return Rect2(_origin + Vector2(float(x) * _cell, float(y) * _cell),
		Vector2(_cell - 1.0, _cell - 1.0))

func _draw_cell(i: int, lost: bool, won: bool) -> void:
	var r := _cell_rect(i)
	var revealed := state.is_revealed(i)
	var flagged := state.is_flagged(i)

	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(3.0)
	if revealed:
		box.bg_color = Color(0.04, 0.04, 0.09, 1.0)
		if lost and i == state.exploded_at():
			box.bg_color = Color(0.7, 0.12, 0.18, 0.85)
	else:
		box.bg_color = Color(0.10, 0.10, 0.18, 1.0)
		box.set_border_width_all(1)
		box.border_color = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.45)
	draw_style_box(box, r)

	if revealed:
		var n := state.adjacent_count(i)
		if n > 0 and not state.is_mine(i):
			_draw_number(r, n)
		if state.is_mine(i):
			_draw_mine(r)   # the exploded cell
		return

	# Covered cells.
	if flagged and not (lost and not state.is_mine(i)):
		_draw_flag(r)
	elif won and state.is_mine(i):
		_draw_flag(r)      # classic: win auto-flags remaining mines
	elif lost and state.is_mine(i) and not flagged:
		_draw_mine(r)      # loss reveals every mine
	if flagged and lost and not state.is_mine(i):
		_draw_wrong_flag(r)

func _draw_number(r: Rect2, n: int) -> void:
	var font := ThemeDB.fallback_font
	var size := int(_cell * 0.54)
	draw_string(font, Vector2(r.position.x, r.position.y + _cell * 0.70),
		str(n), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size,
		NUM_COLORS[clampi(n, 1, 8) - 1])

func _draw_flag(r: Rect2) -> void:
	var c := r.position + r.size * 0.5
	var pole_x := c.x - _cell * 0.08
	draw_line(Vector2(pole_x, r.position.y + _cell * 0.22),
		Vector2(pole_x, r.position.y + _cell * 0.78), Palette.GOLD, 2.0)
	draw_line(Vector2(pole_x - _cell * 0.14, r.position.y + _cell * 0.78),
		Vector2(pole_x + _cell * 0.14, r.position.y + _cell * 0.78), Palette.GOLD, 2.0)
	var pts := PackedVector2Array([
		Vector2(pole_x, r.position.y + _cell * 0.24),
		Vector2(pole_x + _cell * 0.32, r.position.y + _cell * 0.37),
		Vector2(pole_x, r.position.y + _cell * 0.50),
	])
	draw_colored_polygon(pts, Palette.RED)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.GOLD, 1.5)

func _draw_mine(r: Rect2) -> void:
	var c := r.position + r.size * 0.5
	var radius := _cell * 0.20
	draw_circle(c, radius, Color(0.9, 0.15, 0.2))
	draw_circle(c + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.25,
		Color(1.0, 0.7, 0.7))
	for a in 8:
		var dir := Vector2(cos(TAU * a / 8.0), sin(TAU * a / 8.0))
		draw_line(c + dir * radius, c + dir * _cell * 0.34, Color(0.9, 0.15, 0.2), 2.0)

func _draw_wrong_flag(r: Rect2) -> void:
	var inset := r.size * 0.18
	var a := r.position + inset
	var b := r.position + r.size - inset
	draw_line(a, b, Palette.RED, 3.0)
	draw_line(Vector2(a.x, b.y), Vector2(b.x, a.y), Palette.RED, 3.0)

# --- Options-modal integration -----------------------------------------------

## Shared brightness hook (options_modal.gd persists the value). Scales the 2D
## scene via CanvasModulate.
func set_brightness(value: float) -> void:
	if _canvas_modulate:
		_canvas_modulate.color = Color(value, value, value, 1.0)

## Per-game Options section, appended by the shared Options modal while in
## Minesweeper. Difficulty changes apply on the next new game.
func build_settings_section(vb: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "— MINESWEEPER —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Palette.MAGENTA)
	vb.add_child(header)

	var names := ["Beginner  9x9", "Intermediate  16x16", "Expert  30x16"]
	var buttons: Array[CheckButton] = []
	for i in names.size():
		var btn := CheckButton.new()
		btn.text = names[i]
		btn.button_pressed = Settings.minesweeper_difficulty == i
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.minesweeper_difficulty = i
				for other in buttons:
					other.set_pressed_no_signal(other == btn))
		vb.add_child(btn)
		buttons.append(btn)

	var note := Label.new()
	note.text = "Applies on next new game"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vb.add_child(note)
