class_name MahjongState
extends RefCounted
## Pure game logic for Mahjong solitaire. Owns the dealt tiles, the free-tile
## and matching rules, undo history, hints, deadlock detection and shuffling.
## No autoload or scene references — headless-testable (see test_state.gd).
##
## Tiles are Dictionaries: {id, group, rank, layer, x, y}. Grid is the
## half-tile cell grid described in MahjongLayouts; a tile covers the 2x2 block
## from (x, y) to (x+1, y+1).

signal changed

enum Group { DOT, BAMBOO, CHAR, WIND, DRAGON, FLOWER, SEASON }

# Winds 0..3 (E S W N), dragons 0..2 (red green white), flowers/seasons 0..3.
const WIND_LABELS := ["E", "S", "W", "N"]

var tiles: Array = []          # live (not yet removed) tiles
var layout: int = MahjongLayouts.ID.TURTLE

var _next_id := 0
var _history: Array = []       # snapshots of `tiles` (deep copies)

# --- deal ----------------------------------------------------------------------

## Deal `layout` by shuffling the tile set into its cells at pair granularity
## (so every kind keeps an even count and singles can never occur).
func deal(layout: int) -> void:
	self.layout = layout
	var cs: Array = MahjongLayouts.cells(layout)
	var pairs: Array = _build_pairs()
	pairs.shuffle()
	var kinds: Array = []
	for i in cs.size() / 2:
		kinds.append_array(pairs[i])
	kinds.shuffle()
	tiles = []
	_next_id = 0
	_history = []
	for i in cs.size():
		var k: Dictionary = kinds[i]
		var c: Dictionary = cs[i]
		tiles.append({
			"id": _next_id,
			"group": k["group"],
			"rank": k["rank"],
			"layer": c["layer"],
			"x": c["x"],
			"y": c["y"],
		})
		_next_id += 1
	changed.emit()

## Pair list covering the full 144-tile set: suited tiles and honours
## contribute two pairs of identicals each; the four flowers form two pairs and
## so do the four seasons (group matching makes any pairing valid).
func _build_pairs() -> Array:
	var pairs: Array = []
	for g in [Group.DOT, Group.BAMBOO, Group.CHAR]:
		for r in 9:
			pairs.append([{ "group": g, "rank": r }, { "group": g, "rank": r }])
			pairs.append([{ "group": g, "rank": r }, { "group": g, "rank": r }])
	for r in 4:
		pairs.append([{ "group": Group.WIND, "rank": r }, { "group": Group.WIND, "rank": r }])
		pairs.append([{ "group": Group.WIND, "rank": r }, { "group": Group.WIND, "rank": r }])
	for r in 3:
		pairs.append([{ "group": Group.DRAGON, "rank": r }, { "group": Group.DRAGON, "rank": r }])
		pairs.append([{ "group": Group.DRAGON, "rank": r }, { "group": Group.DRAGON, "rank": r }])
	pairs.append([{ "group": Group.FLOWER, "rank": 0 }, { "group": Group.FLOWER, "rank": 1 }])
	pairs.append([{ "group": Group.FLOWER, "rank": 2 }, { "group": Group.FLOWER, "rank": 3 }])
	pairs.append([{ "group": Group.SEASON, "rank": 0 }, { "group": Group.SEASON, "rank": 1 }])
	pairs.append([{ "group": Group.SEASON, "rank": 2 }, { "group": Group.SEASON, "rank": 3 }])
	return pairs

# --- queries -------------------------------------------------------------------

func tile(index: int) -> Dictionary:
	return tiles[index]

func find_id(id: int) -> int:
	for i in tiles.size():
		if tiles[i]["id"] == id:
			return i
	return -1

## A tile is free when nothing lies on top of it and its left or right
## immediate neighbour (same layer, overlapping row span) is absent.
func is_free(index: int) -> bool:
	var t: Dictionary = tiles[index]
	for u in tiles:
		if u["layer"] == t["layer"] + 1 \
				and absi(int(u["x"]) - int(t["x"])) <= 1 \
				and absi(int(u["y"]) - int(t["y"])) <= 1:
			return false   # covered
	var side_free := true
	for u in tiles:
		if u["layer"] == t["layer"] \
				and absi(int(u["y"]) - int(t["y"])) <= 1 \
				and int(u["x"]) == int(t["x"]) - 2:
			side_free = false
			break
	if side_free:
		return true
	for u in tiles:
		if u["layer"] == t["layer"] \
				and absi(int(u["y"]) - int(t["y"])) <= 1 \
				and int(u["x"]) == int(t["x"]) + 2:
			return false   # both sides blocked
	return true

func free_indexes() -> Array:
	var out: Array = []
	for i in tiles.size():
		if is_free(i):
			out.append(i)
	return out

## Flowers match flowers, seasons match seasons; everything else matches by
## group and rank.
func can_match(a: int, b: int) -> bool:
	if a == b:
		return false
	var ta: Dictionary = tiles[a]
	var tb: Dictionary = tiles[b]
	if ta["group"] != tb["group"]:
		return false
	return ta["group"] in [Group.FLOWER, Group.SEASON] or ta["rank"] == tb["rank"]

func has_any_match() -> bool:
	return not hint().is_empty()

## One free matching pair as [index_a, index_b], or [].
func hint() -> Array:
	var free := free_indexes()
	for i in free.size():
		for j in range(i + 1, free.size()):
			if can_match(free[i], free[j]):
				return [free[i], free[j]]
	return []

func is_won() -> bool:
	return tiles.is_empty()

func can_undo() -> bool:
	return not _history.is_empty()

# --- mutations -----------------------------------------------------------------

## Remove a free matching pair. Returns false (untouched) if either tile is not
## free or the pair does not match.
func remove_pair(a: int, b: int) -> bool:
	if not is_free(a) or not is_free(b) or not can_match(a, b):
		return false
	_snapshot()
	if b < a:
		var t := a
		a = b
		b = t
	tiles.remove_at(b)
	tiles.remove_at(a)
	changed.emit()
	return true

## Re-deal the kinds of the remaining tiles onto their current positions.
func shuffle_remaining() -> void:
	if tiles.size() < 2:
		return
	_snapshot()
	var kinds: Array = []
	for t in tiles:
		kinds.append({"group": t["group"], "rank": t["rank"]})
	kinds.shuffle()
	for i in tiles.size():
		tiles[i]["group"] = kinds[i]["group"]
		tiles[i]["rank"] = kinds[i]["rank"]
	changed.emit()

func undo() -> bool:
	if _history.is_empty():
		return false
	tiles = _history.pop_back()
	changed.emit()
	return true

func _snapshot() -> void:
	_history.append(tiles.duplicate(true))
