extends RefCounted
class_name AshGeometry

static var _bevel_cache: Dictionary = {}

static func bevel_mesh(size: Vector3, bevel: float = 0.035) -> ArrayMesh:
	var key := "%s:%s" % [size, bevel]
	if _bevel_cache.has(key):
		return _bevel_cache[key]
	var half := size * 0.5
	var radius := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.4)
	var inner := half - Vector3.ONE * radius
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for normal: Vector3 in faces:
		var u := Vector3.UP.cross(normal).normalized() if absf(normal.y) < 0.5 else Vector3.RIGHT
		var v := normal.cross(u)
		var extent_u := half.dot(u.abs())
		var extent_v := half.dot(v.abs())
		var extent_n := half.dot(normal.abs())
		var xs := [-extent_u, -extent_u + radius, extent_u - radius, extent_u]
		var ys := [-extent_v, -extent_v + radius, extent_v - radius, extent_v]
		for ix in range(3):
			for iy in range(3):
				var quad := [Vector2(xs[ix], ys[iy]), Vector2(xs[ix+1], ys[iy]), Vector2(xs[ix+1], ys[iy+1]), Vector2(xs[ix], ys[iy+1])]
				for idx in [0, 2, 1, 0, 3, 2]:
					var uv: Vector2 = quad[idx]
					var p := normal * extent_n + u * uv.x + v * uv.y
					var q := p.clamp(-inner, inner)
					var outward := (p - q).normalized()
					st.set_normal(outward)
					st.set_uv(uv)
					st.add_vertex(q + outward * radius)
	st.index()
	st.generate_tangents()
	var result := st.commit()
	_bevel_cache[key] = result
	return result

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
	var mesh := bevel_mesh(size)
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
	mesh.radial_segments = 32
	mesh.rings = 16
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
	mesh.radial_segments = 32
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

static func ring(parent: Node3D, at: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 32
	mesh.ring_segments = 8
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	parent.add_child(view)
	view.position = at
	return view

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var view := cylinder(parent, (a + b) * 0.5, radius, a.distance_to(b), mat)
	view.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return view

static func cable(parent: Node3D, a: Vector3, b: Vector3, sag: float, mat: Material, width: float = 0.018) -> void:
	var previous := a
	for i in range(1, 13):
		var t := float(i) / 12.0
		var next := a.lerp(b, t) - Vector3.UP * sin(t * PI) * sag
		rod(parent, previous, next, width, mat)
		previous = next

static func gear(parent: Node3D, at: Vector3, radius: float, mat: Material) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	ring(root, Vector3.ZERO, radius * 0.8, radius * 0.14, mat).rotation.x = PI / 2.0
	var axle := cylinder(root, Vector3.ZERO, radius * 0.2, 0.17, mat)
	axle.rotation.x = PI / 2.0
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var tooth := box(root, Vector3(cos(angle), sin(angle), 0) * radius, Vector3(radius * 0.25, radius * 0.19, 0.14), mat)
		tooth.rotation.z = angle
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		rod(root, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * radius * 0.76, radius * 0.065, mat)
	return root

static func cloth_panel(parent: Node3D, at: Vector3, width: float, height: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(12):
		for y in range(8):
			for delta: Vector2i in [Vector2i(0,0), Vector2i(1,1), Vector2i(1,0), Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)]:
				var u := float(x + delta.x) / 12.0
				var v := float(y + delta.y) / 8.0
				var tear := (sin(u * 57.0) * 0.07 + sin(u * 23.0) * 0.05) * pow(v, 10.0)
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3((u - 0.5) * width, -v * height + tear, sin(u * TAU * 3.0) * (0.04 + v * 0.08)))
	st.generate_normals()
	var view := MeshInstance3D.new()
	view.mesh = st.commit()
	view.material_override = mat
	parent.add_child(view)
	view.position = at
	return view

static func batch(root: Node3D) -> void:
	var groups: Dictionary = {}
	_collect(root, root, groups)
	for mat in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for view: MeshInstance3D in groups[mat]:
			st.append_from(view.mesh, 0, root.global_transform.affine_inverse() * view.global_transform)
			view.queue_free()
		st.set_material(mat)
		var combined := MeshInstance3D.new()
		combined.mesh = st.commit()
		root.add_child(combined)

static func _collect(node: Node, root: Node3D, groups: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override != null:
			var mat: Material = child.material_override
			if not groups.has(mat):
				groups[mat] = []
			groups[mat].append(child)
		_collect(child, root, groups)

static func doll(parent: Node3D, at: Vector3) -> Node3D:
	var model := Node3D.new()
	parent.add_child(model)
	model.position = at
	var cloth := AshSurfaces.material(3, Color("a3916b"))
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
	var scarf := AshSurfaces.material(3, Color("3f7770"))
	ring(model, Vector3(0, 1.02, 0), 0.22, 0.07, scarf)
	cloth_panel(model, Vector3(-0.21, 1.02, 0.22), 0.22, 0.46, scarf).rotation.z = -0.30
	for side in [-1.0, 1.0]:
		ring(model, Vector3(side * 0.14, 1.30, 0.258), 0.087, 0.016, brass).rotation.x = PI / 2.0
		for i in range(5):
			var y := 1.08 + float(i) * 0.077
			rod(model, Vector3(side * 0.22, y, 0.16), Vector3(side * 0.28, y + 0.036, 0.12), 0.011, thread)
	return model
