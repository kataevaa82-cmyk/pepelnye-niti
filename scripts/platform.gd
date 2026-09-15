extends Node
## Browser boundary. In the editor it uses user:// without requiring the SDK.

signal pause_requested
signal ad_closed
signal save_failed

var blocked := false
var sdk_state := "native"
var _poll_elapsed := 0.0
var _bridge_available := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_bridge_available = bool(JavaScriptBridge.eval("typeof window.AshPlatform !== 'undefined'"))

func _process(delta: float) -> void:
	if not _bridge_available:
		return
	_poll_elapsed += delta
	if _poll_elapsed < 0.08:
		return
	_poll_elapsed = 0.0
	var payload = JavaScriptBridge.eval("window.AshPlatform.poll()")
	var state = JSON.parse_string(str(payload))
	if not state is Dictionary:
		return
	blocked = bool(state.get("blocked", false))
	sdk_state = str(state.get("sdkState", "offline"))
	for event in state.get("events", []):
		match str(event.get("type", "")):
			"pause": pause_requested.emit()
			"ad_closed": ad_closed.emit()
			"save_failed": save_failed.emit()

func loading_ready() -> void:
	if _bridge_available:
		JavaScriptBridge.eval("window.AshPlatform.ready()")

func gameplay(active: bool) -> void:
	if _bridge_available:
		JavaScriptBridge.eval("window.AshPlatform.playing(%s)" % ("true" if active else "false"))

func show_interstitial() -> void:
	if _bridge_available:
		JavaScriptBridge.eval("window.AshPlatform.interstitial()")
	else:
		call_deferred("_local_ad_closed")

func _local_ad_closed() -> void:
	ad_closed.emit()

func save_data(data: Dictionary) -> bool:
	if OS.get_environment("ASH_TESTING") == "1":
		return true
	var encoded := JSON.stringify(data)
	var saved := false
	if _bridge_available:
		saved = bool(JavaScriptBridge.eval("window.AshPlatform.writeSave(%s)" % JSON.stringify(encoded)))
	else:
		var file := FileAccess.open("user://progress.json", FileAccess.WRITE)
		if file:
			file.store_string(encoded)
			file.flush()
			saved = file.get_error() == OK
	if not saved:
		save_failed.emit()
	return saved

func load_data() -> Dictionary:
	if OS.get_environment("ASH_TESTING") == "1":
		return {}
	var encoded := ""
	if _bridge_available:
		encoded = str(JavaScriptBridge.eval("window.AshPlatform.readSave()"))
	elif FileAccess.file_exists("user://progress.json"):
		encoded = FileAccess.get_file_as_string("user://progress.json")
	var parsed = JSON.parse_string(encoded) if not encoded.is_empty() else null
	if parsed is Dictionary and int(parsed.get("version", 0)) == 1:
		return parsed
	return {}
