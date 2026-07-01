extends Node3D
## Neon "drone" enemy. Navigates the baked navmesh toward the primary tower
## (climbing ramps as needed), then damages it on arrival. Scales in size, HP,
## damage and colour with the level. Dies when its HP is depleted, dropping a
## few coins. Found by towers via the "enemies" group. Supports a shockwave
## damage-over-time effect.

signal died(enemy)

var max_hp: int = 10
var speed: float = 2.2
var attack_damage: int = 4
var attack_interval: float = 1.0
var coin_drop: int = 2

var _hp: int = 10
var _target := Vector3.ZERO
var _agent: NavigationAgent3D
var _attack_accum := 0.0
var _spin := 0.0
var _dead := false

var _scale := 1.0
var _color := Palette.RED
var _body: MeshInstance3D

# Shockwave damage-over-time.
var _dot_dps := 0.0
var _dot_time := 0.0
var _dot_accum := 0.0

# Slow-tower speed reduction (1.0 = normal).
var _slow_factor := 1.0
var _slow_time := 0.0

## Set by the spawner right after instantiation.
func configure(hp: int, move_speed: float, target: Vector3, damage: int, size: float, color: Color) -> void:
	max_hp = hp
	_hp = hp
	speed = move_speed
	_target = target
	attack_damage = damage
	_scale = size
	_color = color
	coin_drop = 2 + int(round(size * 2.0))   # stronger (bigger) enemies pay out more
	if _agent:
		_agent.target_position = target
	_apply_appearance()

func _ready() -> void:
	add_to_group("enemies")

	_body = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh.radial_segments = 6
	mesh.rings = 3
	_body.mesh = mesh
	add_child(_body)
	_apply_appearance()

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.4
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	call_deferred("_apply_target")

func _apply_appearance() -> void:
	if _body == null:
		return
	_body.scale = Vector3.ONE * _scale
	_body.position = Vector3(0.0, 0.4 * _scale, 0.0)
	_body.material_override = Palette.emissive(_color, 6.5)

func _apply_target() -> void:
	if _agent:
		_agent.target_position = _target

func _process(delta: float) -> void:
	_spin += delta * 2.0
	rotation.y = _spin

	if _dot_time > 0.0:
		_dot_time -= delta
		_dot_accum += _dot_dps * delta
		if _dot_accum >= 1.0:
			var whole := int(_dot_accum)
			_dot_accum -= whole
			take_damage(whole)
			if _dead:
				return
		if _dot_time <= 0.0:
			_dot_dps = 0.0

	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0

	if global_position.distance_to(_target) < 1.2:
		_attack_accum += delta
		if _attack_accum >= attack_interval:
			_attack_accum = 0.0
			GameState.damage_primary(attack_damage)
		return

	if _agent == null or _agent.is_navigation_finished():
		return
	var next := _agent.get_next_path_position()
	global_position = global_position.move_toward(next, speed * _slow_factor * delta)

## Applied by shockwave towers; refreshes rather than stacks.
func apply_dot(dps: float, duration: float) -> void:
	_dot_dps = maxf(_dot_dps, dps)
	_dot_time = maxf(_dot_time, duration)

## Applied by slow towers; the strongest slow in effect wins.
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, factor)
	_slow_time = maxf(_slow_time, duration)

func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp -= amount
	if _hp <= 0:
		_dead = true
		remove_from_group("enemies")
		GameState.add_coins(coin_drop)
		died.emit(self)
		queue_free()
