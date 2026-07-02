extends Node
## Global run state for a Yarbell session. Autoloaded as "GameState".
## Systems mutate these values and the HUD binds to the change signals.

# Physics collision layer bits (Godot layer N -> bit value 1 << (N-1)).
const LAYER_TERRAIN := 1 << 0 # 1
const LAYER_TOWER := 1 << 1   # 2
const LAYER_ENEMY := 1 << 2   # 4
const LAYER_PLAYER := 1 << 3  # 8
const LAYER_CHEST := 1 << 4   # 16

signal coins_changed(value: int)
signal level_changed(value: int)
signal primary_hp_changed(current: int, maximum: int)
signal enemies_changed(alive: int, total: int)
signal wave_changed(current: int, total: int)
signal level_cleared()
signal game_over()

var coins: int = 50:
	set(value):
		coins = maxi(0, value)
		coins_changed.emit(coins)

var level: int = 1:
	set(value):
		level = value
		level_changed.emit(level)

var brightness: float = 1.5   # options default (top of the old 0.5-1.5 range)
var primary_max_hp: int = 100
var primary_hp: int = 100:
	set(value):
		primary_hp = clampi(value, 0, primary_max_hp)
		primary_hp_changed.emit(primary_hp, primary_max_hp)

## Start a fresh run.
func reset() -> void:
	coins = 50
	level = 1

func add_coins(amount: int) -> void:
	coins += amount

## Try to spend; returns true only if affordable.
func spend(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		return true
	return false

func set_primary_max(hp: int) -> void:
	primary_max_hp = hp
	primary_hp = hp

func damage_primary(amount: int) -> void:
	if primary_hp <= 0:
		return
	primary_hp -= amount
	if primary_hp <= 0:
		game_over.emit()
