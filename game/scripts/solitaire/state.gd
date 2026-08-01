class_name SolitaireState
extends RefCounted
## Pure Klondike game logic — no scene nodes. The board view (board.gd) mirrors
## these piles and calls the action methods. Rules: classic Klondike — tableau
## builds down in alternating colour, foundations build up by suit from Ace, only
## a King may start an empty column. See docs/solitaire-requirements.md.

enum Redeal { UNLIMITED, LIMITED }

const TABLEAU_COLUMNS := 7
const FOUNDATION_COUNT := 4
const DRAW3_MAX_PASSES := 3   # classic limited-mode cap for draw-3

# --- config (set before deal) -------------------------------------------------
var draw_count := 1
var redeal_mode: Redeal = Redeal.UNLIMITED

# --- piles (each an Array[SolitaireCard], back() == top) ----------------------
var stock: Array = []
var waste: Array = []
var foundations: Array = []   # 4 arrays
var tableau: Array = []       # 7 arrays

var _passes := 0              # completed stock recycles (draw-3 limit)
var _undo_stack: Array = []   # arrangement snapshots

# --- setup --------------------------------------------------------------------

## Shuffle a 52-card deck and deal the Klondike layout. `rng_seed` >= 0 gives a
## reproducible deal (used by tests); otherwise the deal is random.
func deal(rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var deck: Array = []
	for suit in 4:
		for rank in range(1, 14):
			deck.append(SolitaireCard.new(suit, rank, false))
	# Fisher-Yates shuffle.
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: SolitaireCard = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp

	stock = []
	waste = []
	foundations = [[], [], [], []]
	tableau = []
	for _c in TABLEAU_COLUMNS:
		tableau.append([])
	_passes = 0
	_undo_stack = []

	# Column c gets c+1 cards; only the last (top) is face-up.
	for col in TABLEAU_COLUMNS:
		for row in range(col + 1):
			var card: SolitaireCard = deck.pop_back()
			card.face_up = (row == col)
			tableau[col].append(card)
	# Remaining 24 -> stock, face-down.
	while not deck.is_empty():
		var card: SolitaireCard = deck.pop_back()
		card.face_up = false
		stock.append(card)

# --- rules --------------------------------------------------------------------

## Can `card` be placed on tableau card `onto` (null == empty column)?
func can_stack_tableau(card: SolitaireCard, onto: SolitaireCard) -> bool:
	if onto == null:
		return card.rank == 13   # only a King starts an empty column
	return onto.face_up and card.opposite_color(onto) and card.rank == onto.rank - 1

## Can `card` be placed on the given foundation pile?
func can_stack_foundation(card: SolitaireCard, foundation: Array) -> bool:
	if foundation.is_empty():
		return card.rank == 1    # Ace
	var top: SolitaireCard = foundation.back()
	return card.suit == top.suit and card.rank == top.rank + 1

## The contiguous face-up descending alternating-colour run starting at
## (col, row), or [] if that card can't lead a valid movable run.
func tableau_run(col: int, row: int) -> Array:
	var pile: Array = tableau[col]
	if row < 0 or row >= pile.size():
		return []
	var first: SolitaireCard = pile[row]
	if not first.face_up:
		return []
	var run: Array = [first]
	for i in range(row + 1, pile.size()):
		var prev: SolitaireCard = pile[i - 1]
		var cur: SolitaireCard = pile[i]
		if cur.face_up and cur.opposite_color(prev) and cur.rank == prev.rank - 1:
			run.append(cur)
		else:
			return []
	return run

# --- actions (caller snapshots beforehand for undo) ---------------------------

## Turn `draw_count` cards from stock to waste. Returns true if anything moved.
func draw() -> bool:
	if stock.is_empty():
		return false
	var n: int = mini(draw_count, stock.size())
	for _i in n:
		var card: SolitaireCard = stock.pop_back()
		card.face_up = true
		waste.append(card)
	return true

## Whether the waste can currently be turned back into the stock.
func can_recycle() -> bool:
	if not stock.is_empty() or waste.is_empty():
		return false
	if redeal_mode == Redeal.LIMITED and draw_count == 3:
		return _passes < DRAW3_MAX_PASSES
	return true   # unlimited, or draw-1 (always unlimited, per classic)

## Turn the exhausted waste back into the stock (respecting the redeal limit).
func recycle() -> bool:
	if not can_recycle():
		return false
	while not waste.is_empty():
		var card: SolitaireCard = waste.pop_back()
		card.face_up = false
		stock.append(card)
	_passes += 1
	return true

## Move `cards` (a single card, or a valid tableau run tail) onto tableau column
## `dest_col`. Returns true on success.
func try_move_to_tableau(cards: Array, dest_col: int) -> bool:
	if cards.is_empty():
		return false
	var onto: SolitaireCard = tableau[dest_col].back() if not tableau[dest_col].is_empty() else null
	if not can_stack_tableau(cards[0], onto):
		return false
	if _same_tableau_pile(cards[0], dest_col):
		return false
	_detach(cards)
	tableau[dest_col].append_array(cards)
	return true

## Move a single top `card` onto foundation `dest`. Returns true on success.
func try_move_to_foundation(card: SolitaireCard, dest: int) -> bool:
	if not can_stack_foundation(card, foundations[dest]):
		return false
	_detach([card])
	foundations[dest].append(card)
	return true

## Double-tap behaviour: send `card` to a foundation if it fits, else to a valid
## tableau column (leftmost, preferring a non-empty target). Returns true if moved.
func auto_move(card: SolitaireCard) -> bool:
	var loc := _find(card)
	if loc.is_empty():
		return false
	var run: Array
	if loc["kind"] == "tableau":
		var col: int = loc["index"]
		run = tableau_run(col, tableau[col].find(card))
		if run.is_empty():
			return false
	else:
		var pile: Array = loc["pile"]
		if pile.is_empty() or pile.back() != card:
			return false   # only the top of waste/foundation is actionable
		run = [card]

	# Foundation only accepts a lone card.
	if run.size() == 1:
		for f in FOUNDATION_COUNT:
			if can_stack_foundation(card, foundations[f]):
				_detach([card])
				foundations[f].append(card)
				return true

	# Tableau: leftmost valid non-empty target, else leftmost empty.
	var empty_target := -1
	for col in TABLEAU_COLUMNS:
		if loc["kind"] == "tableau" and loc["index"] == col:
			continue
		var onto: SolitaireCard = tableau[col].back() if not tableau[col].is_empty() else null
		if can_stack_tableau(run[0], onto):
			if onto == null:
				if empty_target == -1:
					empty_target = col
			else:
				_detach(run)
				tableau[col].append_array(run)
				return true
	if empty_target != -1:
		# Don't shuffle a whole King-led column between empty columns (no progress).
		if not (loc["kind"] == "tableau" and run.size() == tableau[loc["index"]].size()):
			_detach(run)
			tableau[empty_target].append_array(run)
			return true
	return false

# --- view helpers -------------------------------------------------------------

## The set of cards that move together if the player grabs `card`, or [] if it
## can't be picked up (only pile tops / valid face-up tableau runs are grabbable).
func grab_run(card: SolitaireCard) -> Array:
	var loc := _find(card)
	match loc.get("kind"):
		"waste", "foundation":
			return [card] if loc["pile"].back() == card else []
		"tableau":
			return tableau_run(loc["index"], tableau[loc["index"]].find(card))
		_:
			return []

## Where a card currently lives: {kind, pile, index?} or {}.
func card_location(card: SolitaireCard) -> Dictionary:
	return _find(card)

# --- queries ------------------------------------------------------------------

func is_won() -> bool:
	for f in foundations:
		if f.size() != 13:
			return false
	return true

## True when nothing is face-down and the stock is spent — the game is a certain
## win and can be auto-completed to the foundations.
func auto_complete_ready() -> bool:
	if is_won() or not stock.is_empty():
		return false
	for col in tableau:
		for card in col:
			if not card.face_up:
				return false
	return true

## During auto-complete: the next card that can go home (waste or a tableau top),
## or null when none remain.
func next_auto_complete_card() -> SolitaireCard:
	var tops: Array = []
	if not waste.is_empty():
		tops.append(waste.back())
	for col in TABLEAU_COLUMNS:
		if not tableau[col].is_empty():
			tops.append(tableau[col].back())
	for card in tops:
		for f in FOUNDATION_COUNT:
			if can_stack_foundation(card, foundations[f]):
				return card
	return null

## Any legal move for the hint feature — the card to highlight, or null.
func hint() -> SolitaireCard:
	# Prefer a card that can go to a foundation.
	var tops: Array = []
	if not waste.is_empty():
		tops.append(waste.back())
	for col in TABLEAU_COLUMNS:
		if not tableau[col].is_empty():
			tops.append(tableau[col].back())
	for card in tops:
		for f in FOUNDATION_COUNT:
			if can_stack_foundation(card, foundations[f]):
				return card
	# Then any tableau/waste move onto another tableau column.
	var movers: Array = []
	if not waste.is_empty():
		movers.append(waste.back())
	for col in TABLEAU_COLUMNS:
		for row in tableau[col].size():
			if not tableau[col][row].face_up:
				continue
			if not tableau_run(col, row).is_empty():
				movers.append(tableau[col][row])
				break
	for card in movers:
		var loc := _find(card)
		var run: Array = [card]
		if loc.get("kind") == "tableau":
			run = tableau_run(loc["index"], tableau[loc["index"]].find(card))
		for col in TABLEAU_COLUMNS:
			if loc.get("kind") == "tableau" and loc["index"] == col:
				continue
			var onto: SolitaireCard = tableau[col].back() if not tableau[col].is_empty() else null
			if can_stack_tableau(run[0], onto):
				# Ignore relocating a whole King-led column to another empty column.
				if onto == null and loc.get("kind") == "tableau" and run.size() == tableau[loc["index"]].size():
					continue
				return card
	return null

# --- undo (arrangement snapshots preserving card identity) --------------------

func snapshot() -> void:
	_undo_stack.append(_capture())

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_restore(_undo_stack.pop_back())
	return true

func _capture() -> Dictionary:
	# Shallow-copy each pile (same card objects) and record face-up flags, so undo
	# reverses only arrangement + flips and keeps card identity stable for the view.
	var founds: Array = []
	for f in foundations:
		founds.append(f.duplicate())
	var tabs: Array = []
	for t in tableau:
		tabs.append(t.duplicate())
	var flags: Dictionary = {}
	_record_flags(stock, flags)
	_record_flags(waste, flags)
	for f in foundations:
		_record_flags(f, flags)
	for t in tableau:
		_record_flags(t, flags)
	return {
		"stock": stock.duplicate(),
		"waste": waste.duplicate(),
		"foundations": founds,
		"tableau": tabs,
		"passes": _passes,
		"flags": flags,
	}

func _restore(snap: Dictionary) -> void:
	stock = snap["stock"]
	waste = snap["waste"]
	foundations = snap["foundations"]
	tableau = snap["tableau"]
	_passes = snap["passes"]
	var flags: Dictionary = snap["flags"]
	for card in flags:
		card.face_up = flags[card]

func _record_flags(pile: Array, flags: Dictionary) -> void:
	for card in pile:
		flags[card] = card.face_up

# --- internals ----------------------------------------------------------------

## Locate the pile holding `card`. Returns {kind, pile, index?} or {}.
func _find(card: SolitaireCard) -> Dictionary:
	if waste.has(card):
		return {"kind": "waste", "pile": waste}
	for f in FOUNDATION_COUNT:
		if foundations[f].has(card):
			return {"kind": "foundation", "pile": foundations[f], "index": f}
	for c in TABLEAU_COLUMNS:
		if tableau[c].has(card):
			return {"kind": "tableau", "pile": tableau[c], "index": c}
	if stock.has(card):
		return {"kind": "stock", "pile": stock}
	return {}

func _same_tableau_pile(card: SolitaireCard, col: int) -> bool:
	return tableau[col].has(card)

## Remove `cards` (which must be the tail of their source pile) and flip the newly
## exposed tableau card face-up.
func _detach(cards: Array) -> void:
	var src := _find(cards[0])
	var pile: Array = src["pile"]
	for _c in cards:
		pile.pop_back()
	if src["kind"] == "tableau" and not pile.is_empty():
		var top: SolitaireCard = pile.back()
		top.face_up = true
