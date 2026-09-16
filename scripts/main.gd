extends Node3D
## One complete prototype mission: prepare shortcuts, steal three cores, escape.

const MISSION_SECONDS := 140.0
const MAX_DEBRIS := 48
const CORE_COUNT := 3
const THREAD_NODE_COUNT := 3

var level: AshWorkshop
var player: AshPlayer
var running := false
var sandbox := false
var collected: Array[int] = []
var used_threads: Array[int] = []
var health := 100.0
var seconds := MISSION_SECONDS
var alarm := false
var charges := 5
var _has_session := false
var _muted := false
var _high_quality := true
var _help_return := "title"
var _save_problem := false
var _saved: Dictionary = {}
var _best := 0
var _age := 0.0
var _save_clock := 0.0
var _hud_clock := 0.0
var _cooldown := 0.0
var _toast_time := 0.0
var _debris: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _menu_mode := "title"
var _waiting_ad := false
var _touch_index := -1

var _hud: Control
var _menu: PanelContainer
var _menu_backdrop: AshMenuBackdrop
var _menu_content: VBoxContainer
var _objective: Label
var _status: Label
var _tools: Label
var _hint: Label
var _toast_label: Label
var _damage_overlay: ColorRect
var _health_bar: ProgressBar
var _touch_pad: Panel
var _ambient: AudioStreamPlayer
var _hit_audio: AudioStreamPlayer
var _pulse_audio: AudioStreamPlayer
var _pickup_audio: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saved = Platform.load_data()
	_best = int(_saved.get("best", 0))
	_muted = bool(_saved.get("muted", false))
	_high_quality = bool(_saved.get("high_quality", not DisplayServer.is_touchscreen_available()))
	get_viewport().msaa_3d = Viewport.MSAA_4X if _high_quality else Viewport.MSAA_DISABLED
	Platform.pause_requested.connect(_pause)
	Platform.ad_closed.connect(_after_ad)
	Platform.save_failed.connect(_save_failed)
	player = AshPlayer.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.strike.connect(_strike)
	player.interact.connect(_interact)
	player.pause_pressed.connect(_pause)
	player.tool_changed.connect(func(_index: int): _update_hud())
	_build_level({})
	player.position = Vector3(0, 0.2, 10.0)
	_audio_setup()
	_build_ui()
	_show_menu("title")
	await get_tree().process_frame
	Platform.loading_ready()

func _build_level(destroyed: Dictionary) -> void:
	_debris.clear()
	_flashes.clear()
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	level = AshWorkshop.new()
	add_child(level)
	level.build(destroyed)
	level.set_quality(_high_quality)
	level.fragments.connect(_spawn_fragment)
	level.altered.connect(_save_now)

func _start_run(relaxed: bool = false, resume: bool = false, start_paused: bool = false) -> void:
	var session: Dictionary = {}
	if resume and _saved.get("session", {}) is Dictionary:
		session = _saved.get("session", {})
	sandbox = bool(session.get("sandbox", relaxed))
	collected.clear()
	for value in session.get("collected", []):
		var index := int(value)
		if index >= 0 and index < CORE_COUNT and index not in collected:
			collected.append(index)
	used_threads.clear()
	for value in session.get("used_threads", []):
		var index := int(value)
		if index >= 0 and index < THREAD_NODE_COUNT and index not in used_threads:
			used_threads.append(index)
	health = clampf(float(session.get("health", 100.0)), 1.0, 100.0)
	seconds = clampf(float(session.get("seconds", MISSION_SECONDS)), 0.1, MISSION_SECONDS)
	charges = clampi(int(session.get("charges", 5)), 0, 5)
	alarm = not collected.is_empty() and not sandbox
	_age = 0.0
	_cooldown = 0.0
	_save_clock = 0.0
	_has_session = true
	var destroyed: Dictionary = session.get("destroyed", {}) if session.get("destroyed", {}) is Dictionary else {}
	_build_level(destroyed)
	player.position = Vector3(0, 0.2, 10.0)
	var position_data = session.get("position", [])
	if position_data is Array and position_data.size() == 3:
		player.position = Vector3(clampf(float(position_data[0]), -13, 13), clampf(float(position_data[1]), 0.1, 5.0), clampf(float(position_data[2]), -14, 14))
	player.restore_view(float(session.get("yaw", 0.0)), float(session.get("pitch", 0.0)))
	player.set_tool(0)
	for index in collected:
		level.hide_core(index)
	for index in used_threads:
		level.hide_thread_node(index)
	level.sentinel.visible = alarm
	_menu.visible = false
	if start_paused:
		_show_menu("pause")
	else:
		_set_running(true)
	_toast("Сначала подготовь проходы. Первое ядро разбудит Сборщика." if not sandbox else "Свободный режим: ломай, исследуй, собирай. Таймера и урона нет.", 8.0)
	_save_now()

func _process(delta: float) -> void:
	if not running:
		return
	_age += delta
	level.animate(_age, delta)
	_save_clock += delta
	_hud_clock += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast_label.visible = _toast_time > 0.0
	_damage_overlay.color.a = move_toward(_damage_overlay.color.a, 0.0, delta * 0.6)
	if alarm:
		seconds = maxf(0.0, seconds - delta)
		_update_sentinel(delta)
		if seconds <= 0 or health <= 0:
			_finish(false)
			return
	for i in range(level.cores.size()):
		if i not in collected:
			var core := level.cores[i]
			core.rotation.y += delta * 0.7
			core.position.y = float(core.get_meta("base_y")) + sin(_age * 2.0 + float(i)) * 0.09
	for i in range(level.thread_nodes.size()):
		if i not in used_threads:
			var thread_node := level.thread_nodes[i]
			thread_node.rotation.y += delta * 0.35
			thread_node.position.y = float(thread_node.get_meta("base_y")) + sin(_age * 2.4 + float(i)) * 0.04
	for i in range(_debris.size() - 1, -1, -1):
		_debris[i]["life"] = float(_debris[i]["life"]) - delta
		var body: RigidBody3D = _debris[i]["node"]
		if float(_debris[i]["life"]) < 0.0:
			body.queue_free()
			_debris.remove_at(i)
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i]["life"] = float(_flashes[i]["life"]) - delta
		var view: MeshInstance3D = _flashes[i]["node"]
		view.scale += Vector3.ONE * delta * 8.0
		if float(_flashes[i]["life"]) <= 0.0:
			view.queue_free()
			_flashes.remove_at(i)
	if _save_clock >= 2.0:
		_save_clock = 0.0
		_save_now()
	if _hud_clock >= 0.1:
		_hud_clock = 0.0
		_update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_menu):
		_pause()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
		_touch_index = -1
		player.touch_move = Vector2.ZERO

func _set_running(active: bool) -> void:
	running = active
	get_tree().paused = not active
	player.enabled = active
	player.touch_move = Vector2.ZERO
	player.touch_sprint = false
	_touch_index = -1
	_hud.visible = active
	_menu_backdrop.visible = not active
	AudioServer.set_bus_mute(0, _muted or not active)
	Platform.gameplay(active)
	if active:
		if not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if not _ambient.playing:
			_ambient.play()
	else:
		_stop_audio()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _stop_audio() -> void:
	for audio in [_ambient, _hit_audio, _pulse_audio, _pickup_audio]:
		if is_instance_valid(audio):
			audio.stream_paused = false
			audio.stop()

func _exit_tree() -> void:
	_stop_audio()
	for audio in [_ambient, _hit_audio, _pulse_audio, _pickup_audio]:
		if is_instance_valid(audio):
			audio.stream = null

func _pause() -> void:
	if running:
		_save_now()
		_show_menu("pause")

func _resume() -> void:
	if Platform.blocked:
		return
	_menu.visible = false
	_set_running(true)

func _strike() -> void:
	if not running or _cooldown > 0.0:
		return
	var pulse := player.tool == 1
	if pulse and charges <= 0:
		_toast("Катушка разряжена. Киянка работает без ограничений.")
		return
	_cooldown = 0.85 if pulse else 0.33
	player.animate_strike()
	var impact := player.ray(12.0 if pulse else 3.2)
	if impact.is_empty():
		_hit_audio.play()
		return
	var at: Vector3 = impact["position"]
	if pulse:
		charges -= 1
		_pulse_audio.play()
		_pulse_flash(at)
		for grid in level.structures:
			grid.damage(at, 2.3, 3)
	else:
		_hit_audio.play()
		var collider: Node = impact["collider"]
		var grid := collider.get_parent() as VoxelStructure
		if grid:
			grid.damage(at, 0.93, 1)
		else:
			_toast("Каркас не ломается. Ищи блочные перегородки и ящики.", 2.5)
	_save_now()
	_update_hud()

func _interact() -> void:
	if not running:
		return
	var index := _near_core()
	if index >= 0:
		collected.append(index)
		level.hide_core(index)
		_pickup_audio.play()
		if not sandbox and not alarm:
			alarm = true
			level.sentinel.visible = true
			_toast("Сборщик проснулся. Собери остальные ядра и возвращайся в убежище!", 6.0)
		elif collected.size() == CORE_COUNT:
			_toast("Весь свет у тебя. Выход там, где ты начал!", 6.0)
		_save_now()
		return
	var thread_index := _near_thread_node()
	if thread_index >= 0:
		if charges >= 5 and health >= 100.0:
			_toast("Нить цела. Узел пригодится во время тревоги.")
			return
		used_threads.append(thread_index)
		level.hide_thread_node(thread_index)
		charges = mini(5, charges + 2)
		health = minf(100.0, health + 25.0)
		_pickup_audio.play()
		_pulse_flash(level.thread_nodes[thread_index].global_position)
		_toast("Узел вплетён: здоровье восстановлено, катушка получила 2 импульса.", 5.0)
		_save_now()
		_update_hud()
		return
	if player.global_position.distance_to(level.exit_at) < 2.4:
		if collected.size() == CORE_COUNT:
			_finish(true)
		else:
			_toast("Для убежища нужны все три световых ядра.")

func _near_core() -> int:
	var origin := player.camera.global_position
	for i in range(level.cores.size()):
		if i in collected:
			continue
		var target := level.cores[i].global_position
		var offset := target - origin
		if offset.length() > 2.6 or offset.normalized().dot(-player.camera.global_basis.z) < 0.6:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return i
	return -1

func _near_thread_node() -> int:
	var origin := player.camera.global_position
	for i in range(level.thread_nodes.size()):
		if i in used_threads:
			continue
		var target := level.thread_nodes[i].global_position
		var offset := target - origin
		if offset.length() > 2.6 or offset.normalized().dot(-player.camera.global_basis.z) < 0.55:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return i
	return -1

func _update_sentinel(delta: float) -> void:
	var machine := level.sentinel
	var target := Vector3(player.position.x, 3.95 + sin(_age * 1.8) * 0.16, player.position.z)
	machine.position = machine.position.move_toward(target, delta * 1.45)
	var look_at_point := Vector3(player.position.x, machine.position.y, player.position.z)
	if machine.position.distance_to(look_at_point) > 0.1:
		machine.look_at(look_at_point, Vector3.UP, true)
	if machine.position.distance_to(player.camera.global_position) < 4.6:
		var query := PhysicsRayQueryParameters3D.create(machine.global_position, player.camera.global_position, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			health = maxf(0, health - delta * 14.0)
			_damage_overlay.color.a = 0.16

func _spawn_fragment(at: Vector3, tint: Color, impulse: Vector3) -> void:
	if _debris.size() >= MAX_DEBRIS:
		return
	var body := RigidBody3D.new()
	body.mass = 0.4
	body.collision_layer = 4
	body.collision_mask = 1
	body.linear_damp = 0.8
	body.angular_damp = 1.0
	level.add_child(body)
	body.global_position = at
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.27
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	AshGeometry.box(body, Vector3.ZERO, Vector3.ONE * 0.27, AshGeometry.material(tint))
	body.apply_central_impulse(impulse)
	body.angular_velocity = Vector3(impulse.z, 2.2, impulse.x)
	_debris.append({"node": body, "life": 4.2})

func _pulse_flash(at: Vector3) -> void:
	var mat := AshGeometry.material(Color(0.45, 1.0, 0.72, 0.18), 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var view := AshGeometry.sphere(level, at, 0.22, mat)
	_flashes.append({"node": view, "life": 0.28})

func _finish(won: bool) -> void:
	if won:
		var score := int(seconds * 10.0) + (level.total_blocks - level.remaining_blocks())
		if not sandbox:
			_best = maxi(_best, score)
	_has_session = false
	_save_now()
	_show_menu("win" if won else "lose")

func _retry_with_ad() -> void:
	if _waiting_ad:
		return
	_waiting_ad = true
	for node in _menu_content.find_children("*", "Button", true, false):
		node.disabled = true
	Platform.show_interstitial()

func _after_ad() -> void:
	if not _waiting_ad:
		return
	_waiting_ad = false
	# Browser pointer lock requires a fresh gesture after the asynchronous ad.
	_start_run(sandbox, false, true)

func _save_now() -> void:
	if not is_instance_valid(level):
		return
	var session: Dictionary = {}
	if _has_session:
		session = {
			"sandbox": sandbox, "collected": collected.duplicate(), "health": health,
			"seconds": seconds, "charges": charges, "used_threads": used_threads.duplicate(),
			"destroyed": level.snapshot(),
			"position": [player.position.x, player.position.y, player.position.z],
			"yaw": player.rotation.y, "pitch": player.camera.rotation.x
		}
	_saved = {"version": 1, "best": _best, "muted": _muted, "high_quality": _high_quality, "session": session}
	Platform.save_data(_saved)

func _save_failed() -> void:
	_save_problem = true
	if is_instance_valid(_toast_label):
		_toast("Браузер не разрешает сохранение. После закрытия прогресс может потеряться.", 8.0)

func _toggle_sound() -> void:
	_muted = not _muted
	# At the title screen do not discard a previously saved session.
	_saved["muted"] = _muted
	_saved["version"] = 1
	Platform.save_data(_saved)
	AudioServer.set_bus_mute(0, _muted or not running)
	_show_menu(_menu_mode)

func _audio_setup() -> void:
	_ambient = _audio("res://assets/audio/workshop.wav", -24.0)
	_hit_audio = _audio("res://assets/audio/hit.wav", -14.0)
	_pulse_audio = _audio("res://assets/audio/pulse.wav", -16.0)
	_pickup_audio = _audio("res://assets/audio/core.wav", -14.0)

func _toggle_quality() -> void:
	_high_quality = not _high_quality
	get_viewport().msaa_3d = Viewport.MSAA_4X if _high_quality else Viewport.MSAA_DISABLED
	level.set_quality(_high_quality)
	_saved["high_quality"] = _high_quality
	Platform.save_data(_saved)
	_show_menu(_menu_mode)

func _audio(path: String, volume: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	if ResourceLoader.exists(path):
		audio.stream = load(path)
		if path.ends_with("workshop.wav") and audio.stream is AudioStreamWAV:
			var wav := audio.stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	audio.volume_db = volume
	add_child(audio)
	return audio

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = preload("res://assets/shaders/vignette.gdshader")
	vignette.material = vignette_mat
	_hud.add_child(vignette)
	_objective = _label(_hud, "", 27, Color("e6d6b7"))
	_objective.position = Vector2(28, 24)
	_objective.size = Vector2(620, 80)
	_status = _label(_hud, "", 22, Color("9bddb9"))
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.position += Vector2(-238, 24)
	_status.size = Vector2(210, 88)
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.position = Vector2(28, 110)
	_health_bar.size = Vector2(190, 8)
	_health_bar.modulate = Color("9bd4b2")
	_hud.add_child(_health_bar)
	_tools = _label(_hud, "", 20, Color("e6d6b7"))
	_tools.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_tools.position += Vector2(28, -74)
	_tools.size = Vector2(800, 55)
	var crosshair := _label(_hud, "+", 22, Color("e4eacb"))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(8, 16)
	_hint = _label(_hud, "", 21, Color("d6e8ce"))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hint.position += Vector2(-270, 38)
	_hint.size = Vector2(540, 55)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label = _label(_hud, "", 22, Color("f2dba7"))
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.position += Vector2(-390, -142)
	_toast_label.size = Vector2(780, 62)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_damage_overlay = ColorRect.new()
	_damage_overlay.color = Color(0.8, 0.12, 0.04, 0)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_damage_overlay)
	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position += Vector2(-85, 125)
	pause_button.size = Vector2(58, 48)
	pause_button.pressed.connect(_pause)
	_hud.add_child(pause_button)
	_touch_ui()
	_menu_backdrop = AshMenuBackdrop.new()
	_menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_menu_backdrop)
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.039, 0.12)
	style.content_margin_left = 58
	style.content_margin_right = 30
	style.content_margin_top = 40
	style.content_margin_bottom = 28
	_menu.add_theme_stylebox_override("panel", style)
	root.add_child(_menu)
	_layout_menu()
	get_viewport().size_changed.connect(_layout_menu)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu.add_child(scroll)
	_menu_content = VBoxContainer.new()
	_menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_menu_content)

func _layout_menu() -> void:
	_menu.offset_right = minf(610.0, get_viewport().get_visible_rect().size.x)

func _label(parent: Node, value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _show_menu(mode: String) -> void:
	_menu_mode = mode
	_set_running(false)
	for node in _menu_content.get_children():
		_menu_content.remove_child(node)
		node.queue_free()
	_menu.visible = true
	_menu_text("Г Л А В А  I   /   Ц Е Х  П А М Я Т И", 13, Color("a3c9b9"))
	var title := _menu_text("Пепельные\nнити", 58, Color("ebe4cd"))
	title.add_theme_font_override("font", preload("res://assets/fonts/DejaVuSerif.ttf"))
	title.add_theme_constant_override("line_spacing", -8)
	_menu_text("Свет помнит дорогу домой.", 19, Color("b5b9a8"))
	var separator := HSeparator.new()
	separator.modulate = Color(0.61, 0.78, 0.68, 0.35)
	_menu_content.add_child(separator)
	if mode == "title":
		_menu_text("Мир замолчал. Но в старой мастерской\nещё теплится жизнь. Стань Стежком —\nи собери её по ниточке.", 20)
		var session = _saved.get("session", {})
		if session is Dictionary and not session.is_empty():
			_menu_button("01    ПРОДОЛЖИТЬ ПУТЬ", func(): _start_run(false, true))
			_menu_button("02    НАЧАТЬ ЗАНОВО", func(): _start_run(false))
		else:
			_menu_button("01    ВОЙТИ В МАСТЕРСКУЮ", func(): _start_run(false))
		_menu_button("02    СВОБОДНОЕ РАЗРУШЕНИЕ", func(): _start_run(true))
	elif mode == "pause":
		_menu_text("Нить натянута. Время остановилось.", 21)
		_menu_button("01    ПРОДОЛЖИТЬ", _resume)
		_menu_button("02    СОХРАНИТЬ И В МЕНЮ", _save_and_title)
	elif mode == "win":
		_menu_text("СВЕТ ВЕРНУЛСЯ ДОМОЙ", 25, Color("b3efd0"))
		_menu_text("Три ядра спасены. В убежище снова\nслышно тихое дыхание.", 20)
		_menu_text("Разобрано блоков: %d  ·  Рекорд: %d" % [level.total_blocks - level.remaining_blocks(), _best], 17)
		_menu_button("ЕЩЁ ОДНА ПОПЫТКА · ВОЗМОЖНА РЕКЛАМА", _retry_with_ad)
		_menu_button("В МЕНЮ", func(): _show_menu("title"))
	elif mode == "lose":
		_menu_text("НИТЬ ОБОРВАЛАСЬ", 25, Color("e7b798"))
		_menu_text("Сначала пробей проходы ко всем ядрам.\nИ только потом поднимай первое.", 20)
		_menu_button("ПОПРОБОВАТЬ СНОВА · ВОЗМОЖНА РЕКЛАМА", _retry_with_ad)
		_menu_button("В МЕНЮ", func(): _show_menu("title"))
	elif mode == "help":
		_menu_text("ПОДГОТОВЬ ПУТЬ. СОБЕРИ СВЕТ. ВЕРНИСЬ.", 18, Color("b3efd0"))
		_menu_text("До первого ядра время не идёт. Разбей преграды, запомни дорогу. Затем собери три ядра за 140 секунд и вернись к зелёному выходу. Узлы нити лечат и заряжают катушку.", 18)
		_menu_text("WASD — движение  ·  мышь — обзор\nЛКМ / R — удар  ·  ПКМ / F — взять\n1 / 2 — инструменты  ·  Shift — бег\nПробел — прыжок  ·  Esc / P — пауза\nБез мыши: Q/E — поворот, T/G — обзор.", 17)
		_menu_button("НАЗАД К СВОЕЙ НИТИ", func(): _show_menu(_help_return))
	if mode != "help":
		_menu_button("03    КАК ИГРАТЬ", _open_help, true)
		var settings := HBoxContainer.new()
		settings.add_theme_constant_override("separation", 8)
		_menu_content.add_child(settings)
		_menu_button("ЗВУК  " + ("ВЫКЛ" if _muted else "ВКЛ"), _toggle_sound, true, settings)
		_menu_button("ГРАФИКА  " + ("ВЫСОКАЯ" if _high_quality else "ЭКОНОМНАЯ"), _toggle_quality, true, settings)
	_menu_text("v0.3  /  Прогресс сохраняется на этом устройстве" + ("\nСохранение недоступно." if _save_problem else ""), 13, Color("84998e"))
	for child in _menu_content.get_children():
		if child is Button:
			child.grab_focus()
			break

func _menu_text(value: String, font_size: int, tint: Color = Color("cccabc")) -> Label:
	var label := _label(_menu_content, value, font_size, tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _save_and_title() -> void:
	_save_now()
	_show_menu("title")

func _open_help() -> void:
	_help_return = _menu_mode
	_show_menu("help")

func _menu_button(value: String, callback: Callable, quiet: bool = false, parent: Node = null) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 38 if quiet else 54
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14 if quiet else 17)
	button.add_theme_color_override("font_color", Color("dadccc"))
	button.add_theme_color_override("font_hover_color", Color("efffe4"))
	button.add_theme_color_override("font_focus_color", Color("efffe4"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		var lit: bool = state == "hover" or state == "pressed"
		style.bg_color = Color(0.26, 0.42, 0.36, 0.55) if lit else Color(0.09, 0.16, 0.15, 0.45 if not quiet else 0.12)
		style.border_color = Color("b7e3c9") if lit or state == "focus" else Color("425a50")
		style.border_width_left = 3 if not quiet else 1
		style.border_width_bottom = 1
		style.content_margin_left = 17
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	(parent if parent != null else _menu_content).add_child(button)

func _touch_ui() -> void:
	var touch := DisplayServer.is_touchscreen_available()
	_touch_pad = Panel.new()
	_touch_pad.visible = touch
	_touch_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_touch_pad.position += Vector2(28, -208)
	_touch_pad.size = Vector2(160, 160)
	_touch_pad.gui_input.connect(_touch_move_input)
	_hud.add_child(_touch_pad)
	_label(_touch_pad, "ДВИЖЕНИЕ", 17, Color("c9d5c0")).position = Vector2(20, 65)
	var row := HBoxContainer.new()
	row.visible = touch
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	row.position += Vector2(-485, -90)
	row.add_theme_constant_override("separation", 10)
	_hud.add_child(row)
	_touch_button(row, "УДАР", _strike)
	_touch_button(row, "ВЗЯТЬ", _interact)
	_touch_button(row, "↑", player.jump_touch)
	_touch_button(row, "1 / 2", func(): player.set_tool(1 - player.tool))
	_touch_button(row, "БЕГ", func(): player.touch_sprint = not player.touch_sprint)
	if touch:
		_tools.position.y -= 190
		_toast_label.position.y -= 95

func _touch_button(parent: Node, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(80, 64)
	button.pressed.connect(callback)
	parent.add_child(button)

func _touch_move_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_index = event.index
			player.touch_move = ((event.position - _touch_pad.size * 0.5) / 60.0).limit_length()
		elif event.index == _touch_index:
			_touch_index = -1
			player.touch_move = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == _touch_index:
		player.touch_move = ((event.position - _touch_pad.size * 0.5) / 60.0).limit_length()
	_touch_pad.accept_event()

func _update_hud() -> void:
	if not is_instance_valid(_objective):
		return
	_objective.text = "СВЕТ ВНУТРИ  %d / 3\n%s" % [collected.size(), "Вернись к зелёному выходу" if collected.size() == CORE_COUNT else "Подготовь путь. Найди три ядра."]
	_status.text = ("СБОРЩИК АКТИВЕН\n%02d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]) if alarm else ("СВОБОДНЫЙ РЕЖИМ" if sandbox else "ТИШИНА\nТаймер ещё не запущен")
	_status.modulate = Color("f3a478") if alarm else Color.WHITE
	_health_bar.value = health
	_tools.text = "%s     |     ИМПУЛЬСЫ %d / 5\n1 / 2 — смена инструмента · F / ПКМ — взять" % ["[1] КИЯНКА" if player.tool == 0 else "[2] ИМПУЛЬСНАЯ КАТУШКА", charges]
	_hint.text = ""
	if _near_core() >= 0:
		_hint.text = "F / ПКМ · ЗАБРАТЬ СВЕТ"
	elif _near_thread_node() >= 0:
		_hint.text = "F / ПКМ · ВПЛЕСТИ УЗЕЛ НИТИ"
	elif player.position.distance_to(level.exit_at) < 2.4:
		_hint.text = "F / ПКМ · В УБЕЖИЩЕ" if collected.size() == CORE_COUNT else "ВЕРНИСЬ С ТРЕМЯ ЯДРАМИ"
	else:
		var hit := player.ray(3.2)
		if not hit.is_empty():
			var collider: Node = hit["collider"]
			var grid := collider.get_parent() as VoxelStructure
			if grid:
				_hint.text = "ЛКМ / R · " + grid.material_name.to_upper()

func _toast(message: String, duration: float = 4.0) -> void:
	_toast_label.text = message
	_toast_time = duration
	_toast_label.visible = true
