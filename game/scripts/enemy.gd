class_name Enemy
extends Node3D
## A little neon monster that navigates the baked navmesh toward the primary tower
## (climbing ramps as needed) and damages it on arrival. Built from cheap
## primitives: a squashed body, glowing eyes with pupils, a crown of horns and
## little feet. It faces where it walks and hops/waddles along.
##
## Three ranks scale size, HP, damage, speed and payout, and change the look:
##   NORMAL     - the level's tinted drones.
##   MINI_BOSS  - a violet brute that ends each wave; carries a health bar.
##   BOSS       - a big fiery brute that ends the final wave; carries a health bar.

signal died(enemy)

enum Rank { NORMAL, MINI_BOSS, BOSS }

# Per-rank multipliers applied to the level's base enemy stats (indexed by Rank).
const RANK_HP := [1.0, 5.0, 12.0]
const RANK_SCALE := [1.0, 1.7, 2.6]
const RANK_SPEED := [1.0, 0.85, 0.7]
const RANK_DAMAGE := [1.0, 2.5, 4.0]
const RANK_COINS := [1.0, 8.0, 20.0]
const RANK_HORNS := [2, 4, 6]

const BODY_ENERGY := 6.0

var max_hp: int = 10
var speed: float = 2.2
var attack_damage: int = 4
var attack_interval: float = 1.0
var coin_drop: int = 2

var _rank := Rank.NORMAL
var _hp: int = 10
var _target := Vector3.ZERO
var _agent: NavigationAgent3D
var _attack_accum := 0.0
var _anim := 0.0
var _hop_rate := 9.0
var _dead := false

var _scale := 1.0
var _color := Palette.RED
var _rig: Node3D
var _body: MeshInstance3D
var _body_mat: StandardMaterial3D

# Boss health bar.
var _hp_bar: Node3D
var _hp_fill_pivot: Node3D

# Shockwave damage-over-time.
var _dot_dps := 0.0
var _dot_time := 0.0
var _dot_accum := 0.0

# Slow-tower speed reduction (1.0 = normal).
var _slow_factor := 1.0
var _slow_time := 0.0

func _ready() -> void:
	add_to_group("enemies")
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.4
	_agent.target_desired_distance = 0.6
	add_child(_agent)

## Set by the spawner right after instantiation. Base stats come from Difficulty;
## the rank multiplies them and drives the look.
func configure(base_hp: int, move_speed: float, target: Vector3, base_damage: int, base_size: float, color: Color, rank: int = Rank.NORMAL) -> void:
	_rank = rank
	max_hp = maxi(1, roundi(float(base_hp) * float(RANK_HP[rank])))
	_hp = max_hp
	speed = move_speed * float(RANK_SPEED[rank])
	_target = target
	attack_damage = maxi(1, roundi(float(base_damage) * float(RANK_DAMAGE[rank])))
	_scale = base_size * float(RANK_SCALE[rank])
	_color = _rank_color(rank, color)
	coin_drop = roundi((2.0 + _scale * 2.0) * float(RANK_COINS[rank]))
	_hop_rate = 9.0 / (1.0 + (_scale - 1.0) * 0.5)
	_build_monster()
	if rank != Rank.NORMAL:
		_build_hp_bar()
	if _agent:
		_agent.target_position = target
	call_deferred("_apply_target")

func _rank_color(rank: int, base: Color) -> Color:
	match rank:
		Rank.MINI_BOSS:
			return Color(0.72, 0.35, 1.0)
		Rank.BOSS:
			return Color(1.0, 0.4, 0.12)
		_:
			return base

func _apply_target() -> void:
	if _agent:
		_agent.target_position = _target

func _process(delta: float) -> void:
	_anim += delta

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

	var moving := false
	if global_position.distance_to(_target) < 1.2:
		_attack_accum += delta
		if _attack_accum >= attack_interval:
			_attack_accum = 0.0
			GameState.damage_primary(attack_damage)
	elif _agent and not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		var dir := next - global_position
		dir.y = 0.0
		if dir.length() > 0.001:
			var target_yaw := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))
		global_position = global_position.move_toward(next, speed * _slow_factor * delta)
		moving = true

	_animate(moving)
	_orient_hp_bar()

func _animate(moving: bool) -> void:
	if _rig == null:
		return
	var s := sin(_anim * _hop_rate)
	var amp := 0.07 if moving else 0.02
	_rig.position.y = absf(s) * amp * _scale
	_rig.rotation.z = s * (0.12 if moving else 0.03)

func _orient_hp_bar() -> void:
	if _hp_bar == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_hp_bar.look_at(cam.global_position, Vector3.UP)

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
	_flash()
	_update_hp_bar()
	if _hp <= 0:
		_dead = true
		remove_from_group("enemies")
		GameState.add_coins(coin_drop)
		Audio.play_sfx("death")
		died.emit(self)
		queue_free()

func _flash() -> void:
	if _body_mat == null:
		return
	_body_mat.emission_energy_multiplier = BODY_ENERGY * 2.2
	var tween := create_tween()
	tween.tween_property(_body_mat, "emission_energy_multiplier", BODY_ENERGY, 0.18)

# --- visual construction ------------------------------------------------------

func _build_monster() -> void:
	if _rig:
		_rig.queue_free()
	_rig = Node3D.new()
	add_child(_rig)

	# Body: a squashed glowing blob.
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 0.55
	body_mesh.radial_segments = 8
	body_mesh.rings = 4
	_body = MeshInstance3D.new()
	_body.mesh = body_mesh
	_body.position = Vector3(0.0, 0.32, 0.0)
	_body.scale = Vector3(1.0, 0.95, 1.05)
	_body_mat = Palette.emissive(_color, BODY_ENERGY)
	_body.material_override = _body_mat
	_rig.add_child(_body)

	# Eyes (front is +Z): white sclera with dark pupils.
	for sx in [-1.0, 1.0]:
		var eye := _add_mesh(_ball(0.09), Vector3(0.12 * sx, 0.42, 0.24), Color(1, 1, 1), 6.0)
		eye.scale = Vector3.ONE
		_add_mesh(_ball(0.045), Vector3(0.12 * sx, 0.42, 0.31), Color(0.03, 0.03, 0.06), 0.15)

	# Horns: a crown across the top; more for bigger ranks.
	var horns: int = RANK_HORNS[_rank]
	var horn_color := _color.lightened(0.35)
	for i in horns:
		var t := 0.0 if horns <= 1 else float(i) / float(horns - 1)
		var x := lerpf(-0.16, 0.16, t)
		var horn := _add_mesh(_cone(0.06, 0.22), Vector3(x, 0.6, -0.02), horn_color, 4.0)
		horn.rotation.z = lerpf(0.35, -0.35, t)

	# Feet: two little nubs up front.
	for sx in [-1.0, 1.0]:
		_add_mesh(_ball(0.09), Vector3(0.13 * sx, 0.06, 0.06), _color.darkened(0.25), 4.0)

	# Bosses get a ridge of back spikes for extra menace.
	if _rank == Rank.BOSS:
		for i in 3:
			var z := lerpf(-0.05, -0.28, float(i) / 2.0)
			var spike := _add_mesh(_cone(0.05, 0.18 - 0.03 * i), Vector3(0.0, 0.5 - 0.04 * i, z), horn_color, 4.5)
			spike.rotation.x = -0.5

	_rig.scale = Vector3.ONE * _scale

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = Palette.emissive(color, energy)
	_rig.add_child(mi)
	return mi

func _ball(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 6
	m.rings = 3
	return m

func _cone(base: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = base
	m.height = height
	m.radial_segments = 4
	return m

# --- boss health bar ----------------------------------------------------------

func _build_hp_bar() -> void:
	var w := 1.1
	var h := 0.14
	_hp_bar = Node3D.new()
	_hp_bar.position = Vector3(0.0, 0.75 * _scale + 0.4, 0.0)
	add_child(_hp_bar)

	var bg := MeshInstance3D.new()
	bg.mesh = _quad(w, h)
	bg.material_override = _bar_mat(Color(0.04, 0.04, 0.08), 1.0)
	_hp_bar.add_child(bg)

	_hp_fill_pivot = Node3D.new()
	_hp_fill_pivot.position = Vector3(-w * 0.5, 0.0, 0.01)
	_hp_bar.add_child(_hp_fill_pivot)

	var fill := MeshInstance3D.new()
	fill.mesh = _quad(w, h)
	fill.position = Vector3(w * 0.5, 0.0, 0.0)
	fill.material_override = _bar_mat(_color, 4.0)
	_hp_fill_pivot.add_child(fill)
	_update_hp_bar()

func _update_hp_bar() -> void:
	if _hp_fill_pivot:
		_hp_fill_pivot.scale.x = clampf(float(_hp) / float(max_hp), 0.0, 1.0)

func _quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q

func _bar_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 10
	return m
