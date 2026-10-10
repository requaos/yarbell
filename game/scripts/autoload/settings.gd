extends Node
## App-wide, game-agnostic preferences shared across every game in the Yarbell
## collection. Autoloaded as "Settings". Persisted to user://settings.cfg so
## choices survive app restarts. Per-game run state lives elsewhere (e.g.
## GameState for tower defense).

const _PATH := "user://settings.cfg"

enum SolitaireRedeal { UNLIMITED, LIMITED }

enum MahjongLayout { TURTLE, PYRAMID, GATE }

# Display / audio (shared by all games).
var brightness: float = 1.5:       # top of the 0.5-2.0 options range
	set(v):
		brightness = v
		_save()
var music_volume: float = 0.5:
	set(v):
		music_volume = v
		_save()
var sfx_volume: float = 0.8:
	set(v):
		sfx_volume = v
		_save()

# Solitaire rules (classic defaults: draw 1, unlimited redeals).
var solitaire_draw_count: int = 1:
	set(v):
		solitaire_draw_count = v
		_save()
var solitaire_redeal: SolitaireRedeal = SolitaireRedeal.UNLIMITED:
	set(v):
		solitaire_redeal = v
		_save()

# Mahjong rules (classic default: the turtle layout).
var mahjong_layout: MahjongLayout = MahjongLayout.TURTLE:
	set(v):
		mahjong_layout = v
		_save()

var _loaded := false   # suppress saving while loading initial values

func _ready() -> void:
	_load()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_PATH) == OK:
		brightness = cfg.get_value("display", "brightness", brightness)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		solitaire_draw_count = cfg.get_value("solitaire", "draw_count", solitaire_draw_count)
		solitaire_redeal = cfg.get_value("solitaire", "redeal", solitaire_redeal)
		mahjong_layout = cfg.get_value("mahjong", "layout", mahjong_layout) as MahjongLayout
	_loaded = true

func _save() -> void:
	if not _loaded:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("display", "brightness", brightness)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("solitaire", "draw_count", solitaire_draw_count)
	cfg.set_value("solitaire", "redeal", solitaire_redeal)
	cfg.set_value("mahjong", "layout", mahjong_layout)
	cfg.save(_PATH)
