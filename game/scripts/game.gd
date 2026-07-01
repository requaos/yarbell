extends Node3D
## Root gameplay scene. Sets up the neon look (WorldEnvironment glow), the true
## orthographic isometric camera, and a subtle key light. The Board and HUD are
## instanced as children in game.tscn.

## The level is centered on the origin.
const LEVEL_CENTER := Vector3.ZERO

## Orthographic view height in world units (zoom). Lower = closer. Kept at a
## medium distance so a good chunk of the maze around the player is visible.
const CAMERA_SIZE := 16.0
const CAMERA_DISTANCE := 60.0
const CAMERA_FOLLOW := 5.0

var _camera: Camera3D
var _cam_look := Vector3.ZERO   # smoothed point the camera centers on

func _ready() -> void:
	print("Yarbell booted")
	_setup_environment()
	_setup_light()
	_setup_camera()

func _process(delta: float) -> void:
	var level := get_node_or_null("Level")
	if level == null or not is_instance_valid(level.player):
		return
	var target: Vector3 = level.player.global_position
	_cam_look = _cam_look.lerp(target, clampf(delta * CAMERA_FOLLOW, 0.0, 1.0))
	_place_camera()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.BG_DEEP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.10, 0.20)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	# Bloom the emissive neon materials.
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.25
	env.glow_strength = 1.1
	env.glow_hdr_threshold = 0.9
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 1.0)

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_SIZE
	_camera.near = 0.05
	_camera.far = 400.0
	add_child(_camera)

	# Start centered on the player if it exists yet, else the level origin.
	var level := get_node_or_null("Level")
	if level and is_instance_valid(level.player):
		_cam_look = level.player.global_position
	else:
		_cam_look = LEVEL_CENTER
	_place_camera()
	_camera.make_current()

## Keep the isometric view centered on `_cam_look` (offset along the equal-axis
## direction gives true isometric projection).
func _place_camera() -> void:
	_camera.position = _cam_look + Vector3(1.0, 1.0, 1.0).normalized() * CAMERA_DISTANCE
	_camera.look_at(_cam_look, Vector3.UP)

func _setup_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 0.6
	sun.light_color = Color(0.6, 0.7, 1.0)
	sun.shadow_enabled = false
	add_child(sun)
