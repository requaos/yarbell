class_name Tower
extends Node3D
## Procedural neon tower. Four kinds:
##   PRIMARY   - the base the player defends; always active; hitscan + coins.
##   PULSE     - hitscan beam on the nearest enemy.
##   MISSILE   - launches a slow projectile that explodes in an area.
##   SHOCKWAVE - periodically pulses a large-area electric wave (damage-over-time).
##
## Secondary towers start INACTIVE (upgrade level 0): they neither fire nor
## generate coins until the player upgrades them at least once. Each upgrade
## also raises coin output, damage and rate of fire, and grows the tower.

enum Type { PRIMARY, PULSE, MISSILE, SHOCKWAVE, SLOW }

const ProjectileScene := preload("res://scenes/entities/projectile.tscn")

@export var tower_type: int = Type.PULSE
@export var tint: Color = Color(0.0, 1.0, 0.95)

var coin_rate := 5
var income_interval := 2.0
var attack_damage := 4
var attack_range := 4.5
var attack_interval := 0.8
var upgrade_level := 0
var upgrade_cost := 40
var cost_step := 12   # linear cost growth per upgrade (keeps deep leveling affordable)

# Missile
var projectile_speed := 6.0
var blast_radius := 2.0
# Shockwave
var shock_radius := 5.0
var dot_dps := 4.0
var dot_duration := 3.0
# Slow (permanent area-of-effect that reduces enemy speed; stronger per upgrade)
var slow_radius := 4.0
var slow_factor := 0.6

var _income_accum := 0.0
var _attack_accum := 0.0
var _core: MeshInstance3D
var _slow_disc: MeshInstance3D   # Slow tower's ground range disc; only shown when active
var _parts: Array = []   # [MeshInstance3D, Color, float energy] for active/inactive look

func is_active() -> bool:
	return tower_type == Type.PRIMARY or upgrade_level >= 1

func _ready() -> void:
	add_to_group("all_towers")
	_configure_type()
	_build_visual()
	_build_collider()
	_refresh_visual()

func _process(delta: float) -> void:
	if not is_active():
		return
	_income_accum += delta
	if _income_accum >= income_interval:
		_income_accum -= income_interval
		GameState.add_coins(coin_rate)
	_attack_accum += delta
	if _attack_accum >= attack_interval:
		_attack_accum = 0.0
		_fire()

func upgrade() -> void:
	upgrade_level += 1
	coin_rate = roundi(coin_rate * 1.5)
	attack_damage = roundi(attack_damage * 1.25)
	attack_interval = maxf(0.15, attack_interval * 0.85)
	blast_radius *= 1.08
	shock_radius *= 1.06
	dot_dps *= 1.25
	slow_factor = maxf(0.2, slow_factor * 0.85)   # lower = slower enemies
	upgrade_cost += cost_step                       # linear growth, not exponential
	_refresh_visual()
	var target_scale := minf(2.0, 1.0 + (upgrade_level - 1) * 0.12)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * target_scale, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func get_upgrade_cost() -> int:
	return upgrade_cost

# --- firing -------------------------------------------------------------------

func _fire() -> void:
	match tower_type:
		Type.PRIMARY, Type.PULSE:
			var t := _nearest_enemy(attack_range)
			if t:
				t.take_damage(attack_damage)
				_show_beam(t.global_position)
				Audio.play_sfx("fire")
		Type.MISSILE:
			var t := _nearest_enemy(attack_range)
			if t:
				_launch_missile(t.global_position)
				Audio.play_sfx("fire")
		Type.SHOCKWAVE:
			_emit_shockwave()
		Type.SLOW:
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and global_position.distance_to(e.global_position) <= slow_radius:
					e.apply_slow(slow_factor, 0.8)

func _nearest_enemy(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best

func _launch_missile(target: Vector3) -> void:
	var proj := ProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0.0, 0.6, 0.0)
	proj.configure(target, projectile_speed, attack_damage, blast_radius, tint)

func _emit_shockwave() -> void:
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= shock_radius:
			e.apply_dot(dot_dps, dot_duration)
			hit_any = true
	if hit_any:
		_show_shock_ring()

# --- effects ------------------------------------------------------------------

func _show_beam(to: Vector3) -> void:
	var from := global_position + Vector3(0.0, 0.6, 0.0)
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.03
	mesh.height = length
	beam.mesh = mesh
	beam.material_override = Palette.emissive(tint, 6.0)
	get_parent().add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	beam.rotate_object_local(Vector3(1.0, 0.0, 0.0), PI / 2.0)
	get_tree().create_timer(0.09).timeout.connect(func() -> void:
		if is_instance_valid(beam):
			beam.queue_free())

func _show_shock_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
	ring.mesh = torus
	ring.material_override = Palette.emissive(tint, 6.0)
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.2, 0.0)
	var final_scale := shock_radius / 0.6
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(final_scale, 1.0, final_scale), 0.5)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.5)
	tween.tween_callback(ring.queue_free)

# --- setup --------------------------------------------------------------------

func _configure_type() -> void:
	match tower_type:
		Type.PRIMARY:
			tint = Palette.GOLD
			coin_rate = 8
			income_interval = 1.5
			attack_damage = 6
			attack_range = 5.0
			attack_interval = 0.7
			upgrade_level = 1
			upgrade_cost = 40
		Type.PULSE:
			tint = Palette.CYAN
			coin_rate = 4
			attack_damage = 4
			attack_range = 4.5
			attack_interval = 0.8
			upgrade_cost = 25
		Type.MISSILE:
			tint = Color(1.0, 0.55, 0.15)
			coin_rate = 5
			attack_damage = 16
			attack_range = 6.0
			attack_interval = 2.0
			upgrade_cost = 35
			blast_radius = 2.0
		Type.SHOCKWAVE:
			tint = Color(0.7, 0.4, 1.0)
			coin_rate = 5
			attack_damage = 0
			attack_range = shock_radius
			attack_interval = 2.5
			upgrade_cost = 35
		Type.SLOW:
			tint = Color(0.3, 0.8, 1.0)
			coin_rate = 4
			attack_damage = 0
			attack_range = slow_radius
			attack_interval = 0.4
			upgrade_cost = 25

func _refresh_visual() -> void:
	for p in _parts:
		var node: MeshInstance3D = p[0]
		if is_active():
			node.material_override = Palette.emissive(p[1], p[2])
		else:
			node.material_override = Palette.emissive(Color(0.32, 0.32, 0.4), 0.12)
	# The slow field only exists while the tower is active, so its ground disc
	# stays hidden until then (otherwise it reads as a grey circle on the map).
	if _slow_disc:
		_slow_disc.visible = is_active()

func _add_part(node: MeshInstance3D, color: Color, energy: float) -> void:
	add_child(node)
	_parts.append([node, color, energy])

func _build_visual() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.30
	base_mesh.bottom_radius = 0.42
	base_mesh.height = 0.30
	base_mesh.radial_segments = 6
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.15, 0.0)
	_add_part(base, Palette.PURPLE, 2.0)

	_core = MeshInstance3D.new()
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.3, 0.3, 0.3)
	_core.mesh = core_mesh
	_core.position = Vector3(0.0, 0.45, 0.0)
	_add_part(_core, tint, 6.5)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.26
	ring_mesh.outer_radius = 0.36
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, 0.62, 0.0)
	_add_part(ring, tint, 8.0)

	match tower_type:
		Type.PRIMARY:
			var beacon := MeshInstance3D.new()
			var beacon_mesh := CylinderMesh.new()
			beacon_mesh.top_radius = 0.06
			beacon_mesh.bottom_radius = 0.12
			beacon_mesh.height = 0.9
			beacon.mesh = beacon_mesh
			beacon.position = Vector3(0.0, 1.1, 0.0)
			_add_part(beacon, tint, 9.0)
		Type.MISSILE:
			var tube := MeshInstance3D.new()
			var tube_mesh := CylinderMesh.new()
			tube_mesh.top_radius = 0.09
			tube_mesh.bottom_radius = 0.11
			tube_mesh.height = 0.5
			tube.mesh = tube_mesh
			tube.position = Vector3(0.0, 0.78, 0.0)
			_add_part(tube, tint, 5.0)
		Type.SHOCKWAVE:
			var coil := MeshInstance3D.new()
			var coil_mesh := TorusMesh.new()
			coil_mesh.inner_radius = 0.38
			coil_mesh.outer_radius = 0.5
			coil.mesh = coil_mesh
			coil.position = Vector3(0.0, 0.82, 0.0)
			_add_part(coil, tint, 6.0)
		Type.SLOW:
			# Faint disc on the ground showing the slow field's reach.
			var disc := MeshInstance3D.new()
			var disc_mesh := CylinderMesh.new()
			disc_mesh.top_radius = slow_radius
			disc_mesh.bottom_radius = slow_radius
			disc_mesh.height = 0.04
			disc.mesh = disc_mesh
			disc.position = Vector3(0.0, 0.04, 0.0)
			_slow_disc = disc
			_add_part(disc, tint, 0.6)

func _build_collider() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameState.LAYER_TOWER
	body.collision_mask = 0
	body.set_meta("tower", self)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.4, 1.0)
	col.shape = shape
	col.position = Vector3(0.0, 0.7, 0.0)
	body.add_child(col)
	add_child(body)
