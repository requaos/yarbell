class_name TerrainGenerator
extends RefCounted
## Procedurally builds the landscape from a maze. A recursive-backtracker maze is
## carved over a coarse node grid; the enemy route is the maze's solution path
## from the entry corner to the farthest node — a single long winding corridor
## that differs every level. The corridor climbs in elevation tiers, with ramps
## placed on the straight passages between nodes (natural chokepoints) up to the
## primary tower on the highest node. Every non-corridor cell becomes a wall,
## rendered with a MultiMesh (one draw call) so the large map stays cheap.
##
## Corridor surfaces are StaticBody3D + BoxMesh + BoxShape3D on the TERRAIN layer
## (feed the navmesh bake and tap rays). Walls are visual-only (no collider).

enum { WALL, PATH }

const COARSE_W := 10
const COARSE_H := 10
const PITCH := 3             # coarse-node spacing in world cells
const BLOCK := 2             # corridor width in world cells
const OFFSET := 1            # margin
const GRID_W := 32           # 4x the previous 16x16 area
const GRID_H := 32
const STEP := 0.6            # elevation gained per tier
const MAX_TIER := 5
const BASE_THICKNESS := 0.3
const CANYON_STEP := 0.7
const GridShader := preload("res://assets/shaders/grid.gdshader")

var _rng := RandomNumberGenerator.new()
var _cells: Array = []
var _node_elev: Dictionary = {}   # Vector2i -> int tier
var _grid_mat: ShaderMaterial

func generate(region: NavigationRegion3D, level: int, site_count: int) -> Dictionary:
	_rng.seed = level * 1013 + 17
	_init_cells()
	_node_elev.clear()

	var adj := _carve_maze()
	var path := _solution_path(adj)
	_build_corridor(region, path)
	_build_walls(region)

	return _collect_data(path, site_count)

# --- maze ---------------------------------------------------------------------

func _carve_maze() -> Dictionary:
	var adj: Dictionary = {}
	var visited: Dictionary = {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var entry := Vector2i(0, 0)
	var stack: Array = [entry]
	visited[entry] = true
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array = []
		for d in dirs:
			var nb: Vector2i = cur + d
			if nb.x >= 0 and nb.y >= 0 and nb.x < COARSE_W and nb.y < COARSE_H and not visited.has(nb):
				options.append(nb)
		if options.is_empty():
			stack.pop_back()
		else:
			var nb: Vector2i = options[_rng.randi_range(0, options.size() - 1)]
			visited[nb] = true
			if not adj.has(cur):
				adj[cur] = []
			if not adj.has(nb):
				adj[nb] = []
			adj[cur].append(nb)
			adj[nb].append(cur)
			stack.append(nb)
	return adj

## Longest solution: BFS from the entry, take the farthest node, backtrack.
func _solution_path(adj: Dictionary) -> Array:
	var entry := Vector2i(0, 0)
	var dist: Dictionary = {entry: 0}
	var parent: Dictionary = {entry: entry}
	var queue: Array = [entry]
	var head := 0
	var far := entry
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for nb in adj.get(cur, []):
			if not dist.has(nb):
				dist[nb] = dist[cur] + 1
				parent[nb] = cur
				if dist[nb] > dist[far]:
					far = nb
				queue.append(nb)
	var path: Array = []
	var c: Vector2i = far
	while c != entry:
		path.append(c)
		c = parent[c]
	path.append(entry)
	path.reverse()
	return path

# --- corridor -----------------------------------------------------------------

func _build_corridor(region: NavigationRegion3D, path: Array) -> void:
	var count := path.size()
	var cells_per_tier: int = maxi(2, int(float(count) / float(MAX_TIER + 1)))

	# Elevation per node index (monotonic climb toward the primary, capped).
	var elev: Array = []
	for i in count:
		elev.append(mini(MAX_TIER, i / cells_per_tier))
		_node_elev[path[i]] = elev[i]

	for i in count:
		var r := _node_rect(path[i])
		_fill_box(region, r[0], r[1], r[2], r[3], elev[i])
		_mark(r[0], r[1], r[2], r[3])

	for i in range(count - 1):
		var a: Vector2i = path[i]
		var b: Vector2i = path[i + 1]
		var pr := _passage_rect(a, b)
		_mark(pr[0], pr[1], pr[2], pr[3])
		if elev[i] == elev[i + 1]:
			_fill_box(region, pr[0], pr[1], pr[2], pr[3], elev[i])
		else:
			_build_ramp(region, a, b, pr, elev[i], elev[i + 1])

func _node_rect(n: Vector2i) -> Array:
	var x0: int = n.x * PITCH + OFFSET
	var z0: int = n.y * PITCH + OFFSET
	return [x0, x0 + BLOCK - 1, z0, z0 + BLOCK - 1]

func _passage_rect(a: Vector2i, b: Vector2i) -> Array:
	var ra := _node_rect(a)
	var rb := _node_rect(b)
	if b.x != a.x:
		var x0: int = mini(ra[1], rb[1]) + 1
		var x1: int = maxi(ra[0], rb[0]) - 1
		return [x0, x1, ra[2], ra[3]]
	else:
		var z0: int = mini(ra[3], rb[3]) + 1
		var z1: int = maxi(ra[2], rb[2]) - 1
		return [ra[0], ra[1], z0, z1]

func _fill_box(region: NavigationRegion3D, x0: int, x1: int, z0: int, z1: int, tier: int) -> void:
	var w: int = x1 - x0 + 1
	var d: int = z1 - z0 + 1
	var top: float = tier * STEP
	var height: float = top + BASE_THICKNESS
	var center := Vector3(
		(x0 + w / 2.0) - GRID_W / 2.0,
		top - height / 2.0,
		(z0 + d / 2.0) - GRID_H / 2.0)
	region.add_child(_make_box_body(Vector3(w, height, d), center, _grid_material()))

func _build_ramp(region: NavigationRegion3D, a: Vector2i, b: Vector2i, pr: Array, ea: int, eb: int) -> void:
	var low: Vector3
	var high: Vector3
	if b.x != a.x:
		var zc: float = (pr[2] + (pr[3] - pr[2] + 1) / 2.0) - GRID_H / 2.0
		var lo_x: float = pr[0] - GRID_W / 2.0
		var hi_x: float = (pr[1] + 1) - GRID_W / 2.0
		if b.x < a.x:  # travelling -x: swap which side is high
			var t := lo_x; lo_x = hi_x; hi_x = t
		low = Vector3(lo_x, ea * STEP, zc)
		high = Vector3(hi_x, eb * STEP, zc)
	else:
		var xc: float = (pr[0] + (pr[1] - pr[0] + 1) / 2.0) - GRID_W / 2.0
		var lo_z: float = pr[2] - GRID_H / 2.0
		var hi_z: float = (pr[3] + 1) - GRID_H / 2.0
		if b.y < a.y:
			var t := lo_z; lo_z = hi_z; hi_z = t
		low = Vector3(xc, ea * STEP, lo_z)
		high = Vector3(xc, eb * STEP, hi_z)

	var length := high.distance_to(low)
	var body := StaticBody3D.new()
	body.collision_layer = GameState.LAYER_TERRAIN
	body.collision_mask = 0
	region.add_child(body)
	body.global_position = (high + low) / 2.0
	body.look_at(body.global_position + (low - high), Vector3.UP)

	var size := Vector3(BLOCK, 0.15, length)
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

# --- walls (MultiMesh) --------------------------------------------------------

func _build_walls(region: NavigationRegion3D) -> void:
	var cells: Array = []
	for ix in GRID_W:
		for iz in GRID_H:
			if _cells[ix][iz] == WALL:
				cells.append(Vector2i(ix, iz))
	if cells.is_empty():
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = cells.size()

	var palette := [Palette.PURPLE, Palette.MAGENTA, Palette.CYAN]
	for i in cells.size():
		var c: Vector2i = cells[i]
		var tiers := _rng.randi_range(1, 3)
		var h := tiers * CANYON_STEP
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0))
		mm.set_instance_transform(i, Transform3D(basis, _cell_center(c.x, c.y, h / 2.0)))
		mm.set_instance_color(i, palette[(tiers - 1) % palette.size()].darkened(0.35))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	region.add_child(mmi)

# --- shared helpers -----------------------------------------------------------

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

func _mark(x0: int, x1: int, z0: int, z1: int) -> void:
	for ix in range(x0, x1 + 1):
		for iz in range(z0, z1 + 1):
			if ix >= 0 and iz >= 0 and ix < GRID_W and iz < GRID_H:
				_cells[ix][iz] = PATH

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

# --- data ---------------------------------------------------------------------

func _node_center(n: Vector2i) -> Vector3:
	var r := _node_rect(n)
	var tier: int = _node_elev.get(n, 0)
	return _cell_center((r[0] + r[1]) / 2.0, (r[2] + r[3]) / 2.0, tier * STEP)

func _collect_data(path: Array, site_count: int) -> Dictionary:
	var entry: Vector2i = path[0]
	var top: Vector2i = path[path.size() - 1]

	var spawns: Array = []
	var er := _node_rect(entry)
	var e0: int = _node_elev.get(entry, 0)
	for ix in range(er[0], er[1] + 1):
		spawns.append(_cell_center(ix, er[2], e0 * STEP))

	var walkable: Array = []
	for n in path:
		walkable.append(_node_center(n))

	return {
		"primary_position": _node_center(top),
		"spawn_points": spawns,
		"secondary_sites": _pick_sites(path, site_count),
		"walkable_points": walkable,
		"player_start": _node_center(path[mini(1, path.size() - 1)]),
		"terrain_size": Vector2(GRID_W, GRID_H),
	}

## Spread towers evenly along the corridor (skipping entry and primary nodes).
func _pick_sites(path: Array, site_count: int) -> Array:
	var sites: Array = []
	var inner := path.size() - 2
	if inner <= 0 or site_count <= 0:
		return sites
	var take: int = mini(site_count, inner)
	for k in take:
		var idx: int = 1 + int(round((k + 1.0) * inner / (take + 1.0)))
		idx = clampi(idx, 1, path.size() - 2)
		sites.append(_node_center(path[idx]))
	return sites

func _init_cells() -> void:
	_cells = []
	for ix in GRID_W:
		var col: Array = []
		col.resize(GRID_H)
		col.fill(WALL)
		_cells.append(col)
