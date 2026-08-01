extends SceneTree
## Headless rules test for SolitaireState. Run from the game/ dir:
##   godot --headless --script scripts/solitaire/test_state.gd
## Exits non-zero if any assertion fails.

var _failures := 0

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)

func _initialize() -> void:
	_test_deal()
	_test_tableau_rules()
	_test_foundation_rules()
	_test_draw_recycle()
	_test_auto_move()
	_test_undo()
	_test_win()

	if _failures == 0:
		print("ALL SOLITAIRE TESTS PASSED")
		quit(0)
	else:
		print("SOLITAIRE TESTS FAILED: %d" % _failures)
		quit(1)

func _count(state: SolitaireState) -> int:
	var n: int = state.stock.size() + state.waste.size()
	for f in state.foundations:
		n += f.size()
	for t in state.tableau:
		n += t.size()
	return n

func _test_deal() -> void:
	var s := SolitaireState.new()
	s.deal(42)
	_check(_count(s) == 52, "deal produces 52 cards")
	_check(s.stock.size() == 24, "stock has 24 after deal")
	var tab := 0
	for i in s.TABLEAU_COLUMNS:
		tab += s.tableau[i].size()
		_check(s.tableau[i].size() == i + 1, "column %d has %d cards" % [i, i + 1])
		_check(s.tableau[i].back().face_up, "column %d top is face-up" % i)
		if s.tableau[i].size() > 1:
			_check(not s.tableau[i][0].face_up, "column %d bottom is face-down" % i)
	_check(tab == 28, "tableau holds 28 cards")

func _test_tableau_rules() -> void:
	var s := SolitaireState.new()
	var red6 := SolitaireCard.new(SolitaireCard.HEARTS, 6, true)
	var blk7 := SolitaireCard.new(SolitaireCard.SPADES, 7, true)
	var red7 := SolitaireCard.new(SolitaireCard.DIAMONDS, 7, true)
	var king := SolitaireCard.new(SolitaireCard.CLUBS, 13, true)
	var queen := SolitaireCard.new(SolitaireCard.SPADES, 12, true)   # black, like the K
	_check(s.can_stack_tableau(red6, blk7), "red 6 stacks on black 7")
	_check(not s.can_stack_tableau(red6, red7), "red 6 does not stack on red 7")
	_check(not s.can_stack_tableau(queen, king), "same-colour Q does not stack on K")
	_check(s.can_stack_tableau(king, null), "King goes on empty column")
	_check(not s.can_stack_tableau(queen, null), "non-King rejected on empty column")

func _test_foundation_rules() -> void:
	var s := SolitaireState.new()
	var found: Array = []
	var ace := SolitaireCard.new(SolitaireCard.SPADES, 1, true)
	var two := SolitaireCard.new(SolitaireCard.SPADES, 2, true)
	var two_h := SolitaireCard.new(SolitaireCard.HEARTS, 2, true)
	_check(s.can_stack_foundation(ace, found), "Ace starts a foundation")
	_check(not s.can_stack_foundation(two, found), "non-Ace rejected on empty foundation")
	found.append(ace)
	_check(s.can_stack_foundation(two, found), "2♠ stacks on A♠")
	_check(not s.can_stack_foundation(two_h, found), "2♥ rejected on A♠ (wrong suit)")

func _test_draw_recycle() -> void:
	var s := SolitaireState.new()
	s.draw_count = 3
	s.redeal_mode = SolitaireState.Redeal.LIMITED
	s.deal(1)
	var passes := 0
	# Exhaust stock then recycle up to the cap.
	while passes < 5:
		while s.draw():
			pass
		if not s.recycle():
			break
		passes += 1
	_check(passes == SolitaireState.DRAW3_MAX_PASSES, "draw-3 limited caps at 3 recycles (got %d)" % passes)

	var u := SolitaireState.new()
	u.draw_count = 3
	u.redeal_mode = SolitaireState.Redeal.UNLIMITED
	u.deal(1)
	var upasses := 0
	while upasses < 6:
		while u.draw():
			pass
		if not u.recycle():
			break
		upasses += 1
	_check(upasses == 6, "draw-3 unlimited keeps recycling (got %d)" % upasses)

func _test_auto_move() -> void:
	var s := SolitaireState.new()
	s.deal(7)
	# Force a known layout: put an Ace on a tableau top, empty a foundation.
	var ace := SolitaireCard.new(SolitaireCard.SPADES, 1, true)
	s.tableau[0] = [ace]
	var moved := s.auto_move(ace)
	_check(moved, "auto_move sends an Ace home")
	_check(s.foundations[0].size() == 1 and s.foundations[0][0] == ace, "Ace landed on a foundation")

	# Card that fits no foundation but fits a tableau.
	var t := SolitaireState.new()
	t.deal(8)
	var blk7 := SolitaireCard.new(SolitaireCard.SPADES, 7, true)
	var red6 := SolitaireCard.new(SolitaireCard.HEARTS, 6, true)
	t.tableau[0] = [blk7]
	t.tableau[1] = [red6]
	var m2 := t.auto_move(red6)
	_check(m2, "auto_move relocates red 6 to black 7 when no foundation fits")
	_check(t.tableau[0].size() == 2 and t.tableau[0].back() == red6, "red 6 moved onto black 7")

func _test_undo() -> void:
	var s := SolitaireState.new()
	s.deal(3)
	var before_stock := s.stock.size()
	var before_waste := s.waste.size()
	s.snapshot()
	s.draw()
	_check(s.stock.size() != before_stock, "draw changed stock")
	_check(s.undo(), "undo returns true")
	_check(s.stock.size() == before_stock, "undo restored stock size")
	_check(s.waste.size() == before_waste, "undo restored waste size")
	_check(not s.can_undo(), "undo stack empty after undo")

func _test_win() -> void:
	var s := SolitaireState.new()
	s.deal(5)
	_check(not s.is_won(), "fresh deal is not won")
	# Fill every foundation with 13 cards.
	s.foundations = [[], [], [], []]
	for suit in 4:
		for rank in range(1, 14):
			s.foundations[suit].append(SolitaireCard.new(suit, rank, true))
	_check(s.is_won(), "13-per-foundation is a win")
