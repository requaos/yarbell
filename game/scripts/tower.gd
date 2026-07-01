extends Node3D
## Procedural neon tower. Auto-attacks the nearest enemy in range (hitscan + a
## brief beam), generates coins over time, and can be upgraded to raise both its
## coin production and damage. `is_primary` towers are stronger and are the ones
## the player must protect (their HP lives in GameState).

@export var is_primary := false
@export var tint: Color = Color(0.0, 1.0, 0.95)

var coin_rate := 5
var income_interval := 2.0
var attack_damage := 4
var attack_range := 4.0
var attack_interval := 0.8
var upgrade_level := 1
var upgrade_cost := 40

var _income_accum := 0.0
var _attack_accum := 0.0
var _core: MeshInstance3D

func _ready() -> void:
	add_to_group("all_towers")
	if is_primary:
		coin_rate = 8
		income_interval = 1.5
		attack_damage = 6
		attack_range = 5.0
		upgrade_cost = 60
	_build_visual()
	_build_collider()

func _process(delta: float) -> void:
	_income_accum += delta
	if _income_accum >= income_interval:
		_income_accum -= income_interval
		GameState.add_coins(coin_rate)

	_attack_accum += delta
	if _attack_accum >= attack_interval:
		_attack_accum = 0.0
		var target := _nearest_enemy()
		if target:
			target.take_damage(attack_damage)
			_show_beam(target.global_position)

## Called by the player to upgrade this tower (payment handled by the caller).
func upgrade() -> void:
	upgrade_level += 1
	coin_rate = roundi(coin_rate * 1.5)
	attack_damage = roundi(attack_damage * 1.25)
	attack_interval = maxf(0.15, attack_interval * 0.85)  # faster rate of fire
	upgrade_cost = roundi(upgrade_cost * 1.6)

	# Grow the whole tower with each upgrade (capped), tweened for feedback.
	var target_scale := minf(2.2, 1.0 + (upgrade_level - 1) * 0.15)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * target_scale, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func get_upgrade_cost() -> int:
	return upgrade_cost

# --- internals ----------------------------------------------------------------

func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := attack_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best

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
	beam.rotate_object_local(Vector3(1.0, 0.0, 0.0), PI / 2.0) # cylinder Y-axis -> aim direction
	var timer := get_tree().create_timer(0.09)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(beam):
			beam.queue_free())

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

func _build_visual() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.30
	base_mesh.bottom_radius = 0.42
	base_mesh.height = 0.30
	base_mesh.radial_segments = 6
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.15, 0.0)
	base.material_override = Palette.emissive(Palette.PURPLE, 2.0)
	add_child(base)

	_core = MeshInstance3D.new()
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.3, 0.3, 0.3)
	_core.mesh = core_mesh
	_core.position = Vector3(0.0, 0.45, 0.0)
	_core.material_override = Palette.emissive(tint, 4.0)
	add_child(_core)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.26
	ring_mesh.outer_radius = 0.36
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, 0.62, 0.0)
	ring.material_override = Palette.emissive(tint, 5.0)
	add_child(ring)

	if is_primary:
		# Taller beacon so the primary reads as special.
		var beacon := MeshInstance3D.new()
		var beacon_mesh := CylinderMesh.new()
		beacon_mesh.top_radius = 0.06
		beacon_mesh.bottom_radius = 0.12
		beacon_mesh.height = 0.9
		beacon.mesh = beacon_mesh
		beacon.position = Vector3(0.0, 1.1, 0.0)
		beacon.material_override = Palette.emissive(tint, 6.0)
		add_child(beacon)
