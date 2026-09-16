extends RefCounted
class_name AshSurfaces
## Original procedural surfaces; no downloaded texture dependencies.

const SURFACE = preload("res://assets/shaders/surface.gdshader")
static var _cache: Dictionary = {}

static func material(kind: int, tint: Color) -> ShaderMaterial:
	var key := "%d:%s" % [kind, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("surface_kind", kind)
	mat.set_shader_parameter("tint", tint)
	_cache[key] = mat
	return mat
