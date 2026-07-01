extends Node3D
## Free-roaming player unit. Taps on terrain move it there (pathfinding over the
## navmesh, including ramps); tapping a tower moves to it if far, or upgrades it
## if within interact range. Carries a monitorable area so chests can detect it.

signal tower_upgraded(cost: int)
signal upgrade_failed()

var speed := 4.0
var interact_range := 2.5

var _agent: NavigationAgent3D

func _ready() -> void:
	add_to_group("player")
	_build_visual()
	_build_area()
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.3
	_agent.target_desired_distance = 0.3
	add_child(_agent)

func _unhandled_input(event: InputEvent) -> void:
	var tapped := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
		pos = event.position
	if tapped:
		_handle_tap(pos)

func _handle_tap(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = GameState.LAYER_TERRAIN | GameState.LAYER_TOWER
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit["collider"]
	if collider.has_meta("tower"):
		var tower = collider.get_meta("tower")
		if global_position.distance_to(tower.global_position) <= interact_range:
			_try_upgrade(tower)
		else:
			_move_to(tower.global_position)
	else:
		_move_to(hit["position"])

func _try_upgrade(tower) -> void:
	var cost: int = tower.get_upgrade_cost()
	if GameState.spend(cost):
		tower.upgrade()
		tower_upgraded.emit(cost)
	else:
		upgrade_failed.emit()

func _move_to(target: Vector3) -> void:
	if _agent:
		_agent.target_position = target

func _process(delta: float) -> void:
	if _agent == null or _agent.is_navigation_finished():
		return
	var next := _agent.get_next_path_position()
	global_position = global_position.move_toward(next, speed * delta)

# --- setup --------------------------------------------------------------------

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.3
	cone.height = 0.7
	cone.radial_segments = 4
	body.mesh = cone
	body.position = Vector3(0.0, 0.35, 0.0)
	body.material_override = Palette.emissive(Color(0.4, 1.0, 1.0), 6.5)
	add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	head.mesh = sphere
	head.position = Vector3(0.0, 0.85, 0.0)
	head.material_override = Palette.emissive(Color.WHITE, 8.0)
	add_child(head)

func _build_area() -> void:
	var area := Area3D.new()
	area.collision_layer = GameState.LAYER_PLAYER
	area.collision_mask = 0
	area.monitorable = true
	area.monitoring = false
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	col.position = Vector3(0.0, 0.4, 0.0)
	area.add_child(col)
	add_child(area)
