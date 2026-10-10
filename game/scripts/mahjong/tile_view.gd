class_name MahjongTileView
extends Node2D
## Draws one procedural neon mahjong tile, mirroring a state tile Dictionary
## ({id, group, rank, layer, x, y}). Flat-neon look (dark slab, suit-coloured
## border and pips/glyphs) matching the app aesthetic; no image assets. Higher
## layers get a drawn thickness edge; the board offsets positions per layer.

const SIZE := Vector2(84.0, 104.0)
const CORNER := 8.0

# Group accent colours (GRID-dark body keeps the neon look).
const GREEN := Color(0.35, 0.9, 0.55)
const PINK := Color(1.0, 0.55, 0.8)
const WHITE := Color(0.95, 0.95, 1.0)

var tile: Dictionary = {}
var _highlight: Color = Color(0, 0, 0, 0)

func setup(p_tile: Dictionary) -> void:
	tile = p_tile
	queue_redraw()

## Gold for selection/hint, red for an invalid-tap flash.
func set_highlight(on: bool, color: Color = Palette.GOLD) -> void:
	var next := color if on else Color(0, 0, 0, 0)
	if _highlight != next:
		_highlight = next
		queue_redraw()

## Hit rectangle in board (canvas) space.
func rect() -> Rect2:
	return Rect2(position, SIZE)

func _draw() -> void:
	if tile.is_empty():
		return
	# Slab thickness: a dark under-edge offset toward the lower right.
	draw_rect(Rect2(Vector2(5.0, 6.0), SIZE), Color(0.02, 0.02, 0.05), true)

	var r := Rect2(Vector2.ZERO, SIZE)
	var accent := _accent()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.07, 0.13, 1.0)
	box.set_border_width_all(2)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	box.set_corner_radius_all(CORNER)
	draw_style_box(box, r)

	match int(tile["group"]):
		MahjongState.Group.DOT:
			_draw_dots(accent)
		MahjongState.Group.BAMBOO:
			_draw_bamboo(accent)
		MahjongState.Group.CHAR:
			_draw_char(accent)
		MahjongState.Group.WIND:
			_draw_glyph(MahjongState.WIND_LABELS[int(tile["rank"])], accent, 44)
		MahjongState.Group.DRAGON:
			_draw_diamond(accent)
		MahjongState.Group.FLOWER:
			_draw_flower()
		MahjongState.Group.SEASON:
			_draw_season()

	if _highlight.a > 0.0:
		var hl := StyleBoxFlat.new()
		hl.bg_color = Color(0, 0, 0, 0)
		hl.set_border_width_all(4)
		hl.border_color = _highlight
		hl.set_corner_radius_all(CORNER)
		draw_style_box(hl, r)

func _accent() -> Color:
	match int(tile["group"]):
		MahjongState.Group.DOT:
			return Palette.GOLD
		MahjongState.Group.BAMBOO:
			return GREEN
		MahjongState.Group.CHAR:
			return Palette.PURPLE
		MahjongState.Group.WIND:
			return Palette.CYAN
		MahjongState.Group.DRAGON:
			return [Palette.RED, GREEN, WHITE][int(tile["rank"])]
		MahjongState.Group.FLOWER:
			return PINK
		_:
			return Palette.GOLD

# --- faces ---------------------------------------------------------------------

func _center() -> Vector2:
	return SIZE * 0.5

## Dots arranged on a 3x3 grid with the classic per-rank patterns.
func _draw_dots(accent: Color) -> void:
	var n := int(tile["rank"]) + 1
	var patterns := {
		1: [4],
		2: [1, 7],
		3: [1, 4, 7],
		4: [0, 2, 6, 8],
		5: [0, 2, 4, 6, 8],
		6: [0, 2, 3, 5, 6, 8],
		7: [0, 2, 4, 6, 8, 1, 3],
		8: [0, 2, 4, 6, 8, 1, 3, 5, 7],
		9: [0, 1, 2, 3, 4, 5, 6, 7, 8],
	}
	var cells: Array = patterns.get(n, [4])
	var radius := 7.0 if cells.size() > 4 else 9.0
	var half := Vector2(SIZE.x * 0.28, SIZE.y * 0.30)
	for c in cells:
		var p := _center() + Vector2((int(c) % 3 - 1) * half.x, (int(c) / 3 - 1) * half.y)
		_draw_disc(p, radius, accent)

func _draw_bamboo(accent: Color) -> void:
	var n := int(tile["rank"]) + 1
	if n == 1:
		_draw_stick(_center() + Vector2(0.0, -8.0), 7.0, 56.0, accent)
		return
	var per_row := 3
	var rows := ceili(float(n) / float(per_row))
	var bw := 7.0
	var bh := 34.0 if rows <= 2 else 22.0
	var stride_x := 20.0
	var stride_y := bh + 10.0
	var top := _center().y - ((rows - 1) * stride_y + bh) * 0.5
	for i in n:
		var row := i / per_row
		var in_row: int = mini(per_row, n - row * per_row)
		var x := _center().x + (i % per_row - (in_row - 1) * 0.5) * stride_x
		_draw_stick(Vector2(x, top + row * stride_y), bw, bh, accent)

func _draw_char(accent: Color) -> void:
	# Rank numeral between two horizontal strokes suggests a character tile.
	var n := str(int(tile["rank"]) + 1)
	var font := ThemeDB.fallback_font
	var stroke := Color(accent.r, accent.g, accent.b, 0.5)
	draw_line(Vector2(16.0, 22.0), Vector2(SIZE.x - 16.0, 22.0), stroke, 2.0)
	draw_line(Vector2(16.0, SIZE.y - 18.0), Vector2(SIZE.x - 16.0, SIZE.y - 18.0), stroke, 2.0)
	draw_string(font, Vector2(0.0, _center().y + 16.0), n, HORIZONTAL_ALIGNMENT_CENTER,
		SIZE.x, 40, accent)

func _draw_glyph(text: String, accent: Color, size: int) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, _center().y + size * 0.36), text,
		HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, size, accent)

func _draw_diamond(accent: Color) -> void:
	var c := _center()
	var s := 24.0
	var pts := PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0),
	])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.25))
	draw_polyline(pts, accent, 3.0)
	_draw_disc(c, 4.0, accent)

func _draw_flower() -> void:
	var c := _center()
	for dir in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		_draw_disc(c + dir * 14.0, 7.0, PINK)
	_draw_disc(c, 5.0, Palette.GOLD)

func _draw_season() -> void:
	var c := _center()
	for i in 4:
		var a := PI / 2.0 * i
		var tip := c + Vector2(cos(a), sin(a)) * 20.0
		var left := c + Vector2(cos(a + 2.2), sin(a + 2.2)) * 12.0
		var right := c + Vector2(cos(a - 2.2), sin(a - 2.2)) * 12.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Palette.GOLD)
	_draw_disc(c, 4.0, Palette.CYAN)

# --- primitives ----------------------------------------------------------------

func _draw_disc(p: Vector2, radius: float, color: Color) -> void:
	draw_circle(p, radius, Color(color.r, color.g, color.b, 0.3))
	draw_arc(p, radius, 0.0, TAU, 16, color, 2.0)

func _draw_stick(p: Vector2, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(p.x - w * 0.5, p.y, w, h), Color(color.r, color.g, color.b, 0.85))
