extends SceneTree
## Headless rules test for MahjongState. Run from the game/ dir:
##   godot --headless --script scripts/mahjong/test_state.gd
## Exits non-zero if any assertion fails.

var _failures := 0

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)

func _initialize() -> void:
	_test_layouts()
	_test_deal()
	_test_free_tiles()
	_test_matching()
	_test_remove_and_undo()
	_test_deadlock_and_shuffle()
	_test_full_game_loop()

	if _failures == 0:
		print("ALL MAHJONG TESTS PASSED")
		quit(0)
	else:
		print("MAHJONG TESTS FAILED: %d" % _failures)
		quit(1)

# --- helpers -------------------------------------------------------------------

func _tile(group: int, rank: int, layer: int, x: int, y: int) -> Dictionary:
	return {"id": y * 100 + x * 10 + layer, "group": group, "rank": rank,
		"layer": layer, "x": x, "y": y}

## A crafted state (not dealt) with the given tiles; ids are indexes.
func _crafted(tiles: Array) -> MahjongState:
	var s := MahjongState.new()
	for i in tiles.size():
		tiles[i]["id"] = i
	s.tiles = tiles
	return s

func _idx_at(s: MahjongState, layer: int, x: int, y: int) -> int:
	for i in s.tiles.size():
		var t: Dictionary = s.tiles[i]
		if t["layer"] == layer and t["x"] == x and t["y"] == y:
			return i
	return -1

# --- tests ---------------------------------------------------------------------

func _test_layouts() -> void:
	var expect := {MahjongLayouts.ID.TURTLE: 144, MahjongLayouts.ID.PYRAMID: 92, MahjongLayouts.ID.GATE: 72}
	for id in expect:
		var n: int = MahjongLayouts.tile_count(id)
		_check(n == expect[id], "layout %d has %d tiles, want %d" % [id, n, expect[id]])
		_check(n % 2 == 0, "layout %d tile count is even" % id)

func _test_deal() -> void:
	for id in [MahjongLayouts.ID.TURTLE, MahjongLayouts.ID.PYRAMID, MahjongLayouts.ID.GATE]:
		var s := MahjongState.new()
		s.deal(id)
		var cells: Array = MahjongLayouts.cells(id)
		_check(s.tiles.size() == cells.size(), "deal %d placed all tiles" % id)
		# Suited/honour kinds must appear evenly (no orphan singles); flowers and
		# seasons are unique tiles that match as groups, so their GROUP total
		# must be even instead.
		var census := {}
		for t in s.tiles:
			var key: int = int(t["group"]) * 100 + int(t["rank"])
			census[key] = census.get(key, 0) + 1
		var group_totals := {}
		for t in s.tiles:
			group_totals[t["group"]] = group_totals.get(t["group"], 0) + 1
		for key in census:
			var group := int(key) / 100
			if group <= MahjongState.Group.DRAGON:
				_check(int(census[key]) % 2 == 0, "deal %d kind %d appears %d times (must be even)" % [id, key, census[key]])
		_check(int(group_totals.get(MahjongState.Group.FLOWER, 0)) % 2 == 0, "deal %d flower group is even" % id)
		_check(int(group_totals.get(MahjongState.Group.SEASON, 0)) % 2 == 0, "deal %d season group is even" % id)
		_check(not s.can_undo(), "fresh deal has no undo history")

	# The full turtle deal uses the entire 144-tile set exactly.
	var s := MahjongState.new()
	s.deal(MahjongLayouts.ID.TURTLE)
	var groups := {}
	for t in s.tiles:
		groups[t["group"]] = groups.get(t["group"], 0) + 1
	_check(int(groups.get(MahjongState.Group.FLOWER, 0)) == 4, "turtle has all 4 flowers")
	_check(int(groups.get(MahjongState.Group.SEASON, 0)) == 4, "turtle has all 4 seasons")
	_check(int(groups.get(MahjongState.Group.WIND, 0)) == 16, "turtle has 16 winds")
	_check(int(groups.get(MahjongState.Group.DRAGON, 0)) == 12, "turtle has 12 dragons")

func _test_free_tiles() -> void:
	var s := MahjongState.new()
	s.deal(MahjongLayouts.ID.TURTLE)
	# Corners and the cap are always free; stacked interior tiles are covered.
	_check(s.is_free(_idx_at(s, 0, 0, 0)), "turtle L0 top-left corner is free")
	_check(s.is_free(_idx_at(s, 0, 11, 7)), "turtle L0 bottom-right corner is free")
	_check(s.is_free(_idx_at(s, 3, 6, 3)), "turtle cap is free")
	_check(not s.is_free(_idx_at(s, 0, 6, 3)), "turtle L0 centre is covered by L1")
	_check(not s.is_free(_idx_at(s, 1, 6, 3)), "turtle L1 centre is covered by L2")
	_check(not s.is_free(_idx_at(s, 2, 6, 3)), "turtle L2 centre is covered by the cap")

	# Crafted: blocked between two neighbours on the same layer.
	var c := _crafted([
		_tile(MahjongState.Group.DOT, 0, 0, 0, 0),
		_tile(MahjongState.Group.DOT, 1, 0, 2, 0),
		_tile(MahjongState.Group.DOT, 2, 0, 4, 0),
	])
	_check(c.is_free(0) and c.is_free(2), "row ends are free")
	_check(not c.is_free(1), "middle tile is blocked on both sides")

func _test_matching() -> void:
	var g := MahjongState.Group
	var s := _crafted([
		_tile(g.DOT, 1, 0, 0, 0),
		_tile(g.DOT, 2, 0, 2, 0),
		_tile(g.BAMBOO, 1, 0, 4, 0),
		_tile(g.BAMBOO, 1, 0, 6, 0),
		_tile(g.WIND, 0, 0, 8, 0),
		_tile(g.WIND, 1, 0, 10, 0),
		_tile(g.FLOWER, 0, 0, 12, 0),
		_tile(g.FLOWER, 3, 0, 14, 0),
		_tile(g.SEASON, 0, 0, 16, 0),
	])
	_check(not s.can_match(0, 1), "same suit different rank does not match")
	_check(s.can_match(2, 3), "identical suited tiles match")
	_check(not s.can_match(4, 5), "different winds do not match")
	_check(s.can_match(6, 7), "any flower matches any flower")
	_check(not s.can_match(6, 8), "flower does not match season")

func _test_remove_and_undo() -> void:
	var g := MahjongState.Group
	var s := _crafted([
		_tile(g.DOT, 5, 0, 0, 0),
		_tile(g.BAMBOO, 5, 0, 2, 0),
		_tile(g.DOT, 5, 0, 4, 0),
	])
	_check(not s.remove_pair(0, 1), "non-matching pair is refused")
	_check(s.tiles.size() == 3, "refused removal leaves the board untouched")
	_check(s.remove_pair(0, 2), "matching free pair is removed")
	_check(s.tiles.size() == 1, "pair removal drops two tiles")
	_check(s.can_undo(), "removal is undoable")
	s.undo()
	_check(s.tiles.size() == 3, "undo restores the pair")

	# Covered tiles can never be removed even if they match.
	var t := _crafted([
		_tile(g.DOT, 5, 0, 0, 0),
		_tile(g.DOT, 5, 0, 2, 0),
		_tile(g.DOT, 5, 1, 1, 0),
	])
	_check(not t.remove_pair(0, 1), "covered pair (tile on top) is refused")

func _test_deadlock_and_shuffle() -> void:
	var g := MahjongState.Group
	# Ends free but kinds differ: deadlock.
	var s := _crafted([
		_tile(g.DOT, 1, 0, 0, 0),
		_tile(g.DOT, 2, 0, 2, 0),
		_tile(g.BAMBOO, 3, 0, 4, 0),
	])
	_check(not s.has_any_match(), "deadlocked board has no match")
	_check(s.hint().is_empty(), "deadlocked board has no hint")

	s.shuffle_remaining()
	_check(s.tiles.size() == 3, "shuffle keeps tile count")
	var census := {}
	for tile in s.tiles:
		var kind := "%d:%d" % [int(tile["group"]), int(tile["rank"])]
		census[kind] = true
	_check(census.size() == 3, "shuffle keeps the multiset of kinds")
	var positions := []
	for tile in s.tiles:
		positions.append([tile["layer"], tile["x"], tile["y"]])
	positions.sort()
	_check(positions[0] == [0, 0, 0] and positions[1] == [0, 2, 0] and positions[2] == [0, 4, 0],
		"shuffle keeps tile positions")
	_check(s.can_undo(), "shuffle snapshots for undo")

	# Non-deadlocked board still reports matches.
	var ok := _crafted([
		_tile(g.DOT, 1, 0, 0, 0),
		_tile(g.DOT, 2, 0, 2, 0),
		_tile(g.DOT, 1, 0, 4, 0),
	])
	_check(ok.has_any_match(), "board with a free pair reports a match")

func _test_full_game_loop() -> void:
	# A real deal must always be finishable via hint/remove with shuffle as the
	# deadlock escape — and undo must work at any point.
	var s := MahjongState.new()
	s.deal(MahjongLayouts.ID.TURTLE)
	var steps := 0
	while not s.is_won() and steps < 20000:
		steps += 1
		var h: Array = s.hint()
		if h.is_empty():
			s.shuffle_remaining()
		else:
			var removed := s.remove_pair(h[0], h[1])
			_check(removed, "hint pair is always removable")
			if not removed:
				break
	_check(s.is_won(), "turtle deal finishes via hint/shuffle loop in %d steps" % steps)
	_check(s.can_undo(), "finished game still has undo history")
