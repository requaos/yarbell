extends SceneTree
## Headless rules test for MinesweeperState. Run from the game/ dir:
##   godot --headless --path . --script res://scripts/minesweeper/test_state.gd
## Exits non-zero if any assertion fails.

var _failures := 0

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)

func _initialize() -> void:
	_test_adjacency()
	_test_first_reveal_safety()
	_test_flood_fill()
	_test_flags()
	_test_chord_satisfied()
	_test_chord_wrong_flag_hits()
	_test_loss_freezes()

	if _failures == 0:
		print("ALL MINESWEEPER TESTS PASSED")
		quit(0)
	else:
		print("MINESWEEPER TESTS FAILED: %d" % _failures)
		quit(1)

# --- helpers -------------------------------------------------------------------

func _crafted(w: int, h: int, mines: int, mine_positions: Array) -> MinesweeperState:
	var s := MinesweeperState.new()
	s.debug_setup(w, h, mines)
	s.debug_place_mines(mine_positions)
	return s

func _revealed_count(s: MinesweeperState) -> int:
	var n := 0
	for i in s.width * s.height:
		if s.is_revealed(i):
			n += 1
	return n

# --- tests ---------------------------------------------------------------------

func _test_adjacency() -> void:
	# 3x3, mine in the centre: every other cell touches exactly one mine.
	var s := _crafted(3, 3, 1, [4])
	for i in 9:
		if i == 4:
			continue
		_check(s.adjacent_count(i) == 1, "cell %d adjacent to exactly one mine" % i)
	_check(s.neighbors(4).size() == 8, "centre has 8 neighbours")
	_check(s.neighbors(0).size() == 3, "corner has 3 neighbours")
	_check(s.remaining_mines() == 1, "mine counter starts at the mine total")

func _test_first_reveal_safety() -> void:
	for game in 60:
		var s := MinesweeperState.new()
		s.new_game(MinesweeperState.Difficulty.BEGINNER)
		var hit: bool = s.reveal(0)
		_check(not hit, "first reveal never hits a mine (game %d)" % game)
		_check(s.adjacent_count(0) == 0, "first reveal neighbourhood is mine-free (game %d)" % game)
		_check(_revealed_count(s) >= 4, "first reveal floods at least its neighbourhood (game %d)" % game)
		if _failures > 0:
			break
	# Expert geometry places its full mine count after the first reveal (the
	# corner exclusion of 4 cells never crowds out 99 mines on 480 cells).
	var e := MinesweeperState.new()
	e.new_game(MinesweeperState.Difficulty.EXPERT)
	e.reveal(0)
	var total := 0
	for m in e.all_mines():
		if m:
			total += 1
	_check(total == 99, "expert board places all 99 mines")

func _test_flood_fill() -> void:
	# 4x4, one mine in the far corner: revealing the opposite corner floods
	# every safe cell (the mine's neighbours form the numbered frontier).
	var s := _crafted(4, 4, 1, [15])
	var hit: bool = s.reveal(0)
	_check(not hit, "safe reveal does not hit")
	_check(s.is_won(), "flood reveals every safe cell -> won")
	_check(not s.is_revealed(15), "the mine stays covered")
	_check(_revealed_count(s) == 15, "all 15 safe cells revealed")
	_check(s.remaining_mines() == 1, "no flags placed")

func _test_flags() -> void:
	var s := MinesweeperState.new()
	s.new_game(MinesweeperState.Difficulty.BEGINNER)
	# Flagging before the first reveal is allowed.
	s.toggle_flag(0)
	_check(s.is_flagged(0), "covered cell flags")
	_check(s.remaining_mines() == 9, "counter drops per flag")
	_check(not s.reveal(0), "flagged cell cannot be revealed")
	_check(not s.is_revealed(0), "flagged cell stays covered")
	s.toggle_flag(0)
	_check(s.remaining_mines() == 10, "counter restores on unflag")
	# Revealed cells cannot be flagged.
	s.reveal(5)
	s.toggle_flag(5)
	_check(not s.is_flagged(5), "revealed cell cannot be flagged")
	# Counter may go negative (over-flagging) — on a deterministic crafted
	# board where no flood can interfere: 11 flags on a 1-mine 4x4.
	var c := _crafted(4, 4, 1, [15])
	for i in range(11):
		c.toggle_flag(i)
	_check(c.remaining_mines() == -10, "over-flagging drives the counter negative")

func _test_chord_satisfied() -> void:
	# 3x3 centre mine: reveal a corner, flag the mine, chord it to open the
	# adjacent edges; repeat around the board to clear every safe cell.
	var s := _crafted(3, 3, 1, [4])
	_check(not s.chord(0), "chording an unrevealed cell is a no-op")
	s.reveal(0)
	_check(not s.chord(0), "unsatisfied chord (no flags) is a no-op")
	_check(_revealed_count(s) == 1, "unsatisfied chord reveals nothing")
	s.toggle_flag(4)
	s.chord(0)      # opens 1 and 3
	_check(s.is_revealed(1) and s.is_revealed(3), "satisfied chord opens unflagged neighbours")
	s.reveal(2)
	s.chord(2)      # opens 5
	s.reveal(6)
	s.chord(6)      # opens 7
	s.reveal(8)
	_check(s.is_won(), "reveals plus satisfied chords clear the board")
	_check(not s.has_lost(), "correctly-flagged chords never hit")

func _test_chord_wrong_flag_hits() -> void:
	# 2x2, mine bottom-right. Flag the wrong safe cell, chord the number:
	# the unflagged mine opens and the game is lost.
	var s := _crafted(2, 2, 1, [3])
	s.reveal(0)
	s.toggle_flag(1)   # wrong flag on a safe cell
	var hit: bool = s.chord(0)
	_check(hit, "chord with a wrong flag opens the mine")
	_check(s.has_lost(), "wrong-flag chord loses the game")
	_check(s.exploded_at() == 3, "explosion reported on the mine cell")

func _test_loss_freezes() -> void:
	var s := MinesweeperState.new()
	s.new_game(MinesweeperState.Difficulty.BEGINNER)
	s.debug_place_mines([40])
	var hit: bool = s.reveal(40)
	_check(hit, "revealing a mine hits")
	_check(s.has_lost(), "mine hit loses")
	_check(s.is_revealed(40), "the exploded cell is revealed")
	_check(not s.reveal(41), "no further reveals after a loss")
	s.toggle_flag(41)
	_check(not s.is_flagged(41), "no further flags after a loss")
	_check(not s.chord(41), "no further chords after a loss")
	_check(not s.is_won(), "a lost game is not won")
