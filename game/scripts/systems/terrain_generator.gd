class_name TerrainGenerator
extends RefCounted
## Procedurally builds a serpentine of terraces: wide plateaus stacked at rising
## elevations, each connected to the next by a ramp placed at alternating ends
## (right, left, right, ...). Enemies must traverse the full width of a terrace,
## climb the ramp, cross back the other way, climb again — a long switchback
## path from the entry edge up to the primary tower on the top terrace, using
## the whole landscape. Towers sit along each terrace, so enemies pass them the
## entire way up, and the ramps are elevation chokepoints. Deterministic per
## level number.
##
## Terrace/ramp surfaces are StaticBody3D + BoxMesh + BoxShape3D on the TERRAIN
## layer (feed the navmesh bake and tap rays). Walls are visual-only (no
## collider) so they stay out of the navmesh.

enum { WALL, PLATEAU, RAMP }

const GRID_W := 16
const GRID_H := 16
const X_MARGIN := 2          # side walls
const STRIP_DEPTH := 3       # z-depth of each terrace
const STEP := 0.6            # elevation gained per terrace
const BASE_THICKNESS := 0.3
const RAMP_WIDTH := 2.0
const CANYON_STEP := 0.7
const GridShader := preload("res://assets/shaders/grid.gdshader")

var _rng := RandomNumberGenerator.new()
var _cells: Array = []
var _plateaus: Array = []    # [{x0, x1, z0, z1, elev}] front(low) -> top
var _ramps: Array = []       # [{a, b, end, cell_x}]
var _grid_mat: ShaderMaterial
var _wall_mats: Dictionary = {}

func generate(region: NavigationRegion3D, level: int, site_count: int) -> Dictionary:
	_rng.seed = level * 1013 + 17
	_init_cells()
	_plateaus = _build_terraces()
	_compute_ramps()
	_mark_cells()

	for p in _plateaus:
		_build_terrace(region, p)
	for r in _ramps:
		_build_ramp(region, r)
	_build_walls(region)

	return _collect_data(site_count)

# --- layout -------------------------------------------------------------------

func _build_terraces() -> Array:
	var rows := _rng.randi_range(3, 4)
	var x0 := X_MARGIN
	var w := GRID_W - 2 * X_MARGIN
	var plateaus: Array = []
	var z := 1
	for i in rows:
		var z1 := z + STRIP_DEPTH - 1
		if z1 > GRID_H - 1:
			break
		plateaus.append({"x0": x0, "x1": x0 + w - 1, "z0": z, "z1": z1, "elev": i})
		z = z1 + 2   # one-cell gap between terraces for the ramp/step
	return plateaus

func _compute_ramps() -> void:
	_ramps = []
	for i in range(_plateaus.size() - 1):
		var a: Dictionary = _plateaus[i]
		var end := "right" if (i % 2 == 0) else "left"
		var cell_x: int = (a.x1 - 1) if end == "right" else a.x0
		_ramps.append({"a": a, "b": _plateaus[i + 1], "end": end, "cell_x": cell_x})

func _mark_cells() -> void:
	for p in _plateaus:
		for ix in range(p.x0, p.x1 + 1):
			for iz in range(p.z0, p.z1 + 1):
				_cells[ix][iz] = PLATEAU
	for r in _ramps:
		var gz: int = r.a.z1 + 1
		_cells[r.cell_x][gz] = RAMP
		_cells[r.cell_x + 1][gz] = RAMP

# --- geometry -----------------------------------------------------------------

func _build_terrace(region: NavigationRegion3D, p: Dictionary) -> void:
	var w: int = p.x1 - p.x0 + 1
	var d: int = p.z1 - p.z0 + 1
	var top: float = p.elev * STEP
	var height: float = top + BASE_THICKNESS
	var center := Vector3(
		(p.x0 + w / 2.0) - GRID_W / 2.0,
		top - height / 2.0,
		(p.z0 + d / 2.0) - GRID_H / 2.0)
	region.add_child(_make_box_body(Vector3(w, height, d), center, _grid_material()))

func _build_ramp(region: NavigationRegion3D, r: Dictionary) -> void:
	var a: Dictionary = r.a
	var b: Dictionary = r.b
	var xc: float = (r.cell_x + 1) - GRID_W / 2.0   # center of the two ramp cells
	var low := Vector3(xc, a.elev * STEP, (a.z1 + 1) - GRID_H / 2.0)
	var high := Vector3(xc, b.elev * STEP, b.z0 - GRID_H / 2.0)
	var length := high.distance_to(low)

	var body := StaticBody3D.new()
	body.collision_layer = GameState.LAYER_TERRAIN
	body.collision_mask = 0
	region.add_child(body)
	body.global_position = (high + low) / 2.0
	body.look_at(body.global_position + (low - high), Vector3.UP)

	var size := Vector3(RAMP_WIDTH, 0.15, length)
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
	var row0: Dictionary = _plateaus[0]
	var top: Dictionary = _plateaus[_plateaus.size() - 1]

	# Enemies enter row 0 at the end opposite its ramp, and cross to reach it.
	var enter_right: bool = (_ramps[0].end == "left")
	var spawn_x: int = (row0.x1 - 1) if enter_right else (row0.x0 + 1)
	var spawns: Array = []
	for iz in range(row0.z0, row0.z1 + 1):
		spawns.append(_cell_center(spawn_x, iz, row0.elev * STEP))

	# The primary sits at the far end of the top terrace from where enemies arrive.
	var arrive_end: String = _ramps[_ramps.size() - 1].end
	var prim_x: int = (top.x0 + 1) if arrive_end == "right" else (top.x1 - 1)
	var prim_z: int = int((top.z0 + top.z1) / 2.0)
	var primary := _cell_center(prim_x, prim_z, top.elev * STEP)

	var walkable: Array = []
	for p in _plateaus:
		for ix in range(p.x0, p.x1 + 1):
			for iz in range(p.z0, p.z1 + 1):
				walkable.append(_cell_center(ix, iz, p.elev * STEP))

	var player_start := _cell_center((row0.x0 + row0.x1) / 2.0, (row0.z0 + row0.z1) / 2.0, row0.elev * STEP)

	return {
		"primary_position": primary,
		"spawn_points": spawns,
		"secondary_sites": _pick_sites(site_count, primary),
		"walkable_points": walkable,
		"player_start": player_start,
		"terrain_size": Vector2(GRID_W, GRID_H),
	}

## Spread towers along every terrace so enemies pass towers the whole way up.
func _pick_sites(site_count: int, primary: Vector3) -> Array:
	var per_plateau: Array = []
	for p in _plateaus:
		var mid_z: int = int((p.z0 + p.z1) / 2.0)
		var cells: Array = []
		for frac in [0.2, 0.5, 0.8]:
			var x: int = p.x0 + int((p.x1 - p.x0) * frac)
			cells.append(_cell_center(x, mid_z, p.elev * STEP))
		_shuffle(cells)
		per_plateau.append(cells)

	var sites: Array = []
	var round := 0
	while sites.size() < site_count and round < 3:
		for cells in per_plateau:
			if sites.size() >= site_count:
				break
			var pos: Vector3 = cells[round]
			if pos.distance_to(primary) > 1.5:
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
