extends Control
## Game-selection screen for the Yarbell collection. Playable games launch their
## scene; games not built yet are shown disabled with a "· soon" label. BACK
## returns to the title screen.

const OptionsModalScene := preload("res://scenes/ui/options_modal.tscn")

# One entry per game. `scene` is empty for games not built yet (shown disabled).
# Adding a game later is a single entry here plus its scene path.
const GAMES := [
	{"name": "TOWER DEFENSE", "scene": "res://scenes/game/game.tscn"},
	{"name": "SOLITAIRE", "scene": "res://scenes/game/solitaire.tscn"},
	{"name": "MAHJONG", "scene": ""},
]

var _options

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "SELECT A GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Palette.CYAN)
	title.add_theme_color_override("font_outline_color", Palette.MAGENTA)
	title.add_theme_constant_override("outline_size", 6)
	vb.add_child(title)

	for game in GAMES:
		var scene: String = game.scene
		if scene.is_empty():
			vb.add_child(NeonUI.disabled_button("%s · soon" % game.name))
		else:
			vb.add_child(NeonUI.menu_button(game.name, _play.bind(scene)))

	vb.add_child(NeonUI.menu_button("BACK", _on_back))

	_options = OptionsModalScene.instantiate()
	_options.show_gear = false
	add_child(_options)

func _play(scene: String) -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file(scene)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
