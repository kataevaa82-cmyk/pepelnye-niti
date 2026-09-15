extends RefCounted
class_name AshGeometry

static func material(color: Color, emission: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.92
	result.metallic = metallic
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		body.position = at
		body.add_child(view)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		return body
	parent.add_child(view)
	view.position = at
	return view

static func sphere(parent: Node3D, at: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	parent.add_child(view)
	view.position = at
	return view

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	parent.add_child(view)
	view.position = at
	return view

static func label(parent: Node3D, at: Vector3, text: String, color: Color, size: int = 36) -> Label3D:
	var view := Label3D.new()
	view.text = text
	view.font_size = size
	view.pixel_size = 0.008
	view.modulate = color
	view.outline_size = 4
	view.no_depth_test = false
	parent.add_child(view)
	view.position = at
	return view

static func doll(parent: Node3D, at: Vector3) -> Node3D:
	var model := Node3D.new()
	parent.add_child(model)
	model.position = at
	var cloth := material(Color("a3916b"))
	var thread := material(Color("483f35"))
	var brass := material(Color("514b3c"), 0.0, 0.45)
	var light := material(Color("9cf4cc"), 1.4)
	var torso := sphere(model, Vector3(0, 0.75, 0), 0.32, cloth)
	torso.scale = Vector3(0.85, 1.15, 0.68)
	var head := sphere(model, Vector3(0, 1.28, 0), 0.30, cloth)
	head.scale = Vector3(1.12, 0.9, 0.75)
	for side in [-1.0, 1.0]:
		var leg := cylinder(model, Vector3(side * 0.16, 0.25, 0), 0.10, 0.46, cloth)
		leg.rotation.z = side * 0.12
		box(model, Vector3(side * 0.18, 0.05, 0.07), Vector3(0.22, 0.10, 0.32), thread)
		var arm := cylinder(model, Vector3(side * 0.38, 0.72, 0), 0.075, 0.55, cloth)
		arm.rotation.z = side * 0.18
		var ring := cylinder(model, Vector3(side * 0.14, 1.30, 0.21), 0.115, 0.07, brass)
		ring.rotation.x = PI / 2.0
		sphere(model, Vector3(side * 0.14, 1.30, 0.255), 0.06, light)
	for i in range(6):
		var stitch := box(model, Vector3(0, 0.56 + i * 0.065, 0.218), Vector3(0.11, 0.015, 0.018), thread)
		stitch.rotation.z = 0.25
	sphere(model, Vector3(0, 0.86, 0.235), 0.075, light)
	return model
