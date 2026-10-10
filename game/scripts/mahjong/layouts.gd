class_name MahjongLayouts
extends RefCounted
## Static cell tables for the Mahjong solitaire layouts. A cell is a Dictionary
## {layer, x, y} on a half-tile grid: a tile at (x, y) covers the 2x2 cell block
## from (x, y) to (x+1, y+1), so neighbouring tiles sit two cells apart and
## half-offset stacking is expressible. Pure data — no autoload references.

enum ID { TURTLE, PYRAMID, GATE }

const NAMES := ["Turtle", "Pyramid", "Gate"]

## All cells of a layout, in draw order (bottom layer first, row by row).
static func cells(layout: int) -> Array:
	match layout:
		ID.TURTLE:
			return _turtle()
		ID.PYRAMID:
			return _pyramid()
		ID.GATE:
			return _gate()
		_:
			return _turtle()

static func tile_count(layout: int) -> int:
	return cells(layout).size()

# --- layouts -------------------------------------------------------------------

## The classic 144-tile silhouette: a 12-wide base with pinched rows, a middle
## tier, an upper tier and a single half-offset cap tile.
static func _turtle() -> Array:
	var out: Array = []
	_rect(out, 0, 0, 0, 12, 8)
	# Pinch two rows for the shell silhouette.
	_drop(out, 0, 0, 2)
	_drop(out, 0, 22, 2)
	_drop(out, 0, 0, 12)
	_drop(out, 0, 22, 12)
	_rect(out, 1, 6, 2, 6, 6)
	_rect(out, 2, 8, 4, 5, 3)
	out.append(_cell(3, 13, 6))   # half-offset cap over the upper tier
	return out

## 92 tiles: a wide plateau with a smaller one stacked on top.
static func _pyramid() -> Array:
	var out: Array = []
	_rect(out, 0, 2, 2, 10, 6)
	_rect(out, 1, 4, 4, 8, 4)
	return out

## 72 tiles: a hollow frame with corner caps and a raised lintel.
static func _gate() -> Array:
	var out: Array = []
	_rect(out, 0, 0, 0, 12, 6)
	# Hollow out the window.
	for y in range(4, 8, 2):
		for x in range(4, 20, 2):
			_drop(out, 0, x, y)
	# Lintel across the window and four corner caps.
	_rect(out, 1, 6, 4, 6, 2)
	out.append(_cell(1, 2, 0))
	out.append(_cell(1, 20, 0))
	out.append(_cell(1, 2, 10))
	out.append(_cell(1, 20, 10))
	return out

# --- helpers -------------------------------------------------------------------

static func _cell(layer: int, x: int, y: int) -> Dictionary:
	return {"layer": layer, "x": x, "y": y}

## A w*h block of tiles at tile coordinates (x0, y0). Ordinary neighbours sit
## two cells apart on the half-tile grid so tiles abut edge-to-edge; odd cell
## coordinates are reserved for half-offset stacks (e.g. the turtle cap).
static func _rect(out: Array, layer: int, x0: int, y0: int, w: int, h: int) -> void:
	for y in h:
		for x in w:
			out.append(_cell(layer, x0 + x * 2, y0 + y * 2))

## Remove the cell at (layer, x, y) if present (used to carve shapes).
static func _drop(out: Array, layer: int, x: int, y: int) -> void:
	for i in out.size():
		var c: Dictionary = out[i]
		if c["layer"] == layer and c["x"] == x and c["y"] == y:
			out.remove_at(i)
			return
