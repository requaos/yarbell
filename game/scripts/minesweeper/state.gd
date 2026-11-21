class_name MinesweeperState
extends RefCounted
## Pure game logic for Minesweeper. Owns the grid, mine placement (after the
## safe first reveal), adjacency counts, flags, flood-fill reveals and
## chording. No autoload or scene references — headless-testable (see
## test_state.gd). Cells are indexed row-major: i = y * width + x.

signal changed

enum Difficulty { BEGINNER, INTERMEDIATE, EXPERT }

const SIZES := {
	Difficulty.BEGINNER: {"w": 9, "h": 9, "mines": 10},
	Difficulty.INTERMEDIATE: {"w": 16, "h": 16, "mines": 40},
	Difficulty.EXPERT: {"w": 30, "h": 16, "mines": 99},
}

var width := 9
var height := 9
var mine_total := 10

var _mines: Array = []        # bool per cell
var _adjacent: Array = []     # int per cell
var _revealed: Array = []     # bool per cell
var _flagged: Array = []      # bool per cell
var _mines_placed := false
var _lost := false
var _exploded := -1

# --- setup ---------------------------------------------------------------------

func new_game(difficulty: int) -> void:
	var cfg: Dictionary = SIZES.get(difficulty, SIZES[Difficulty.BEGINNER])
	_setup(int(cfg["w"]), int(cfg["h"]), int(cfg["mines"]))

func _setup(w: int, h: int, mines: int) -> void:
	width = w
	height = h
	mine_total = mines
	_mines = []
	_adjacent = []
	_revealed = []
	_flagged = []
	for i in w * h:
		_mines.append(false)
		_adjacent.append(0)
		_revealed.append(false)
		_flagged.append(false)
	_mines_placed = false
	_lost = false
	_exploded = -1
	changed.emit()

## Test hook: custom board geometry (see debug_place_mines).
func debug_setup(w: int, h: int, mines: int) -> void:
	_setup(w, h, mines)

## Test hook: place an explicit mine set (indexes) and compute adjacency.
func debug_place_mines(positions: Array) -> void:
	for i in width * height:
		_mines[i] = false
	for p in positions:
		_mines[p] = true
	_mines_placed = true
	_exploded = -1
	_lost = false
	_recompute_adjacent()
	changed.emit()

## Scatter mine_total mines, excluding the 3x3 neighbourhood of `safe`
## (falls back to excluding just `safe`, then to no exclusion, if too tight).
func _place_mines(safe: int) -> void:
	var exclude := {}
	for n in neighbors(safe):
		exclude[n] = true
	exclude[safe] = true
	if width * height - exclude.size() < mine_total:
		exclude = {safe: true}
	if width * height - exclude.size() < mine_total:
		exclude = {}
	var pool: Array = []
	for i in width * height:
		if not exclude.has(i):
			pool.append(i)
	pool.shuffle()
	for m in mini(mine_total, pool.size()):
		_mines[pool[m]] = true
	_mines_placed = true
	_recompute_adjacent()

func _recompute_adjacent() -> void:
	for i in width * height:
		var count := 0
		for n in neighbors(i):
			if _mines[n]:
				count += 1
		_adjacent[i] = count

# --- queries -------------------------------------------------------------------

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

## Valid neighbour indexes of cell i (no diagonals skipped — 8-neighbourhood).
func neighbors(i: int) -> Array:
	var out: Array = []
	var x := i % width
	var y := i / width
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if in_bounds(nx, ny):
				out.append(ny * width + nx)
	return out

func is_mine(i: int) -> bool:
	return _mines[i]

func is_revealed(i: int) -> bool:
	return _revealed[i]

func is_flagged(i: int) -> bool:
	return _flagged[i]

func adjacent_count(i: int) -> int:
	return _adjacent[i]

func has_lost() -> bool:
	return _lost

## The cell the losing reveal happened on, or -1.
func exploded_at() -> int:
	return _exploded

## Every safe cell revealed.
func is_won() -> bool:
	for i in width * height:
		if not _mines[i] and not _revealed[i]:
			return false
	return true

## Total mines minus flags placed (can go negative).
func remaining_mines() -> int:
	var flags := 0
	for f in _flagged:
		if f:
			flags += 1
	return mine_total - flags

func all_mines() -> Array:
	return _mines

# --- actions -------------------------------------------------------------------

## Reveal a covered, unflagged cell. Places mines safely on the first reveal.
## Returns true if this reveal hit a mine.
func reveal(i: int) -> bool:
	if _lost or _revealed[i] or _flagged[i]:
		return false
	if not _mines_placed:
		_place_mines(i)
	if _mines[i]:
		_lost = true
		_exploded = i
		_revealed[i] = true
		changed.emit()
		return true
	_flood(i)
	changed.emit()
	return false

## Flood-fill the zero region containing i (revealing the numbered frontier).
func _flood(start: int) -> void:
	var stack: Array = [start]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if _revealed[i] or _flagged[i] or _mines[i]:
			continue
		_revealed[i] = true
		if _adjacent[i] == 0:
			for n in neighbors(i):
				if not _revealed[n]:
					stack.append(n)

## Flag/unflag a covered cell. No-op on revealed cells or after a loss.
func toggle_flag(i: int) -> void:
	if _lost or _revealed[i]:
		return
	_flagged[i] = not _flagged[i]
	changed.emit()

## Chord a revealed number: if its flags match the count, reveal every
## unflagged covered neighbour (any of them may be a mine). Returns true if a
## mine was hit.
func chord(i: int) -> bool:
	if _lost or not _revealed[i] or _adjacent[i] == 0:
		return false
	var flags := 0
	for n in neighbors(i):
		if _flagged[n]:
			flags += 1
	if flags != _adjacent[i]:
		return false
	var hit := false
	for n in neighbors(i):
		if not _flagged[n] and not _revealed[n]:
			if reveal(n):
				hit = true
	return hit
