extends CharacterBody3D
class_name AshPlayer

signal strike
signal interact
signal tool_changed(index: int)
signal pause_pressed

var enabled := false
var camera: Camera3D
var tool := 0
var touch_move := Vector2.ZERO
var touch_sprint := false
var _pitch := 0.0
var _swing := 0.0
var _clock := 0.0
var _hands: Node3D
var _hammer: Node3D
var _coil: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.45
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.74
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.25
	camera.fov = 76.0
	camera.near = 0.06
	camera.far = 85.0
	add_child(camera)
	camera.make_current()
	_configure_input()
	_build_hands()

func _configure_input() -> void:
	var mapping := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"turn_left": [KEY_Q, KEY_LEFT], "turn_right": [KEY_E, KEY_RIGHT],
		"look_up": [KEY_T], "look_down": [KEY_G],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "use": [KEY_F],
		"strike": [KEY_R], "pause_game": [KEY_ESCAPE, KEY_P],
		"tool_hammer": [KEY_1], "tool_coil": [KEY_2]
	}
	for action in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for keycode in mapping[action]:
				var event := InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	if not enabled:
		velocity = Vector3.ZERO
		return
	_clock += delta
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back") + touch_move
	movement = movement.limit_length()
	var direction := transform.basis * Vector3(movement.x, 0, movement.y)
	var speed := 6.0 if Input.is_action_pressed("sprint") or touch_sprint else 4.2
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 16.0 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 6.0
	move_and_slide()
	rotation.y += Input.get_axis("turn_right", "turn_left") * delta * 1.8
	_pitch = clampf(_pitch + Input.get_axis("look_down", "look_up") * delta, -1.25, 1.25)
	camera.rotation.x = _pitch
	if global_position.y < -5.0:
		global_position = Vector3(0, 0.2, 10)
	_swing = maxf(0.0, _swing - delta * 3.4)
	_hands.rotation.x = -sin(_swing * PI) * 1.05
	_hands.position.y = sin(_clock * 10.0) * 0.012 * movement.length()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		pause_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	elif event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
		look(event.relative * 1.6)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				strike.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			interact.emit()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_tool(1 - tool)
	if event.is_action_pressed("strike"):
		strike.emit()
	if event.is_action_pressed("use"):
		interact.emit()
	if event.is_action_pressed("tool_hammer"):
		set_tool(0)
	if event.is_action_pressed("tool_coil"):
		set_tool(1)

func look(relative: Vector2) -> void:
	rotation.y -= relative.x * 0.0025
	_pitch = clampf(_pitch - relative.y * 0.0025, -1.25, 1.25)
	camera.rotation.x = _pitch

func jump_touch() -> void:
	if enabled and is_on_floor():
		velocity.y = 6.0

func set_tool(index: int) -> void:
	tool = clampi(index, 0, 1)
	_hammer.visible = tool == 0
	_coil.visible = tool == 1
	tool_changed.emit(tool)

func animate_strike() -> void:
	_swing = 1.0

func ray(length: float) -> Dictionary:
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * length
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func restore_view(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, -1.25, 1.25)
	camera.rotation.x = _pitch

func _build_hands() -> void:
	_hands = Node3D.new()
	camera.add_child(_hands)
	var cloth := AshGeometry.material(Color("ad9670"))
	var thread := AshGeometry.material(Color("4a4337"))
	var iron := AshGeometry.material(Color("424a48"), 0.0, 0.6)
	var brass := AshGeometry.material(Color("9d7650"), 0.0, 0.5)
	var light := AshGeometry.material(Color("7af5c0"), 1.6)
	for side in [-1.0, 1.0]:
		var hand := AshGeometry.box(_hands, Vector3(side * 0.28, -0.28, -0.53), Vector3(0.12, 0.13, 0.24), cloth)
		hand.rotation.z = side * 0.20
		for i in range(4):
			AshGeometry.box(_hands, Vector3(side * 0.28, -0.211, -0.60 + i * 0.04), Vector3(0.045, 0.005, 0.012), thread)
	_hammer = Node3D.new()
	_hands.add_child(_hammer)
	var handle := AshGeometry.cylinder(_hammer, Vector3(0.29, -0.15, -0.67), 0.032, 0.63, brass)
	handle.rotation.x = -0.3
	AshGeometry.box(_hammer, Vector3(0.29, 0.17, -0.76), Vector3(0.34, 0.17, 0.18), iron)
	_coil = Node3D.new()
	_hands.add_child(_coil)
	AshGeometry.box(_coil, Vector3(0.26, -0.16, -0.68), Vector3(0.20, 0.22, 0.35), iron)
	for i in range(5):
		var ring := AshGeometry.cylinder(_coil, Vector3(0.26, -0.08, -0.65 - i * 0.045), 0.13, 0.014, brass)
		ring.rotation.x = PI / 2.0
	AshGeometry.sphere(_coil, Vector3(0.26, -0.08, -0.91), 0.067, light)
	_coil.visible = false
