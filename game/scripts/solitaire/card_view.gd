class_name SolitaireCardView
extends Node2D
## Draws a single procedural neon playing card, mirroring one SolitaireCard.
## Flat-neon look (dark body, bright border, rank + suit) matching the app menus;
## no image assets. Face-down cards show a purple lattice back.

const SIZE := Vector2(96.0, 132.0)
const CORNER := 10.0

var card: SolitaireCard
var _highlighted := false

func setup(p_card: SolitaireCard) -> void:
	card = p_card
	queue_redraw()

func set_highlighted(on: bool) -> void:
	if _highlighted != on:
		_highlighted = on
		queue_redraw()

## Hit rectangle in board (canvas) space. The board root sits at the origin.
func rect() -> Rect2:
	return Rect2(position, SIZE)

func _draw() -> void:
	if card == null:
		return
	var r := Rect2(Vector2.ZERO, SIZE)
	if card.face_up:
		_draw_face(r)
	else:
		_draw_back(r)
	if _highlighted:
		var hl := StyleBoxFlat.new()
		hl.bg_color = Color(0, 0, 0, 0)
		hl.set_border_width_all(4)
		hl.border_color = Palette.GOLD
		hl.set_corner_radius_all(CORNER)
		draw_style_box(hl, r)

func _draw_face(r: Rect2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.06, 0.12, 1.0)
	box.set_border_width_all(2)
	box.border_color = Palette.CYAN
	box.set_corner_radius_all(CORNER)
	draw_style_box(box, r)

	var col: Color = Palette.RED if card.is_red() else Palette.CYAN
	var font := ThemeDB.fallback_font
	var rank := card.rank_label()
	var suit := card.suit_symbol()
	draw_string(font, Vector2(10, 30), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	draw_string(font, Vector2(10, 54), suit, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	draw_string(font, Vector2(0, SIZE.y * 0.64), suit, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 44, col)

func _draw_back(r: Rect2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.05, 0.16, 1.0)
	box.set_border_width_all(2)
	box.border_color = Palette.PURPLE
	box.set_corner_radius_all(CORNER)
	draw_style_box(box, r)

	var inner := r.grow(-12.0)
	var edge := Color(Palette.PURPLE.r, Palette.PURPLE.g, Palette.PURPLE.b, 0.35)
	var diag := Color(Palette.MAGENTA.r, Palette.MAGENTA.g, Palette.MAGENTA.b, 0.4)
	draw_rect(inner, edge, false, 2.0)
	draw_line(inner.position, inner.end, diag, 2.0)
	draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), diag, 2.0)
