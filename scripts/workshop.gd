extends Node3D
class_name AshWorkshop

signal fragments(at: Vector3, tint: Color, impulse: Vector3)
signal altered

var structures: Array[VoxelStructure] = []
var cores: Array[Node3D] = []
var thread_nodes: Array[Node3D] = []
var sentinel: Node3D
var sentinel_eye: MeshInstance3D
var exit_at := Vector3(0, 0, 11.6)
var total_blocks := 0
var _wood: Material
var _iron: Material
var _stone: Material
var _glow: StandardMaterial3D
var _detail: Node3D
var _sun: DirectionalLight3D
var _ash: CPUParticles3D
var _rotor: Node3D

func build(destroyed: Dictionary = {}) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_wood = AshSurfaces.material(2, Color("9b7d58"))
	_iron = AshSurfaces.material(1, Color("54615e"))
	_stone = AshSurfaces.material(0, Color("8b8875"))
	_glow = AshGeometry.material(Color("87d8b6"), 1.3)
	_detail = Node3D.new()
	add_child(_detail)
	_environment()
	_architecture()
	_build_rooms()
	_add_grid("entry_board", Vector3(-2.48, 0, 4.2), Vector3i(9, 4, 1), Color("8b6f4e"), 1, destroyed)
	_add_grid("west_door", Vector3(-10.48, 0, -0.6), Vector3i(9, 5, 1), Color("8f674d"), 1, destroyed)
	_add_grid("east_door", Vector3(5.52, 0, -0.6), Vector3i(9, 5, 1), Color("6f7d73"), 2, destroyed)
	_add_grid("north_door", Vector3(-2.48, 0, -8.0), Vector3i(9, 5, 1), Color("8d775b"), 1, destroyed)
	for i in range(5):
		var at := Vector3(-5.0 + float(i % 2) * 10.0, 0, 7.0 - float(i) * 2.7)
		_add_grid("crate_%d" % i, at, Vector3i(3, 3, 3), Color("786147"), 1, destroyed)
	_add_grid("short_bridge", Vector3(1.7, 0, -4), Vector3i(6, 3, 1), Color("827765"), 1, destroyed)
	_core(Vector3(-8, 1.2, -3.9), "I · ПАМЯТЬ")
	_core(Vector3(8, 1.2, -3.9), "II · ДЫХАНИЕ")
	_core(Vector3(0, 1.2, -11.5), "III · СЕРДЦЕ")
	_thread_node(Vector3(-11.4, 0.72, 7.4), "УЗЕЛ I")
	_thread_node(Vector3(11.2, 0.72, 1.8), "УЗЕЛ II")
	_thread_node(Vector3(0, 0.72, -6.7), "УЗЕЛ III")
	_build_exit()
	_build_sentinel()
	_decorate()
	AshGeometry.batch(_detail)

func _environment() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("1a303a")
	sky.sky_horizon_color = Color("a19374")
	sky.ground_bottom_color = Color("1e2424")
	sky.ground_horizon_color = Color("9e8665")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b2bbad")
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.fog_enabled = true
	environment.fog_light_color = Color("766b59")
	environment.fog_density = 0.013
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -30, 0)
	sun.light_color = Color("ffe1af")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	_sun = sun
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(-25, 145, 0)
	bounce.light_color = Color("8cb5be")
	bounce.light_energy = 0.3
	add_child(bounce)

func _architecture() -> void:
	var floor_mat := AshSurfaces.material(4, Color("777d70"))
	AshGeometry.box(self, Vector3(0, -0.2, 0), Vector3(28, 0.4, 30), floor_mat, true)
	for i in range(-6, 7):
		AshGeometry.box(self, Vector3(i * 2.0, 0.006, 0), Vector3(0.025, 0.012, 29.8), _iron)
	for i in range(-7, 8):
		AshGeometry.box(self, Vector3(0, 0.008, i * 2.0), Vector3(27.8, 0.012, 0.025), _iron)
	for side in [-1.0, 1.0]:
		AshGeometry.box(self, Vector3(side * 14.0, 2.8, 0), Vector3(0.55, 5.6, 30), _stone, true)
		for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
			AshGeometry.box(self, Vector3(side * 12.3, 3.8, z), Vector3(0.5, 7.6, 0.6), _iron, true)
			var glass := AshGeometry.material(Color("acbbae"), 0.25)
			AshGeometry.box(_detail, Vector3(side * 13.68, 3.7, z), Vector3(0.05, 2.4, 2.9), glass)
			for bar in [-0.95, 0.0, 0.95]:
				AshGeometry.box(self, Vector3(side * 13.59, 3.7, z + bar), Vector3(0.12, 2.5, 0.07), _iron)
			AshGeometry.box(self, Vector3(side * 13.57, 3.7, z), Vector3(0.13, 0.10, 3.0), _iron)
	for z in [-15.0, 15.0]:
		AshGeometry.box(self, Vector3(0, 3, z), Vector3(28, 6, 0.6), _stone, true)
	for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		AshGeometry.box(self, Vector3(0, 6.3, z), Vector3(25, 0.3, 0.45), _wood)
		for side in [-1.0, 1.0]:
			var brace := AshGeometry.box(self, Vector3(side * 8.2, 5.8, z), Vector3(4.6, 0.22, 0.27), _wood)
			brace.rotation.z = side * -0.24
	for side in [-1.0, 1.0]:
		var pipe := AshGeometry.cylinder(self, Vector3(side * 11.0, 5.1, 0), 0.16, 27.0, _iron)
		pipe.rotation.x = PI / 2.0
		for z in [3.0, 9.0, -9.0]:
			_lamp(Vector3(side * 10.8, 3.7, z))
	# Fixed machinery makes the room read as a giant abandoned weaving shop.
	for side in [-1.0, 1.0]:
		for z in [3.0, 8.5]:
			var at := Vector3(side * 9.5, 0, z)
			_loom(at)
	AshGeometry.label(self, Vector3(0, 4.4, -14.6), "НИТЬ ЖИВА, ПОКА ТЫ ИДЁШЬ", Color("d5c8a8"), 48)
	AshGeometry.label(self, Vector3(-3.8, 2.4, 4.0), "ПРОЛОМИ ПУТЬ\nЛКМ / R", Color("e6d2a3"), 32)

func _build_rooms() -> void:
	for center in [-8.0, 8.0]:
		for offset in [-3.0, 3.0]:
			AshGeometry.box(self, Vector3(center + offset, 1.7, -3.1), Vector3(0.4, 3.4, 5.6), _stone, true)
		AshGeometry.box(self, Vector3(center, 1.7, -5.8), Vector3(6.2, 3.4, 0.4), _stone, true)
		AshGeometry.box(self, Vector3(center, 3.45, -3.1), Vector3(6.3, 0.18, 5.8), _wood, true)
		_lamp(Vector3(center, 2.7, -3.5))
	for x in [-3.2, 3.2]:
		AshGeometry.box(self, Vector3(x, 1.7, -11.1), Vector3(0.4, 3.4, 6.4), _stone, true)
	AshGeometry.box(self, Vector3(0, 3.45, -11.1), Vector3(6.7, 0.18, 6.3), _wood, true)
	_lamp(Vector3(0, 2.7, -11.8))
	AshGeometry.label(self, Vector3(-8, 3.65, -0.3), "ХРАНИЛИЩЕ ПАМЯТИ", Color("d8c6a3"), 27)
	AshGeometry.label(self, Vector3(8, 3.65, -0.3), "КАМЕРА ДЫХАНИЯ · МЕТАЛЛ", Color("d8c6a3"), 25)
	AshGeometry.label(self, Vector3(0, 3.7, -7.8), "СЕРДЦЕ МАСТЕРСКОЙ", Color("d8c6a3"), 27)

func _lamp(at: Vector3) -> void:
	AshGeometry.cylinder(self, at, 0.20, 0.07, _iron)
	AshGeometry.sphere(self, at - Vector3.UP * 0.1, 0.1, _glow)
	var light := OmniLight3D.new()
	light.position = at - Vector3.UP * 0.2
	light.light_color = Color("b8e7c7")
	light.light_energy = 1.15
	light.omni_range = 5.5
	light.shadow_enabled = false
	add_child(light)
	for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
		var edge := Vector3(cos(angle), 0, sin(angle)) * 0.15
		AshGeometry.rod(_detail, at + edge, at + edge - Vector3.UP * 0.32, 0.016, _iron)
	AshGeometry.ring(_detail, at - Vector3.UP * 0.3, 0.16, 0.024, _iron)
	AshGeometry.rod(_detail, at + Vector3.UP * 0.05, at + Vector3.UP * 0.48, 0.018, _iron)

func _add_grid(id: String, at: Vector3, dimensions: Vector3i, tint: Color, hardness: int, destroyed: Dictionary) -> void:
	var grid := VoxelStructure.new()
	add_child(grid)
	grid.position = at
	var erased: Array = []
	if destroyed.get(id, []) is Array:
		erased = destroyed.get(id, [])
	grid.build(id, dimensions, tint, hardness, erased)
	grid.fragment.connect(func(pos: Vector3, color: Color, force: Vector3): fragments.emit(pos, color, force))
	grid.changed.connect(func(): altered.emit())
	structures.append(grid)
	total_blocks += dimensions.x * dimensions.y * dimensions.z

func _core(at: Vector3, title: String) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.set_meta("base_y", at.y)
	AshGeometry.box(self, at - Vector3.UP * 0.79, Vector3(0.8, 0.8, 0.8), _iron, true)
	AshGeometry.sphere(root, Vector3.ZERO, 0.16, _glow)
	for i in range(3):
		var orbit := Node3D.new()
		root.add_child(orbit)
		orbit.rotation = Vector3(float(i) * PI / 3.0, float(i) * PI / 4.0, 0)
		AshGeometry.ring(orbit, Vector3.ZERO, 0.31, 0.024, _iron)
	AshGeometry.ring(root, Vector3.ZERO, 0.22, 0.012, _glow).rotation.x = PI / 2.0
	var core_light := OmniLight3D.new()
	core_light.light_color = Color("83dfb5")
	core_light.light_energy = 0.8
	core_light.omni_range = 2.0
	root.add_child(core_light)
	var label := AshGeometry.label(self, at + Vector3(0, 0.75, 0), title, Color("a7f0c9"), 27)
	root.set_meta("label_node", label)
	cores.append(root)

func hide_core(index: int) -> void:
	cores[index].visible = false
	var label: Label3D = cores[index].get_meta("label_node")
	label.visible = false

func _thread_node(at: Vector3, title: String) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.set_meta("base_y", at.y)
	AshGeometry.cylinder(root, Vector3(0, -0.34, 0), 0.20, 0.68, _wood)
	for offset in [-0.35, 0.35]:
		AshGeometry.cylinder(root, Vector3(0, offset - 0.34, 0), 0.30, 0.08, _iron)
	for i in range(5):
		AshGeometry.ring(root, Vector3(0, -0.55 + float(i) * 0.11, 0), 0.225, 0.012, _glow)
	AshGeometry.sphere(root, Vector3(0, 0.08, 0), 0.11, _glow)
	var label := AshGeometry.label(self, at + Vector3(0, 0.72, 0), title, Color("a7f0c9"), 24)
	root.set_meta("label_node", label)
	thread_nodes.append(root)

func hide_thread_node(index: int) -> void:
	thread_nodes[index].visible = false
	var label: Label3D = thread_nodes[index].get_meta("label_node")
	label.visible = false

func _build_exit() -> void:
	for x in [-1.1, 1.1]:
		AshGeometry.box(self, exit_at + Vector3(x, 1.25, 0), Vector3(0.2, 2.5, 0.2), _wood)
	AshGeometry.box(self, exit_at + Vector3(0, 2.5, 0), Vector3(2.4, 0.2, 0.2), _wood)
	AshGeometry.box(self, exit_at + Vector3(0, 0.02, 0), Vector3(2.3, 0.04, 1.2), _glow)
	var doll := AshGeometry.doll(self, Vector3(-1.7, 0, 9.2))
	doll.rotation.y = PI * 0.15
	AshGeometry.label(self, Vector3(0, 2.95, 11.6), "УБЕЖИЩЕ · ВЕРНИ СВЕТ СЮДА", Color("a2e8c7"), 30).rotation.y = PI

func _build_sentinel() -> void:
	sentinel = Node3D.new()
	add_child(sentinel)
	sentinel.position = Vector3(0, 4.0, -4.5)
	AshGeometry.sphere(sentinel, Vector3.ZERO, 0.5, _iron).scale = Vector3(1, 0.65, 1)
	var red := AshGeometry.material(Color("ff7950"), 1.8)
	sentinel_eye = AshGeometry.sphere(sentinel, Vector3(0, -0.10, 0.46), 0.15, red)
	AshGeometry.ring(sentinel, Vector3(0, -0.10, 0.48), 0.19, 0.06, _iron).rotation.x = PI / 2.0
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var shell := AshGeometry.box(sentinel, Vector3(cos(angle) * 0.4, 0.06, sin(angle) * 0.4), Vector3(0.29, 0.27, 0.18), _iron)
		shell.rotation.y = -angle
		AshGeometry.sphere(sentinel, Vector3(cos(angle) * 0.47, 0.17, sin(angle) * 0.47), 0.026, _wood)
	_rotor = Node3D.new()
	sentinel.add_child(_rotor)
	_rotor.position.y = 0.37
	AshGeometry.ring(_rotor, Vector3.ZERO, 0.6, 0.035, _iron)
	for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
		var blade := AshGeometry.box(_rotor, Vector3(cos(angle), 0, sin(angle)) * 0.3, Vector3(0.48, 0.035, 0.11), _wood)
		blade.rotation.y = -angle
	for side in [-1.0, 1.0]:
		for z in [-0.25, 0.25]:
			var limb := AshGeometry.box(sentinel, Vector3(side * 0.8, -0.15, z), Vector3(1.0, 0.08, 0.09), _wood)
			limb.rotation.z = side * -0.4
			AshGeometry.box(sentinel, Vector3(side * 1.23, -0.60, z), Vector3(0.07, 0.62, 0.07), _iron)
			AshGeometry.sphere(sentinel, Vector3(side * 1.23, -0.29, z), 0.10, _iron)
			AshGeometry.rod(sentinel, Vector3(side * 1.23, -0.91, z), Vector3(side * 1.12, -1.08, z + 0.1), 0.035, _iron)
			AshGeometry.cable(sentinel, Vector3(side * 0.36, 0.1, z), Vector3(side * 1.22, -0.3, z), 0.22, _iron, 0.018)
	sentinel.visible = false

func _loom(at: Vector3) -> void:
	AshGeometry.box(self, at + Vector3(0, 0.35, 0), Vector3(2.3, 0.7, 1.55), _iron, true)
	var cloth := AshSurfaces.material(3, Color("a39373"))
	for side in [-1.0, 1.0]:
		AshGeometry.box(_detail, at + Vector3(side * 1.0, 1.5, 0.5), Vector3(0.15, 2.8, 0.18), _wood)
		AshGeometry.box(_detail, at + Vector3(side * 1.0, 0.1, 0), Vector3(0.34, 0.18, 1.8), _iron)
	AshGeometry.rod(_detail, at + Vector3(-1.1, 2.75, 0.5), at + Vector3(1.1, 2.75, 0.5), 0.10, _wood)
	AshGeometry.rod(_detail, at + Vector3(-1.12, 1.1, -0.35), at + Vector3(1.12, 1.1, -0.35), 0.30, cloth)
	for i in range(23):
		var x := -0.82 + float(i) * 0.075
		AshGeometry.rod(_detail, at + Vector3(x, 2.6, 0.48), at + Vector3(x, 1.18, -0.42), 0.006, _wood)
	for side in [-1.0, 1.0]:
		AshGeometry.ring(_detail, at + Vector3(side * 0.98, 1.1, -0.35), 0.40, 0.075, _iron).rotation.z = PI / 2.0
	AshGeometry.gear(_detail, at + Vector3(0, 0.67, -0.85), 0.37, _iron)
	AshGeometry.gear(_detail, at + Vector3(0.63, 0.92, -0.84), 0.23, _wood)
	AshGeometry.cloth_panel(_detail, at + Vector3(0, 2.68, 0.42), 1.3, 1.13, cloth)

func _decorate() -> void:
	var cloth := AshSurfaces.material(3, Color("777e69"))
	var cable_mat := AshGeometry.material(Color("2d3834"))
	for side in [-1.0, 1.0]:
		for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
			# Stone lintels and iron column plates give the architecture depth.
			AshGeometry.box(_detail, Vector3(side * 13.57, 2.42, z), Vector3(0.38, 0.15, 3.18), _stone)
			AshGeometry.box(_detail, Vector3(side * 12.3, 0.15, z), Vector3(0.95, 0.3, 0.95), _iron)
			for dy in [1.2, 4.0, 5.8]:
				AshGeometry.box(_detail, Vector3(side * 12.3, dy, z), Vector3(0.58, 0.24, 0.69), _iron)
				for offset in [-0.19, 0.19]:
					AshGeometry.sphere(_detail, Vector3(side * 12.3 + offset, dy, z + 0.36), 0.046, _wood)
			AshGeometry.cable(_detail, Vector3(side * 12.3, 6.2, z), Vector3(0, 6.2, z), 0.75, cable_mat, 0.025)
		AshGeometry.cloth_panel(_detail, Vector3(side * 6.4, 6.1, 1.6), 1.5, 2.0, cloth)
		for z in [-11.0, -3.0, 4.0, 11.0]:
			for i in range(6):
				var shard := AshGeometry.box(_detail, Vector3(side * (12.7 + float(i % 2) * 0.45), 0.10, z + float(i) * 0.27), Vector3(0.38, 0.17, 0.26), _stone)
				shard.rotation.y = float(i) * 1.7
	for z in [-10.0, -2.0, 6.0, 12.0]:
		AshGeometry.rod(_detail, Vector3(-12.2, 6.4, z), Vector3(0, 7.7, z), 0.12, _iron)
		AshGeometry.rod(_detail, Vector3(12.2, 6.4, z), Vector3(0, 7.7, z), 0.12, _iron)
		for x in [-6.0, 0.0, 6.0]:
			AshGeometry.rod(_detail, Vector3(x, 6.3, z), Vector3(x, 7.7 - absf(x) * 0.105, z), 0.055, _iron)
	for at in [Vector3(-5.2, 2.75, -5.53), Vector3(10.8, 2.8, -5.53), Vector3(2.8, 2.6, -13.9)]:
		AshGeometry.gear(_detail, at, 0.55, _iron)
	_ash = CPUParticles3D.new()
	_ash.amount = 110
	_ash.lifetime = 16.0
	_ash.preprocess = 4.0
	_ash.position.y = 3.6
	_ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ash.emission_box_extents = Vector3(13, 2.6, 14)
	_ash.direction = Vector3(0.4, -0.5, 0.2)
	_ash.gravity = Vector3(0, -0.015, 0)
	_ash.initial_velocity_min = 0.04
	_ash.initial_velocity_max = 0.15
	_ash.scale_amount_min = 0.5
	_ash.scale_amount_max = 1.2
	var mote := SphereMesh.new()
	mote.radius = 0.012
	mote.height = 0.024
	mote.radial_segments = 6
	mote.rings = 3
	mote.material = AshGeometry.material(Color("b7aa87"), 0.3)
	_ash.mesh = mote
	add_child(_ash)

func set_quality(high: bool) -> void:
	_sun.shadow_enabled = high
	_ash.emitting = high
	_ash.visible = high

func animate(_age: float, delta: float) -> void:
	if is_instance_valid(_rotor) and sentinel.visible:
		_rotor.rotation.y += delta * 8.0

func snapshot() -> Dictionary:
	var data: Dictionary = {}
	for grid in structures:
		data[grid.identifier] = grid.snapshot()
	return data

func remaining_blocks() -> int:
	var count := 0
	for grid in structures:
		count += grid.cells.size()
	return count
