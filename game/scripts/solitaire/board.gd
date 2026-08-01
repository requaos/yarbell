extends Node2D
## Solitaire board: owns a SolitaireState and mirrors it with SolitaireCardView
## nodes, handles all pointer input (drag, tap-to-move, double-tap auto-move,
## stock draw/recycle, undo), win detection and auto-complete. In group "game" so
## the shared Options modal can drive brightness and add its Solitaire settings.
## See docs/solitaire-requirements.md.

const OptionsModalScene := preload("res://scenes/ui/options_modal.tscn")

# Layout in the 1280x720 design space.
const CARD := SolitaireCardView.SIZE
const COL_STRIDE := 150.0
const X0 := 142.0
const TOP_Y := 40.0
const TAB_Y := 210.0
const FAN_UP := 34.0
const FAN_DOWN := 16.0
const WASTE_FAN := 26.0

const DRAG_THRESHOLD := 12.0
const DOUBLE_TAP := 0.35

var state: SolitaireState
var _views: Dictionary = {}          # SolitaireCard -> SolitaireCardView
var _canvas_modulate: CanvasModulate
var _hud: SolitaireHud

# Input state.
var _pressed := false
var _press_point := Vector2.ZERO
var _press_grab: Array = []
var _press_on_stock := false
var _dragging := false
var _drag_grab: Array = []
var _drag_start_pos: Array = []
var _selected_run: Array = []
var _last_tap_card: SolitaireCard = null
var _last_tap_time := 0.0

var _won := false
var _auto_running := false

func _ready() -> void:
	add_to_group("game")

	_canvas_modulate = CanvasModulate.new()
	add_child(_canvas_modulate)
	set_brightness(Settings.brightness)

	_hud = SolitaireHud.new()
	add_child(_hud)
	_hud.new_game_pressed.connect(new_game)
	_hud.undo_pressed.connect(_do_undo)
	_hud.hint_pressed.connect(request_hint)
	_hud.menu_pressed.connect(_to_menu)

	var options := OptionsModalScene.instantiate()
	options.show_gear = true
	add_child(options)

	new_game()

# --- game lifecycle -----------------------------------------------------------

func new_game() -> void:
	_won = false
	_auto_running = false
	_clear_selection()
	_hud.hide_win()

	state = SolitaireState.new()
	state.draw_count = Settings.solitaire_draw_count
	state.redeal_mode = Settings.solitaire_redeal as SolitaireState.Redeal
	state.deal()

	_rebuild_views()
	sync()
	Audio.play_sfx("card_deal")

func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/select.tscn")

func _rebuild_views() -> void:
	for view in _views.values():
		view.queue_free()
	_views.clear()
	for card in _all_cards():
		var view := SolitaireCardView.new()
		add_child(view)
		view.setup(card)
		_views[card] = view

func _all_cards() -> Array:
	var cards: Array = []
	cards.append_array(state.stock)
	cards.append_array(state.waste)
	for f in state.foundations:
		cards.append_array(f)
	for t in state.tableau:
		cards.append_array(t)
	return cards

# --- layout / rendering -------------------------------------------------------

func _foundation_pos(i: int) -> Vector2:
	return Vector2(X0 + i * COL_STRIDE, TOP_Y)

func _waste_pos() -> Vector2:
	return Vector2(X0 + 5.0 * COL_STRIDE, TOP_Y)

func _stock_pos() -> Vector2:
	return Vector2(X0 + 6.0 * COL_STRIDE, TOP_Y)

func _col_x(col: int) -> float:
	return X0 + col * COL_STRIDE

func sync() -> void:
	for i in SolitaireState.FOUNDATION_COUNT:
		var pile: Array = state.foundations[i]
		for r in pile.size():
			_place(pile[r], _foundation_pos(i), r)
	for r in state.stock.size():
		_place(state.stock[r], _stock_pos(), r)
	var w: Array = state.waste
	var base: int = maxi(0, w.size() - 3)
	for r in w.size():
		var off := Vector2(maxi(0, r - base) * WASTE_FAN, 0.0)
		_place(w[r], _waste_pos() + off, r)
	for col in SolitaireState.TABLEAU_COLUMNS:
		var pile: Array = state.tableau[col]
		var y := TAB_Y
		for r in pile.size():
			var card: SolitaireCard = pile[r]
			_place(card, Vector2(_col_x(col), y), r)
			y += FAN_UP if card.face_up else FAN_DOWN

func _place(card: SolitaireCard, pos: Vector2, z: int) -> void:
	var view: SolitaireCardView = _views[card]
	view.position = pos
	view.z_index = z
	view.setup(card)
	view.set_highlighted(_selected_run.has(card))

func _draw() -> void:
	draw_rect(Rect2(-1200.0, -1200.0, 3680.0, 3120.0), Palette.BG_DEEP)
	for i in SolitaireState.FOUNDATION_COUNT:
		_draw_slot(_foundation_pos(i))
	_draw_slot(_waste_pos())
	_draw_slot(_stock_pos())
	for col in SolitaireState.TABLEAU_COLUMNS:
		_draw_slot(Vector2(_col_x(col), TAB_Y))

func _draw_slot(pos: Vector2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.GRID.r, Palette.GRID.g, Palette.GRID.b, 0.25)
	box.set_border_width_all(2)
	box.border_color = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.30)
	box.set_corner_radius_all(SolitaireCardView.CORNER)
	draw_style_box(box, Rect2(pos, CARD))

# --- input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _won or _auto_running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press(event.position)
		else:
			_end_press(event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_on_motion(event.position)

func _begin_press(point: Vector2) -> void:
	_pressed = true
	_press_point = point
	_dragging = false
	_press_grab = []
	_press_on_stock = _rect_at(_stock_pos()).has_point(point)
	if _press_on_stock:
		return
	var card := _card_at(point)
	if card != null:
		_press_grab = state.grab_run(card)

func _on_motion(point: Vector2) -> void:
	if not _pressed:
		return
	if _dragging:
		_update_drag(point)
	elif _press_grab.size() > 0 and point.distance_to(_press_point) > DRAG_THRESHOLD:
		_start_drag()

func _end_press(point: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	if _dragging:
		_finish_drag(point)
	else:
		_handle_tap(point)

# --- dragging -----------------------------------------------------------------

func _start_drag() -> void:
	_dragging = true
	_clear_selection()
	_drag_grab = _press_grab
	_drag_start_pos = []
	for i in _drag_grab.size():
		var view: SolitaireCardView = _views[_drag_grab[i]]
		_drag_start_pos.append(view.position)
		view.z_index = 2000 + i

func _update_drag(point: Vector2) -> void:
	var offset := point - _press_point
	for i in _drag_grab.size():
		_views[_drag_grab[i]].position = _drag_start_pos[i] + offset

func _finish_drag(point: Vector2) -> void:
	var dest := _pile_at(point)
	if _try_commit(_drag_grab, dest):
		_after_move("card_place")
	else:
		Audio.play_sfx("card_invalid")
		sync()   # snap the run back home
	_dragging = false
	_drag_grab = []

# --- tapping ------------------------------------------------------------------

func _handle_tap(point: Vector2) -> void:
	if _press_on_stock:
		_do_stock()
		return

	var card := _card_at(point)
	if card != null:
		var now := Time.get_ticks_msec() / 1000.0
		if card == _last_tap_card and now - _last_tap_time < DOUBLE_TAP:
			_last_tap_card = null
			_do_auto_move(card)
			return
		_last_tap_card = card
		_last_tap_time = now

		if _selected_run.size() > 0:
			var dest := state.card_location(card)
			if _try_commit(_selected_run, dest):
				_after_move("card_place")
				return
		var run := state.grab_run(card)
		if run.size() > 0:
			_set_selection(run)
		else:
			_clear_selection()
		return

	# Empty area / empty pile.
	if _selected_run.size() > 0:
		var dest := _pile_at(point)
		if not dest.is_empty() and _try_commit(_selected_run, dest):
			_after_move("card_place")
			return
	_clear_selection()

# --- actions ------------------------------------------------------------------

func _do_stock() -> void:
	state.snapshot()
	if not state.stock.is_empty():
		state.draw()
		_after_move("card_flip")
	elif state.can_recycle():
		state.recycle()
		_after_move("card_flip")
	else:
		state.undo()   # discard the snapshot, nothing happened
		Audio.play_sfx("card_invalid")

func _do_auto_move(card: SolitaireCard) -> void:
	state.snapshot()
	if state.auto_move(card):
		_after_move("card_place")
	else:
		state.undo()
		Audio.play_sfx("card_invalid")

func _do_undo() -> void:
	if _won or _auto_running:
		return
	if state.undo():
		_clear_selection()
		sync()
		Audio.play_sfx("card_flip")

## Snapshot + apply a move of `cards` onto `dest` ({kind, index}). Returns true on
## success; leaves state untouched on failure.
func _try_commit(cards: Array, dest: Dictionary) -> bool:
	if cards.is_empty() or dest.is_empty():
		return false
	var kind: String = dest.get("kind", "")
	if kind == "foundation":
		var fi: int = dest["index"]
		if cards.size() == 1 and state.can_stack_foundation(cards[0], state.foundations[fi]):
			state.snapshot()
			state.try_move_to_foundation(cards[0], fi)
			return true
	elif kind == "tableau":
		var ci: int = dest["index"]
		if state.tableau[ci].has(cards[0]):
			return false
		var onto: SolitaireCard = state.tableau[ci].back() if not state.tableau[ci].is_empty() else null
		if state.can_stack_tableau(cards[0], onto):
			state.snapshot()
			state.try_move_to_tableau(cards, ci)
			return true
	return false

func _after_move(sfx: String) -> void:
	_clear_selection()
	sync()
	Audio.play_sfx(sfx)
	if state.is_won():
		_win()
	elif state.auto_complete_ready():
		_run_auto_complete()

func _win() -> void:
	_won = true
	_hud.show_win()
	Audio.play_sfx("win")

func _run_auto_complete() -> void:
	_auto_running = true
	while true:
		var card := state.next_auto_complete_card()
		if card == null:
			break
		state.try_move_to_foundation(card, _foundation_for(card))
		sync()
		Audio.play_sfx("card_place")
		await get_tree().create_timer(0.09).timeout
	_auto_running = false
	if state.is_won():
		_win()

func _foundation_for(card: SolitaireCard) -> int:
	for f in SolitaireState.FOUNDATION_COUNT:
		if state.can_stack_foundation(card, state.foundations[f]):
			return f
	return 0

func request_hint() -> void:
	if _won or _auto_running:
		return
	var card := state.hint()
	if card == null:
		Audio.play_sfx("card_invalid")
		return
	var view: SolitaireCardView = _views.get(card)
	if view == null:
		return
	view.set_highlighted(true)
	await get_tree().create_timer(0.9).timeout
	if not _selected_run.has(card):
		view.set_highlighted(false)

# --- selection ----------------------------------------------------------------

func _set_selection(run: Array) -> void:
	_selected_run = run
	sync()

func _clear_selection() -> void:
	if _selected_run.is_empty():
		return
	_selected_run = []
	sync()

# --- hit-testing --------------------------------------------------------------

func _rect_at(pos: Vector2) -> Rect2:
	return Rect2(pos, CARD)

## Topmost card whose rect contains `point`, or null.
func _card_at(point: Vector2) -> SolitaireCard:
	var best: SolitaireCard = null
	var best_z := -1
	for card in _views:
		var view: SolitaireCardView = _views[card]
		if view.z_index > best_z and view.rect().has_point(point):
			best = card
			best_z = view.z_index
	return best

## The pile under `point` for drop / tap-to-move: {kind, index} or {}.
func _pile_at(point: Vector2) -> Dictionary:
	for i in SolitaireState.FOUNDATION_COUNT:
		if _rect_at(_foundation_pos(i)).has_point(point):
			return {"kind": "foundation", "index": i}
	if _rect_at(_stock_pos()).has_point(point):
		return {"kind": "stock"}
	if _rect_at(_waste_pos()).has_point(point):
		return {"kind": "waste"}
	for col in SolitaireState.TABLEAU_COLUMNS:
		var x := _col_x(col)
		if point.x >= x and point.x <= x + CARD.x and point.y >= TAB_Y:
			return {"kind": "tableau", "index": col}
	return {}

# --- Options-modal integration -----------------------------------------------

## Shared brightness hook (options_modal.gd). Scales the 2D scene via CanvasModulate.
func set_brightness(value: float) -> void:
	if _canvas_modulate:
		_canvas_modulate.color = Color(value, value, value, 1.0)

## Per-game Options section, appended by the shared Options modal while in
## Solitaire. Draw/redeal changes apply on the next new game.
func build_settings_section(vb: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "— SOLITAIRE —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Palette.MAGENTA)
	vb.add_child(header)

	var draw3 := CheckButton.new()
	draw3.text = "Draw three"
	draw3.button_pressed = Settings.solitaire_draw_count == 3
	draw3.toggled.connect(func(on: bool) -> void:
		Settings.solitaire_draw_count = 3 if on else 1)
	vb.add_child(draw3)

	var limit := CheckButton.new()
	limit.text = "Limit redeals"
	limit.button_pressed = Settings.solitaire_redeal == Settings.SolitaireRedeal.LIMITED
	limit.toggled.connect(func(on: bool) -> void:
		Settings.solitaire_redeal = Settings.SolitaireRedeal.LIMITED if on else Settings.SolitaireRedeal.UNLIMITED)
	vb.add_child(limit)

	var note := Label.new()
	note.text = "Applies on next new game"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vb.add_child(note)
