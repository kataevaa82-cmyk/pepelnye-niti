extends Node3D
class_name VoxelStructure
## Limited block-grid destruction, not a Teardown-scale voxel engine.

signal fragment(at: Vector3, tint: Color, impulse: Vector3)
signal changed

const CELL := 0.62
const NEIGHBORS := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]

var identifier := ""
var material_name := "дерево"
var cells: Dictionary = {}
var removed: Dictionary = {}
var health: Dictionary = {}
var durability := 1
var _palette: Array[Material] = []
var _tints: Array[Color] = []
var _mesh: ArrayMesh
var _shape: BoxShape3D
var _fragment_budget := 0

func build(id: String, dimensions: Vector3i, tint: Color, hardness: int, erased: Array = []) -> void:
	identifier = id
	durability = hardness
	material_name = "металл" if hardness > 1 else "дерево / кирпич"
	for value in erased:
		if value is String:
			removed[value] = true
	_mesh = AshGeometry.bevel_mesh(Vector3.ONE * (CELL - 0.018), 0.022)
	_shape = BoxShape3D.new()
	_shape.size = Vector3.ONE * CELL
	for i in range(5):
		var shade := tint.darkened(float(i) * 0.055)
		_tints.append(shade)
		_palette.append(AshSurfaces.material(1 if hardness > 1 else 2, shade))
	for x in range(dimensions.x):
		for y in range(dimensions.y):
			for z in range(dimensions.z):
				var key := Vector3i(x, y, z)
				if removed.has(_encode(key)):
					continue
				var body := StaticBody3D.new()
				body.collision_layer = 1
				body.collision_mask = 0
				add_child(body)
				body.position = Vector3(key) * CELL + Vector3.UP * CELL * 0.5
				var view := MeshInstance3D.new()
				view.mesh = _mesh
				view.material_override = _palette[posmod(x * 13 + y * 7 + z * 3, 5)]
				body.add_child(view)
				var collider := CollisionShape3D.new()
				collider.shape = _shape
				body.add_child(collider)
				cells[key] = body
				health[key] = hardness

func damage(world_point: Vector3, radius: float, strength: int) -> int:
	var hit_count := 0
	_fragment_budget = 14
	for key in cells.keys():
		var body: StaticBody3D = cells[key]
		if body.global_position.distance_squared_to(world_point) > radius * radius:
			continue
		health[key] = int(health[key]) - strength
		if int(health[key]) <= 0:
			_remove(key, world_point)
			hit_count += 1
		else:
			var view := body.get_child(0) as MeshInstance3D
			view.material_override = _palette[4]
	if hit_count > 0:
		_collapse_unsupported(world_point)
		changed.emit()
	return hit_count

func _collapse_unsupported(impact: Vector3) -> void:
	var supported: Dictionary = {}
	var queue: Array[Vector3i] = []
	for key in cells:
		if key.y == 0:
			supported[key] = true
			queue.append(key)
	var cursor := 0
	while cursor < queue.size():
		var key := queue[cursor]
		cursor += 1
		for direction in NEIGHBORS:
			var adjacent: Vector3i = key + direction
			if cells.has(adjacent) and not supported.has(adjacent):
				supported[adjacent] = true
				queue.append(adjacent)
	for key in cells.keys():
		if not supported.has(key):
			_remove(key, impact)

func _remove(key: Vector3i, impact: Vector3) -> void:
	var body: StaticBody3D = cells[key]
	var at := body.global_position
	var tint := _tints[posmod(key.x * 13 + key.y * 7 + key.z * 3, 5)]
	if _fragment_budget > 0:
		_fragment_budget -= 1
		fragment.emit(at, tint, (at - impact).normalized() * 3.2 + Vector3.UP * 2.1)
	body.collision_layer = 0
	body.queue_free()
	cells.erase(key)
	health.erase(key)
	removed[_encode(key)] = true

func snapshot() -> Array:
	return removed.keys()

func _encode(key: Vector3i) -> String:
	return "%d,%d,%d" % [key.x, key.y, key.z]
