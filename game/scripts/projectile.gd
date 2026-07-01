extends Node3D
## Slow-moving missile fired by a missile tower. Flies toward a target point and,
## on arrival, explodes with a small area-of-effect blast that damages every
## enemy within the blast radius.

var speed := 6.0
var damage := 6
var blast_radius := 2.0
var color := Color(1.0, 0.55, 0.15)

var _target := Vector3.ZERO
var _mesh: MeshInstance3D

func configure(target: Vector3, move_speed: float, dmg: int, radius: float, tint: Color) -> void:
	_target = target
	speed = move_speed
	damage = dmg
	blast_radius = radius
	color = tint
	if _mesh:
		_mesh.material_override = Palette.emissive(color, 6.0)

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	_mesh.mesh = sphere
	_mesh.material_override = Palette.emissive(color, 6.0)
	add_child(_mesh)

func _process(delta: float) -> void:
	var to := _target - global_position
	if to.length() < 0.35:
		_explode()
		return
	global_position += to.normalized() * speed * delta

func _explode() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.global_position.distance_to(global_position) <= blast_radius:
			e.take_damage(damage)
	_spawn_blast()
	queue_free()

func _spawn_blast() -> void:
	var blast := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = blast_radius
	sphere.height = blast_radius * 2.0
	blast.mesh = sphere
	blast.material_override = Palette.emissive(color, 5.0)
	blast.scale = Vector3.ONE * 0.2
	get_parent().add_child(blast)
	blast.global_position = global_position
	var tween := blast.create_tween()
	tween.tween_property(blast, "scale", Vector3.ONE, 0.18)
	tween.parallel().tween_property(blast, "transparency", 1.0, 0.18)
	tween.tween_callback(blast.queue_free)
