class_name TerrainGenerator
extends RefCounted
## Procedurally builds a chain of plateaus at rising elevations, connected by
## ramps, forming the walkable route from the spawn plateau up to the primary
## tower on the top plateau. Every non-plateau cell becomes a solid wall block,
## so the navmesh only covers the plateaus + ramps: enemies are forced along the
## climbing route, past the towers placed on each plateau, and the ramps act as
## elevation chokepoints. Deterministic per level number.
##
## Plateau/ramp surfaces are StaticBody3D + BoxMesh + BoxShape3D on the TERRAIN
## layer (feed the navmesh bake and tap rays). Walls are visual-only (no
## collider) so they stay out of the navmesh.

enum { WALL, PLATEAU, RAMP }

const GRID_W := 16
const GRID_H := 16
const STEP := 0.6                # elevation gained per plateau
const BASE_THICKNESS := 0.3
const RAMP_WIDTH := 2.0
const CANYON_STEP := 0.7
const GridShader := preload("res://assets/shaders/grid.gdshader")

var _rng := RandomNumberGenerator.new()
var _cells: Array = []
var _plateaus: Array = []        # [{x0, x1, z0, z1, elev}] front -> top
var _grid_mat: ShaderMaterial
var _wall_mats: Dictionary = {}

func generate(region: NavigationRegion3D, level: int, site_count: int) -> Dictionary:
	_rng.seed = level * 1013 + 17
	_init_cells()
	_plateaus = _build_plateaus()
	_mark_cells()

	for p in _plateaus:
		_build_plateau(region, p)
	for i in range(_plateaus.size() - 1):
		_build_ramp_between(region, _plateaus[i], _plateaus[i + 1])
	_build_walls(region)

	return _collect_data(site_count)

# --- layout -------------------------------------------------------------------

func _build_plateaus() -> Array:
	var plateaus: Array = []
	var num := _rng.randi_range(2, 3)
	var z0 := 1
	var elev := 0
	var prev = null
	for p in num:
		var depth := _rng.randi_range(3, 4)
		var width := _rng.randi_range(4, 5)
		var z1 := z0 + depth - 1
		if z1 > GRID_H - 2:
			break
		var x0: int
		if prev == null:
			x0 = _rng.randi_range(1, GRID_W - 1 - width)
		else:
			var span: int = mini(width, prev.x1 - prev.x0 + 1)
			var max_shift: int = maxi(0, span - 2)
			var shift := _rng.randi_range(-max_shift, max_shift)
			x0 = clampi(prev.x0 + shift, 1, GRID_W - 1 - width)
			# Guarantee at least 2 cells of x-overlap for the ramp.
			var overlap: int = mini(x0 + width - 1, prev.x1) - maxi(x0, prev.x0) + 1
			if overlap < 2:
				x0 = clampi(prev.x0, 1, GRID_W - 1 - width)
		var rect := {"x0": x0, "x1": x0 + width - 1, "z0": z0, "z1": z1, "elev": elev}
		plateaus.append(rect)
		prev = rect
		elev += 1
		z0 = z1 + 2   # one-cell gap between plateaus for the ramp
	return plateaus

func _mark_cells() -> void:
	for p in _plateaus:
		for ix in range(p.x0, p.x1 + 1):
			for iz in range(p.z0, p.z1 + 1):
				_cells[ix][iz] = PLATEAU
	# Mark the ramp gap rows so walls don't bury the ramps.
	for i in range(_plateaus.size() - 1):
		var a = _plateaus[i]
		var b = _plateaus[i + 1]
		var ox0: int = maxi(a.x0, b.x0)
		var ox1: int = mini(a.x1, b.x1)
		for ix in range(ox0, ox1 + 1):
			_cells[ix][a.z1 + 1] = RAMP

# --- geometry -----------------------------------------------------------------

func _build_plateau(region: NavigationRegion3D, p: Dictionary) -> void:
	var w: int = p.x1 - p.x0 + 1
	var d: int = p.z1 - p.z0 + 1
	var top: float = p.elev * STEP
	var height: float = top + BASE_THICKNESS
	var center := Vector3(
		(p.x0 + w / 2.0) - GRID_W / 2.0,
		top - height / 2.0,
		(p.z0 + d / 2.0) - GRID_H / 2.0)
	region.add_child(_make_box_body(Vector3(w, height, d), center, _grid_material()))

func _build_ramp_between(region: NavigationRegion3D, a: Dictionary, b: Dictionary) -> void:
	var ox0: int = maxi(a.x0, b.x0)
	var ox1: int = mini(a.x1, b.x1)
	var xc: float = ((ox0 + ox1 + 1) / 2.0) - GRID_W / 2.0
	var ramp_w: float = minf(RAMP_WIDTH, float(ox1 - ox0 + 1))
	var low := Vector3(xc, a.elev * STEP, (a.z1 + 1) - GRID_H / 2.0)
	var high := Vector3(xc, b.elev * STEP, b.z0 - GRID_H / 2.0)
	var length := high.distance_to(low)

	var body := StaticBody3D.new()
	body.collision_layer = GameState.LAYER_TERRAIN
	body.collision_mask = 0
	region.add_child(body)
	body.global_position = (high + low) / 2.0
	body.look_at(body.global_position + (low - high), Vector3.UP)

	var size := Vector3(ramp_w, 0.15, length)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = Palette.emissive(Palette.PURPLE, 2.5)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

func _build_walls(region: NavigationRegion3D) -> void:
	for ix in GRID_W:
		for iz in GRID_H:
			if _cells[ix][iz] != WALL:
				continue
			var tiers := _rng.randi_range(1, 3)
			var h := tiers * CANYON_STEP
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.0, h, 1.0)
			mesh.mesh = box
			mesh.position = _cell_center(ix, iz, h / 2.0)
			mesh.material_override = _wall_material(tiers)
			region.add_child(mesh)

func _make_box_body(size: Vector3, center: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameState.LAYER_TERRAIN
	body.collision_mask = 0
	body.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

func _cell_center(ix: float, iz: float, y: float) -> Vector3:
	return Vector3(ix - GRID_W / 2.0 + 0.5, y, iz - GRID_H / 2.0 + 0.5)

func _grid_material() -> ShaderMaterial:
	if _grid_mat == null:
		_grid_mat = ShaderMaterial.new()
		_grid_mat.shader = GridShader
		_grid_mat.set_shader_parameter("line_color", Vector3(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b))
		_grid_mat.set_shader_parameter("bg_color", Vector3(0.02, 0.02, 0.08))
		_grid_mat.set_shader_parameter("cell_size", 1.0)
		_grid_mat.set_shader_parameter("line_width", 0.05)
		_grid_mat.set_shader_parameter("glow", 1.6)
	return _grid_mat

func _wall_material(tiers: int) -> StandardMaterial3D:
	if not _wall_mats.has(tiers):
		var palette := [Palette.PURPLE, Palette.MAGENTA, Palette.CYAN]
		var col: Color = palette[(tiers - 1) % palette.size()]
		_wall_mats[tiers] = Palette.emissive(col.darkened(0.25), 0.8)
	return _wall_mats[tiers]

# --- data ---------------------------------------------------------------------

func _collect_data(site_count: int) -> Dictionary:
	var front: Dictionary = _plateaus[0]
	var top: Dictionary = _plateaus[_plateaus.size() - 1]

	var primary := _cell_center((top.x0 + top.x1 + 1) / 2.0 - 0.5, top.z1, top.elev * STEP)

	var spawns: Array = []
	for ix in range(front.x0, front.x1 + 1):
		spawns.append(_cell_center(ix, front.z0, front.elev * STEP))

	var walkable: Array = []
	for p in _plateaus:
		for ix in range(p.x0, p.x1 + 1):
			for iz in range(p.z0, p.z1 + 1):
				walkable.append(_cell_center(ix, iz, p.elev * STEP))

	var player_start := _cell_center((front.x0 + front.x1) / 2.0, front.z0 + 1, front.elev * STEP)

	return {
		"primary_position": primary,
		"spawn_points": spawns,
		"secondary_sites": _pick_sites(site_count, primary),
		"walkable_points": walkable,
		"player_start": player_start,
		"terrain_size": Vector2(GRID_W, GRID_H),
	}

## Distribute towers across the plateaus (round-robin) so enemies pass towers on
## every level of the climb. Picks edge cells that still cover the crossing route.
func _pick_sites(site_count: int, primary: Vector3) -> Array:
	var per_plateau: Array = []
	for p in _plateaus:
		var cells: Array = [
			_cell_center(p.x0, p.z0, p.elev * STEP),
			_cell_center(p.x1, p.z1, p.elev * STEP),
			_cell_center(p.x0, p.z1, p.elev * STEP),
			_cell_center(p.x1, p.z0, p.elev * STEP),
		]
		_shuffle(cells)
		per_plateau.append(cells)

	var sites: Array = []
	var round := 0
	while sites.size() < site_count and round < 4:
		for cells in per_plateau:
			if sites.size() >= site_count:
				break
			if round < cells.size():
				var pos: Vector3 = cells[round]
				if pos.distance_to(primary) > 1.2:
					sites.append(pos)
		round += 1
	return sites

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _init_cells() -> void:
	_cells = []
	for ix in GRID_W:
		var col: Array = []
		col.resize(GRID_H)
		col.fill(WALL)
		_cells.append(col)
