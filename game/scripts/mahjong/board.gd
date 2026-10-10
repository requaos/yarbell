extends Node2D
## Mahjong solitaire board: owns a MahjongState and mirrors it with
## MahjongTileView nodes, handles tap-to-select / tap-to-match input, hint,
## undo, the deadlock prompt (auto-detected), shuffling and the win overlay.
## In group "game" so the shared Options modal can drive brightness and add
## the Mahjong settings section. See docs/mahjong-requirements.md.

const OptionsModalScene := preload("res://scenes/ui/options_modal.tscn")

# Tile placement on the half-tile cell grid, lifted per layer for depth.
const CELL_W := MahjongTileView.SIZE.x * 0.5
const CELL_H := MahjongTileView.SIZE.y * 0.5
const LAYER_DX := 7.0
const LAYER_DY := -13.0

const VIEWPORT := Vector2(1280.0, 720.0)

var state: MahjongState
var _views: Dictionary = {}          # tile id -> MahjongTileView
var _canvas_modulate: CanvasModulate
var _hud: MahjongHud
var _origin := Vector2.ZERO

var _selected_id := -1               # tile id of the current selection, -1 none
var _won := false

func _ready() -> void:
	add_to_group("game")

	_canvas_modulate = CanvasModulate.new()
	add_child(_canvas_modulate)
	set_brightness(Settings.brightness)

	_hud = MahjongHud.new()
	add_child(_hud)
	_hud.new_game_pressed.connect(new_game)
	_hud.undo_pressed.connect(_do_undo)
	_hud.hint_pressed.connect(request_hint)
	_hud.menu_pressed.connect(_to_menu)
	_hud.shuffle_pressed.connect(_do_shuffle)

	var options := OptionsModalScene.instantiate()
	options.show_gear = true
	add_child(options)

	new_game()

# --- game lifecycle -----------------------------------------------------------

func new_game() -> void:
	_won = false
	_selected_id = -1
	_hud.hide_win()
	_hud.hide_deadlock()

	state = MahjongState.new()
	state.deal(Settings.mahjong_layout)
	_rebuild_views()
	Audio.play_sfx("card_deal")
	_check_flow()

func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/select.tscn")

func _rebuild_views() -> void:
	for view in _views.values():
		view.queue_free()
	_views.clear()
	_compute_origin()
	for t in state.tiles:
		var view := MahjongTileView.new()
		add_child(view)
		view.setup(t)
		view.position = _screen_pos(t)
		view.z_index = int(t["layer"]) * 100 + int(t["y"]) * 10 + int(t["x"])
		_views[t["id"]] = view

# --- layout --------------------------------------------------------------------

func _screen_pos(t: Dictionary) -> Vector2:
	return _origin + Vector2(
		float(t["x"]) * CELL_W + float(t["layer"]) * LAYER_DX,
		float(t["y"]) * CELL_H + float(t["layer"]) * LAYER_DY)

## Center the layout's bounding box (including the layer lift) in the viewport.
func _compute_origin() -> void:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for t in state.tiles:
		var p := Vector2(
			float(t["x"]) * CELL_W + float(t["layer"]) * LAYER_DX,
			float(t["y"]) * CELL_H + float(t["layer"]) * LAYER_DY)
		min_p = min_p.min(p)
		max_p = max_p.max(p + MahjongTileView.SIZE)
	_origin = (VIEWPORT - (max_p - min_p)) * 0.5 - min_p

# --- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _won or _hud.is_prompting():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tap(event.position)

func _handle_tap(point: Vector2) -> void:
	var id := _tile_at(point)
	if id == -1:
		_deselect()
		return
	var idx := state.find_id(id)
	if idx == -1:
		return
	if _selected_id == id:
		_deselect()
		return
	if _selected_id != -1:
		var sel := state.find_id(_selected_id)
		if sel != -1 and state.can_match(sel, idx):
			_remove_pair(sel, idx)
			return
	if not state.is_free(idx):
		_flash_invalid(id)
		Audio.play_sfx("card_invalid")
		return
	_select(id)
	Audio.play_sfx("tile_select")

## Topmost tile whose rect contains `point`, or -1.
func _tile_at(point: Vector2) -> int:
	var best := -1
	var best_z := -1
	for id in _views:
		var view: MahjongTileView = _views[id]
		if view.z_index > best_z and view.rect().has_point(point):
			best = id
			best_z = view.z_index
	return best

func _select(id: int) -> void:
	_deselect()
	_selected_id = id
	_highlight(id, Palette.GOLD)

func _deselect() -> void:
	if _selected_id != -1:
		_highlight(_selected_id, Color(0, 0, 0, 0))
		_selected_id = -1

func _highlight(id: int, color: Color) -> void:
	var view: MahjongTileView = _views.get(id)
	if view:
		view.set_highlight(color.a > 0.0, color)

func _flash_invalid(id: int) -> void:
	var view: MahjongTileView = _views.get(id)
	if view == null:
		return
	view.set_highlight(true, Palette.RED)
	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_callback(func() -> void:
		if _selected_id != id:
			view.set_highlight(false))

# --- actions -------------------------------------------------------------------

func _remove_pair(a: int, b: int) -> void:
	var id_a: int = state.tiles[a]["id"]
	var id_b: int = state.tiles[b]["id"]
	if not state.remove_pair(a, b):
		return
	_deselect()
	_pop(id_a)
	_pop(id_b)
	Audio.play_sfx("tile_match")
	_check_flow()

## Fade-and-grow a removed tile's view, then free it.
func _pop(id: int) -> void:
	var view: MahjongTileView = _views.get(id)
	if view == null:
		return
	_views.erase(id)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(view, "modulate:a", 0.0, 0.16)
	tween.tween_property(view, "scale", Vector2(1.2, 1.2), 0.16)
	tween.chain().tween_callback(view.queue_free)

func _do_undo() -> void:
	if _won or _hud.is_prompting():
		return
	if state.undo():
		_deselect()
		_rebuild_views()
		Audio.play_sfx("card_flip")
		_check_flow()

func _do_shuffle() -> void:
	state.shuffle_remaining()
	_deselect()
	for t in state.tiles:
		var view: MahjongTileView = _views.get(t["id"])
		if view:
			view.setup(t)
	Audio.play_sfx("card_deal")
	_check_flow()

func request_hint() -> void:
	if _won or _hud.is_prompting():
		return
	var pair: Array = state.hint()
	if pair.is_empty():
		Audio.play_sfx("card_invalid")
		return
	for idx in pair:
		var id: int = state.tiles[idx]["id"]
		_highlight(id, Palette.GOLD)
		var tween := create_tween()
		tween.tween_interval(0.9)
		tween.tween_callback(func() -> void:
			if _selected_id != id:
				_highlight(id, Color(0, 0, 0, 0)))

## After any board change: win, or deadlock prompt when no pair remains.
func _check_flow() -> void:
	if state.is_won():
		_won = true
		Audio.play_sfx("win")
		_hud.show_win()
	elif not state.has_any_match():
		_hud.show_deadlock()

# --- Options-modal integration -----------------------------------------------

## Shared brightness hook (options_modal.gd persists the value). Scales the 2D
## scene via CanvasModulate.
func set_brightness(value: float) -> void:
	if _canvas_modulate:
		_canvas_modulate.color = Color(value, value, value, 1.0)

## Per-game Options section, appended by the shared Options modal while in
## Mahjong. Layout changes apply on the next new game.
func build_settings_section(vb: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "— MAHJONG —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Palette.MAGENTA)
	vb.add_child(header)

	var buttons: Array[CheckButton] = []
	for i in MahjongLayouts.NAMES.size():
		var btn := CheckButton.new()
		btn.text = MahjongLayouts.NAMES[i]
		btn.button_pressed = Settings.mahjong_layout == i
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.mahjong_layout = i
				for other in buttons:
					other.set_pressed_no_signal(other == btn))
		vb.add_child(btn)
		buttons.append(btn)

	var note := Label.new()
	note.text = "Applies on next new game"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vb.add_child(note)
