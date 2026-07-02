class_name WaveSpawner
extends Node
## Runs a level as a sequence of waves. Each wave spawns a batch of normal
## monsters from the map-edge spawn points, then caps off with a mini-boss; the
## final wave caps off with a full boss instead. A wave is cleared once every one
## of its monsters is dead, after which a short intermission precedes the next.
## The level is cleared when the final (boss) wave is cleared.

const EnemyScene := preload("res://scenes/entities/enemy.tscn")

signal cleared()
signal announce(text: String, color: Color)

enum { PHASE_LEADIN, PHASE_SPAWNING, PHASE_CLEARING, PHASE_INTERMISSION, PHASE_DONE }

const LEADIN := 1.5
const INTERMISSION := 3.0

var _parent: Node
var _spawns: Array = []
var _target := Vector3.ZERO
var _cfg: Dictionary = {}

var _waves: Array = []   # each: { "normals": int, "boss_rank": int }
var _wave := 0
var _phase := PHASE_LEADIN
var _timer := 0.0
var _spawn_accum := 0.0
var _normals_left := 0
var _boss_pending := false
var _alive := 0
var _wave_total := 0

func start(parent: Node, spawn_points: Array, target: Vector3, cfg: Dictionary) -> void:
	_parent = parent
	_spawns = spawn_points
	_target = target
	_cfg = cfg
	_build_waves()
	_wave = 0
	_phase = PHASE_LEADIN
	_timer = LEADIN
	GameState.wave_changed.emit(1, _waves.size())
	GameState.enemies_changed.emit(0, 0)

func _build_waves() -> void:
	var total := int(_cfg["total_enemies"])
	var count := maxi(1, int(_cfg.get("waves", 3)))
	_waves.clear()
	var per := maxi(1, int(round(float(total) / float(count))))
	var assigned := 0
	for i in count:
		var normals := per
		if i == count - 1:
			normals = maxi(1, total - assigned)   # remainder lands on the last wave
		assigned += normals
		var boss_rank: int = Enemy.Rank.BOSS if i == count - 1 else Enemy.Rank.MINI_BOSS
		_waves.append({"normals": normals, "boss_rank": boss_rank})

func _process(delta: float) -> void:
	match _phase:
		PHASE_LEADIN, PHASE_INTERMISSION:
			_timer -= delta
			if _timer <= 0.0:
				_begin_wave()
		PHASE_SPAWNING:
			_spawn_accum += delta
			if _spawn_accum >= float(_cfg["spawn_interval"]):
				_spawn_accum = 0.0
				if _normals_left > 0:
					_spawn(Enemy.Rank.NORMAL)
					_normals_left -= 1
				elif _boss_pending:
					_spawn_boss()
					_boss_pending = false
					_phase = PHASE_CLEARING
		PHASE_CLEARING:
			if _alive <= 0:
				_end_wave()

func _begin_wave() -> void:
	var def: Dictionary = _waves[_wave]
	_normals_left = int(def["normals"])
	_boss_pending = true
	_alive = 0
	_wave_total = _normals_left + 1
	_spawn_accum = float(_cfg["spawn_interval"])   # spawn the first monster immediately
	_phase = PHASE_SPAWNING
	GameState.wave_changed.emit(_wave + 1, _waves.size())
	GameState.enemies_changed.emit(0, _wave_total)
	announce.emit("WAVE %d / %d" % [_wave + 1, _waves.size()], Palette.CYAN)

func _end_wave() -> void:
	if _wave >= _waves.size() - 1:
		_phase = PHASE_DONE
		cleared.emit()
	else:
		_wave += 1
		_phase = PHASE_INTERMISSION
		_timer = INTERMISSION
		announce.emit("WAVE %d INCOMING" % (_wave + 1), Palette.GOLD)

func _spawn(rank: int) -> void:
	var enemy := EnemyScene.instantiate()
	_parent.add_child(enemy)
	enemy.global_position = _spawns[randi() % _spawns.size()]
	enemy.configure(
		int(_cfg["enemy_hp"]),
		float(_cfg["enemy_speed"]),
		_target,
		int(_cfg["enemy_damage"]),
		float(_cfg["enemy_scale"]),
		_cfg["enemy_color"],
		rank)
	enemy.died.connect(_on_enemy_died)
	_alive += 1
	GameState.enemies_changed.emit(_alive, _wave_total)

func _spawn_boss() -> void:
	var rank := int(_waves[_wave]["boss_rank"])
	_spawn(rank)
	if rank == Enemy.Rank.BOSS:
		announce.emit("⚠  BOSS  ⚠", Color(1.0, 0.4, 0.12))
	else:
		announce.emit("MINI-BOSS!", Color(0.72, 0.35, 1.0))

func _on_enemy_died(_enemy) -> void:
	_alive -= 1
	GameState.enemies_changed.emit(_alive, _wave_total)
