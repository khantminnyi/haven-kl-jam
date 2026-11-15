extends Node
# "Dev" autoload: debug-only helpers for playtesting and screenshots.
# pre-jam tooling, not game code. inert in release exports (OS.is_debug_build() is false there).
#
# hotkeys while running from the editor or a debug build:
#   f3   debug overlay (FPS, node count, time scale, physics frame)
#   f6   reload the current scene (F5 is the fps counter, see Game)
#   f9   cycle slow motion 1x / 0.5x / 0.25x / 0.1x (tune game feel frame by frame)
#   f11  toggle fullscreen
#   f12  screenshot -> res://shots/ (when run from the editor) or user://shots/
#
# user args after a bare `--` (for scripted playtests):
#   --shot-at=30,90         screenshot at these physics frames
#   --shot-dir=shots/run1   folder for those screenshots (project-relative)
#   --input=primary@20-25,move_right@30-120   hold input actions during physics-frame ranges
#   --drag=x1,y1>x2,y2@start-end;...   left-mouse drag in screen pixels: press at (x1,y1) on frame start,
#                           glide to (x2,y2), release on frame end. same point twice = press and hold.
#   --quit-at=200           quit at this physics frame (default: just after the last screenshot)
#   --keep-open             stay open after the last screenshot
#   --shot-scale=0.5        downscale saved screenshots (0.5 = half the width and height)
#   --time-scale=0.5        start with this Engine.time_scale

const SLOWMO_STEPS: Array[float] = [1.0, 0.5, 0.25, 0.1]

var _frame := 0
var _shot_frames: Array[int] = []
var _shot_dir := ""
var _quit_at := -1
var _pending_shots := 0
var _shot_scale := 1.0
var _scripted_inputs: Array[Dictionary] = []
var _scripted_drags: Array[Dictionary] = []
var _slowmo_index := 0
var _overlay_layer: CanvasLayer
var _overlay_label: Label
func _ready() -> void:
	if not OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_DISABLED
		set_process_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_user_args()
	_build_overlay()
func _physics_process(_delta: float) -> void:
	_frame += 1
	_apply_scripted_inputs()
	_apply_scripted_drags()
	if _frame in _shot_frames:
		take_screenshot(_shot_dir.path_join("frame_%05d.png" % _frame))
	if _quit_at >= 0 and _frame >= _quit_at and _pending_shots == 0:
		print("[Dev] QUIT at physics frame %d" % _frame)
		get_tree().quit()
func _process(_delta: float) -> void:
	if _overlay_layer.visible:
		_overlay_label.text = "FPS %d | nodes %d | time x%.2f | frame %d" % [
			Engine.get_frames_per_second(),
			get_tree().get_node_count(),
			Engine.time_scale,
			_frame,
		]
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F3:
			_overlay_layer.visible = not _overlay_layer.visible
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F9:
			_slowmo_index = (_slowmo_index + 1) % SLOWMO_STEPS.size()
			Engine.time_scale = SLOWMO_STEPS[_slowmo_index]
			print("[Dev] time scale x%.2f" % Engine.time_scale)
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		KEY_F12:
			take_screenshot()
		_:
			return
	get_viewport().set_input_as_handled()


func take_screenshot(path: String = "") -> String:
	if DisplayServer.get_name() == "headless":
		push_warning("[Dev] screenshots need a rendering window; headless runs can't take them")
		return ""
	if path.is_empty():
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		path = _default_shot_dir().path_join("shot_%s.png" % stamp)
	_pending_shots += 1
	await RenderingServer.frame_post_draw
	_pending_shots -= 1
	var image := get_viewport().get_texture().get_image()
	if _shot_scale > 0.0 and _shot_scale < 1.0:
		image.resize(maxi(1, roundi(image.get_width() * _shot_scale)), maxi(1, roundi(image.get_height() * _shot_scale)), Image.INTERPOLATE_BILINEAR)
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	_ensure_shots_gdignore()
	var err := image.save_png(absolute)
	if err != OK:
		push_error("[Dev] could not save screenshot to %s (error %d)" % [absolute, err])
		return ""
	print("[Dev] SHOT %s" % absolute)
	return absolute


func _parse_user_args() -> void:
	var keep_open := false
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"--shot-at":
				for frame_text in value.split(",", false):
					_shot_frames.append(frame_text.to_int())
			"--shot-dir":
				_shot_dir = value
			"--quit-at":
				_quit_at = value.to_int()
			"--keep-open":
				keep_open = true
			"--shot-scale":
				_shot_scale = value.to_float()
			"--time-scale":
				Engine.time_scale = value.to_float()
			"--input":
				_parse_scripted_inputs(value)
			"--drag":
				_parse_scripted_drags(value)
			_:
				push_warning("[Dev] unknown user arg: %s" % arg)
	if _shot_dir.is_empty():
		_shot_dir = _default_shot_dir()
	elif not (_shot_dir.begins_with("res://") or _shot_dir.begins_with("user://") or _shot_dir.is_absolute_path()):
		_shot_dir = _base_dir().path_join(_shot_dir)
	if not _shot_frames.is_empty() and _quit_at < 0 and not keep_open:
		_quit_at = int(_shot_frames.max()) + 2


func _parse_scripted_inputs(spec: String) -> void:
	for item in spec.split(",", false):
		var at := item.split("@")
		if at.size() != 2:
			push_warning("[Dev] --input: expected action@start-end, got '%s'" % item)
			continue
		if not InputMap.has_action(at[0]):
			push_warning("[Dev] --input: unknown action '%s'" % at[0])
			continue
		var span := at[1].split("-")
		var start := span[0].to_int()
		var end := span[1].to_int() if span.size() > 1 else start
		_scripted_inputs.append({"action": StringName(at[0]), "start": start, "end": end, "held": false})


func _apply_scripted_inputs() -> void:
	for step in _scripted_inputs:
		var should_hold: bool = _frame >= step["start"] and _frame <= step["end"]
		if should_hold == step["held"]:
			continue
		step["held"] = should_hold
		# parse_input_event (not action_press) so _input/_unhandled_input handlers fire too.
		var event := InputEventAction.new()
		event.action = step["action"]
		event.pressed = should_hold
		if should_hold:
			event.strength = 1.0
		else:
			event.strength = 0.0
		Input.parse_input_event(event)


func _parse_scripted_drags(spec: String) -> void:
	for item in spec.split(";", false):
		var at := item.split("@")
		var points := at[0].split(">") if at.size() == 2 else PackedStringArray()
		if points.size() != 2:
			push_warning("[Dev] --drag: expected x1,y1>x2,y2@start-end, got '%s'" % item)
			continue
		var span := at[1].split("-")
		var start := span[0].to_int()
		var end := span[1].to_int() if span.size() > 1 else start + 1
		_scripted_drags.append({"from": _parse_point(points[0]), "to": _parse_point(points[1]), "start": start, "end": maxi(end, start + 1)})


func _parse_point(text: String) -> Vector2:
	var xy := text.split(",")
	return Vector2(xy[0].to_float(), xy[1].to_float() if xy.size() > 1 else 0.0)


func _apply_scripted_drags() -> void:
	for drag in _scripted_drags:
		var start: int = drag["start"]
		var end: int = drag["end"]
		if _frame < start or _frame > end:
			continue
		var progress := float(_frame - start) / float(end - start)
		var pos: Vector2 = (drag["from"] as Vector2).lerp(drag["to"], progress)
		_send_mouse_motion(pos, _frame < end)
		if _frame == start:
			_send_mouse_button(pos, true)
		elif _frame == end:
			_send_mouse_button(pos, false)


func _send_mouse_motion(pos: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	else:
		event.button_mask = 0
	Input.parse_input_event(event)


func _send_mouse_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.global_position = pos
	event.pressed = pressed
	if pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	else:
		event.button_mask = 0
	Input.parse_input_event(event)


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 128
	_overlay_layer.visible = false
	_overlay_label = Label.new()
	_overlay_label.position = Vector2(8, 8)
	_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_overlay_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("outline_size", 4)
	_overlay_layer.add_child(_overlay_label)
	add_child(_overlay_layer)


func _base_dir() -> String:
	if OS.has_feature("editor"):
		return "res://"
	else:
		return "user://"


func _default_shot_dir() -> String:
	return _base_dir().path_join("shots")


func _ensure_shots_gdignore() -> void:
	if _base_dir() != "res://":
		return
	var marker := ProjectSettings.globalize_path("res://shots/.gdignore")
	if not FileAccess.file_exists(marker):
		DirAccess.make_dir_recursive_absolute(marker.get_base_dir())
		FileAccess.open(marker, FileAccess.WRITE).close()
