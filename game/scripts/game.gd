extends Node3D
## Root gameplay scene. Sets up the neon look (WorldEnvironment glow), the true
## orthographic isometric camera, and a subtle key light. The Board and HUD are
## instanced as children in game.tscn.

## The level is centered on the origin.
const LEVEL_CENTER := Vector3.ZERO

func _ready() -> void:
	print("Yarbell booted")
	_setup_environment()
	_setup_light()
	_setup_camera()

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
	# Frame the camera to the generated level (built during the Level node's
	# _ready, which runs before this parent's _ready).
	var span := 16.0
	var level := get_node_or_null("Level")
	if level:
		span = maxf(level.terrain_size.x, level.terrain_size.y)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = span * 1.15 + 2.0
	camera.near = 0.05
	camera.far = 300.0
	# Looking from an equal-axis direction yields true isometric projection.
	camera.position = LEVEL_CENTER + Vector3(1.0, 1.0, 1.0).normalized() * 60.0
	add_child(camera)
	camera.look_at(LEVEL_CENTER, Vector3.UP)
	camera.make_current()

func _setup_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 0.6
	sun.light_color = Color(0.6, 0.7, 1.0)
	sun.shadow_enabled = false
	add_child(sun)
