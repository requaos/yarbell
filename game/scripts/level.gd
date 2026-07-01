extends Node3D
## Orchestrates a single level: procedural terrain, runtime navmesh bake, and
## tower placement. Enemies, player, chests and level progression are layered on
## in later build steps.

const TowerScene := preload("res://scenes/entities/tower.tscn")
const PlayerScene := preload("res://scenes/entities/player.tscn")
const ChestScene := preload("res://scenes/entities/chest.tscn")

const CHEST_INTERVAL := 8.0

var terrain_size := Vector2(14, 14)
var primary_position := Vector3.ZERO
var player: Node3D
var hud: CanvasLayer

var _region: NavigationRegion3D
var _generator := TerrainGenerator.new()
var _data: Dictionary = {}
var _game_over := false

func _ready() -> void:
	hud = get_parent().get_node_or_null("HUD")
	GameState.game_over.connect(_on_game_over)
	start_level(GameState.level)

func start_level(level: int) -> void:
	_clear()
	_configure_nav_map()
	_region = NavigationRegion3D.new()
	add_child(_region)

	var cfg := Difficulty.config_for(level)
	_data = _generator.generate(_region, level, int(cfg["secondary_sites"]))
	terrain_size = _data["terrain_size"]
	primary_position = _data["primary_position"]

	_bake_navmesh()
	GameState.set_primary_max(100)
	_place_towers()
	_spawn_player()
	_start_wave()
	_start_chests()

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = _data["player_start"]
	if hud:
		player.tower_upgraded.connect(func(cost: int) -> void:
			hud.flash("-%d  UPGRADED" % cost, Palette.CYAN))
		player.upgrade_failed.connect(func() -> void:
			hud.flash("NEED MORE COINS", Palette.RED))

func _start_chests() -> void:
	var timer := Timer.new()
	timer.wait_time = CHEST_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_spawn_chest)
	add_child(timer)
	_spawn_chest()

func _spawn_chest() -> void:
	var cells: Array = _data.get("walkable_points", [])
	if cells.is_empty():
		return
	var chest := ChestScene.instantiate()
	add_child(chest)
	chest.global_position = cells[randi() % cells.size()]
	if hud:
		chest.collected.connect(func(amount: int) -> void:
			hud.flash("+%d  COINS" % amount, Palette.GOLD))

func _configure_nav_map() -> void:
	# Align the world navigation map's rasterization to the navmesh cell size so
	# the narrow corridor rasterizes cleanly (avoids cell-size-mismatch errors).
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.2)
	NavigationServer3D.map_set_cell_height(map, 0.1)

func _bake_navmesh() -> void:
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nav.geometry_collision_mask = GameState.LAYER_TERRAIN
	nav.agent_radius = 0.25   # narrow enough for the 2-cell corridor
	nav.agent_height = 1.0
	nav.agent_max_climb = 0.4
	nav.agent_max_slope = 50.0
	nav.cell_size = 0.2
	nav.cell_height = 0.1
	_region.navigation_mesh = nav
	_region.bake_navigation_mesh(false)
	print("Yarbell: navmesh baked (%d polys)" % nav.get_polygon_count())

func _place_towers() -> void:
	var primary := TowerScene.instantiate()
	primary.tower_type = Tower.Type.PRIMARY
	primary.position = primary_position
	add_child(primary)
	primary.add_to_group("primary")

	# One tower per generated site, with a random type (Pulse most common). All
	# secondaries start inactive until the player upgrades them.
	var weighted := [Tower.Type.PULSE, Tower.Type.PULSE, Tower.Type.MISSILE, Tower.Type.SHOCKWAVE]
	for pos in _data["secondary_sites"]:
		var tower := TowerScene.instantiate()
		tower.tower_type = weighted[randi() % weighted.size()]
		tower.position = pos
		add_child(tower)
		tower.add_to_group("towers")

func _start_wave() -> void:
	var cfg := Difficulty.config_for(GameState.level)
	var spawner := WaveSpawner.new()
	add_child(spawner)
	spawner.cleared.connect(_on_level_cleared)
	spawner.start(self, _data["spawn_points"], primary_position, cfg)

func _on_level_cleared() -> void:
	if _game_over:
		return
	GameState.level_cleared.emit()
	await get_tree().create_timer(2.0).timeout
	if _game_over:
		return
	if hud:
		hud.hide_overlay()
	GameState.level += 1
	start_level(GameState.level)

func _on_game_over() -> void:
	_game_over = true
	# Freeze the run; wait for a tap to restart.
	if is_instance_valid(player):
		player.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not _game_over:
		return
	var restart: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if restart:
		_game_over = false
		GameState.reset()
		if hud:
			hud.hide_overlay()
		start_level(GameState.level)

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_region = null
