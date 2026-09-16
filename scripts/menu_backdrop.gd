extends Control
class_name AshMenuBackdrop

const BACKGROUND = preload("res://assets/menu/workshop-dream.webp")
var _clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = BACKGROUND
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/menu_shade.gdshader")
	shade.material = mat
	add_child(shade)
	# Draw floating ash above the image, below the interactive menu.
	var dust := Control.new()
	dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dust.draw.connect(func(): _draw_dust(dust))
	add_child(dust)
	set_meta("dust", dust)

func _process(delta: float) -> void:
	if visible:
		_clock += delta
		var dust: Control = get_meta("dust")
		dust.queue_redraw()

func _draw_dust(canvas: Control) -> void:
	for i in range(42):
		var x := fposmod(float(i) * 173.7 + sin(_clock * 0.18 + i) * 26.0, maxf(size.x, 1.0))
		var y := fposmod(float(i) * 97.3 - _clock * (6.0 + float(i % 5)), maxf(size.y, 1.0))
		var alpha := (sin(_clock * 0.7 + float(i) * 1.9) * 0.5 + 0.5) * 0.55
		canvas.draw_circle(Vector2(x, y), 0.7 + float(i % 3) * 0.4, Color(0.9, 0.75, 0.48, alpha))
	var points := PackedVector2Array()
	for i in range(60):
		var y := 38.0 + float(i) / 59.0 * (size.y - 76.0)
		points.append(Vector2(27.0 + sin(float(i) * 0.14 + _clock * 0.5) * 3.0, y))
	canvas.draw_polyline(points, Color(0.53, 0.85, 0.73, 0.38), 1.0, true)
	var bead_y := 40.0 + (sin(_clock * 0.18) * 0.5 + 0.5) * (size.y - 80.0)
	canvas.draw_circle(Vector2(27, bead_y), 3, Color("b8f2d8"))
