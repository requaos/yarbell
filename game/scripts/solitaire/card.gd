class_name SolitaireCard
extends RefCounted
## A single playing card in the Solitaire game. Pure value object, no scene node.
## Suits: 0=♠ 1=♥ 2=♦ 3=♣ (hearts and diamonds are red). Ranks 1..13 (Ace..King).

const SPADES := 0
const HEARTS := 1
const DIAMONDS := 2
const CLUBS := 3

const SUIT_SYMBOLS := ["♠", "♥", "♦", "♣"]
const RANK_LABELS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var suit: int
var rank: int
var face_up: bool

func _init(p_suit: int, p_rank: int, p_face_up: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	face_up = p_face_up

func is_red() -> bool:
	return suit == HEARTS or suit == DIAMONDS

## True when this card and `other` are opposite colours (tableau stacking rule).
func opposite_color(other: SolitaireCard) -> bool:
	return is_red() != other.is_red()

func suit_symbol() -> String:
	return SUIT_SYMBOLS[suit]

func rank_label() -> String:
	return RANK_LABELS[rank]
