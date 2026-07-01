extends Node3D
## Neon "drone" enemy. Navigates the baked navmesh toward the primary tower
## (climbing ramps as needed), then damages it on arrival. Dies when its HP is
## depleted, dropping a few coins. Found by towers via the "enemies" group.

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

## Set by the spawner right after instantiation.
func configure(hp: int, move_speed: float, target: Vector3) -> void:
	max_hp = hp
	_hp = hp
	speed = move_speed
	_target = target
	if _agent:
		_agent.target_position = target

func _ready() -> void:
	add_to_group("enemies")

	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh.radial_segments = 6
	mesh.rings = 3
	body.mesh = mesh
	body.position = Vector3(0.0, 0.4, 0.0)
	body.material_override = Palette.emissive(Palette.RED, 4.0)
	add_child(body)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.4
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	# Navmesh/map may need a frame to sync before a path is available.
	call_deferred("_apply_target")

func _apply_target() -> void:
	if _agent:
		_agent.target_position = _target

func _process(delta: float) -> void:
	_spin += delta * 2.0
	rotation.y = _spin

	if global_position.distance_to(_target) < 1.2:
		_attack_accum += delta
		if _attack_accum >= attack_interval:
			_attack_accum = 0.0
			GameState.damage_primary(attack_damage)
		return

	if _agent == null or _agent.is_navigation_finished():
		return
	var next := _agent.get_next_path_position()
	global_position = global_position.move_toward(next, speed * delta)

func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp -= amount
	if _hp <= 0:
		_dead = true
		# Leave the group immediately so towers can't target it again this frame.
		remove_from_group("enemies")
		GameState.add_coins(coin_drop)
		died.emit(self)
		queue_free()
