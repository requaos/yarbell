class_name WaveSpawner
extends Node
## Spawns a level's enemies from the map-edge spawn points over time, tracks how
## many are alive, and reports clearance once all are spawned and defeated.

const EnemyScene := preload("res://scenes/entities/enemy.tscn")

signal cleared()

var _parent: Node
var _spawns: Array = []
var _target := Vector3.ZERO
var _cfg: Dictionary = {}

var _total := 0
var _spawned := 0
var _alive := 0
var _accum := 0.0
var _active := false

func start(parent: Node, spawn_points: Array, target: Vector3, cfg: Dictionary) -> void:
	_parent = parent
	_spawns = spawn_points
	_target = target
	_cfg = cfg
	_total = int(cfg["total_enemies"])
	_spawned = 0
	_alive = 0
	_accum = 0.0
	_active = true
	GameState.enemies_changed.emit(0, _total)

func _process(delta: float) -> void:
	if not _active:
		return
	if _spawned < _total:
		_accum += delta
		if _accum >= float(_cfg["spawn_interval"]):
			_accum = 0.0
			_spawn_one()
	elif _alive <= 0:
		_active = false
		cleared.emit()

func _spawn_one() -> void:
	var enemy := EnemyScene.instantiate()
	_parent.add_child(enemy)
	enemy.global_position = _spawns[_spawned % _spawns.size()]
	enemy.configure(
		int(_cfg["enemy_hp"]),
		float(_cfg["enemy_speed"]),
		_target,
		int(_cfg["enemy_damage"]),
		float(_cfg["enemy_scale"]),
		_cfg["enemy_color"])
	enemy.died.connect(_on_enemy_died)
	_spawned += 1
	_alive += 1
	GameState.enemies_changed.emit(_alive, _total)

func _on_enemy_died(_enemy) -> void:
	_alive -= 1
	GameState.enemies_changed.emit(_alive, _total)
