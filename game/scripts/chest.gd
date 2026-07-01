extends Area3D
## A glowing bonus chest that appears on the terrain. When the player's unit
## reaches it (their monitorable area overlaps), it grants coins and disappears.

signal collected(amount: int)

var reward := 25

func _ready() -> void:
	collision_layer = 0
	collision_mask = GameState.LAYER_PLAYER
	monitoring = true
	monitorable = false

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mesh.mesh = box
	mesh.position = Vector3(0.0, 0.35, 0.0)
	mesh.material_override = Palette.emissive(Palette.GOLD, 4.0)
	add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	col.position = Vector3(0.0, 0.35, 0.0)
	add_child(col)

	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	rotate_y(delta * 1.5)

func _on_area_entered(_area: Area3D) -> void:
	GameState.add_coins(reward)
	collected.emit(reward)
	queue_free()
