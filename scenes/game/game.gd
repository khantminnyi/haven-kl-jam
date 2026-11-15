extends Node
# shared game stuff: level order, save file, mute and scene changes.

const MENU := "res://scenes/ui/menu.tscn"
const SAVE_PATH := "user://save.cfg"
# add new levels here, in order.
const LEVELS: Array[Dictionary] = [
	{"name": "basic training", "path": "res://scenes/level/levels/tutorial.tscn"},
	{"name": "the sniper", "path": "res://scenes/level/levels/soldier_1.tscn"},
	{"name": "grandma vs the dog", "path": "res://scenes/level/levels/grandpa_1.tscn"},
	{"name": "lactose intolerant", "path": "res://scenes/level/levels/lactose_1.tscn"},
]

# where the team's recorded runs live (one json per level). shipped with the game.
const GHOST_DIR := "res://ghosts/"

var unlocked := 1  # how many levels you can pick in the menu
var best_times := {}  # level index -> fastest run in seconds
var _overlay: ColorRect
var _loading: Label
var _busy := false
var muted := false  # the mute button (or M); remembered between runs
var _mute_button: Button
var _fps_label: Label  # F5 debug readout, like minecraft
var _fps_timer := 0.0
var _ghost_cache := {}  # level index -> recording (an empty dictionary if there is none)


# up up down down left right left right b a.
const KONAMI: Array[Key] = [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]

var _konami_progress := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# hold F for ragdoll mode (limbs go 10x floppier). added here so it needs no input-map edit.
	if not InputMap.has_action("ragdoll"):
		InputMap.add_action("ragdoll")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		InputMap.action_add_event("ragdoll", key)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		unlocked = clampi(int(config.get_value("progress", "unlocked", 1)), 1, LEVELS.size())
		best_times = config.get_value("progress", "best_times", {})
		muted = bool(config.get_value("settings", "muted", false))
	_build_overlay()
	_apply_mute()


func over_mute_button(point: Vector2) -> bool:
	return _mute_button != null and _mute_button.get_global_rect().has_point(point)


func toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	_save()


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	if _mute_button:
		if muted:
			_mute_button.text = "unmute (M)"
		else:
			_mute_button.text = "mute (M)"


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_M:
		toggle_mute()
		return
	if key.keycode == KEY_F5:
		_fps_label.visible = not _fps_label.visible  # F5: show or hide the fps readout
		return
	if key.keycode == KONAMI[_konami_progress]:
		_konami_progress = _konami_progress + 1
	else:
		_konami_progress = (1 if key.keycode == KONAMI[0] else 0)
	if _konami_progress == KONAMI.size():
		_konami_progress = 0
		if CharacterRig.head_scale > 2.0:
			CharacterRig.head_scale = 1.5
		else:
			CharacterRig.head_scale = 3.0
		Sfx.play("bell_01")
		_loading.text = "big heads %s" % ("on" if CharacterRig.head_scale > 2.0 else "off")
		var toast := create_tween()
		toast.tween_property(_loading, "modulate:a", 1.0, 0.1)
		toast.tween_interval(1.4)
		toast.tween_property(_loading, "modulate:a", 0.0, 0.4)


func go_to_level(index: int) -> void:
	Level.skip_intro = false
	change_scene(LEVELS[index]["path"])


func go_to_menu() -> void:
	change_scene(MENU)


func report_time(seconds: float) -> bool:
	var index := current_level_index()
	var is_best: bool = not best_times.has(index) or seconds < float(best_times[index])
	if is_best:
		best_times[index] = seconds
	if OS.is_debug_build():
		print("[Game] level %d finished in %.1f s" % [index, seconds])
	unlocked = maxi(unlocked, mini(index + 2, LEVELS.size()))
	_save()
	return is_best


func level_won() -> void:
	var index := current_level_index()
	if index + 1 < LEVELS.size():
		go_to_level(index + 1)
	else:
		go_to_menu()


func _process(delta: float) -> void:
	if _fps_label == null or not _fps_label.visible:
		return
	_fps_timer -= delta
	if _fps_timer > 0.0:
		return
	_fps_timer = 0.25
	_fps_label.text = "le recoil 1.0 (F5 to hide)
%d fps  (%.1f ms/frame)
nodes %d   draw calls %d
level %d   time scale %.2f   %s" % [
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		current_level_index(), Engine.time_scale, "muted" if muted else "sound on"]


func current_level_index() -> int:
	if get_tree().current_scene == null:
		return -1
	var path := get_tree().current_scene.scene_file_path
	for i in range(LEVELS.size()):
		if LEVELS[i]["path"] == path:
			return i
	return -1


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	Engine.time_scale = 1.0
	if path == MENU:
		Sfx.stop_music()  # level to level keeps going only if the next level has no track of its own
	Sfx.play("switch_01", -4.0)
	_loading.text = "loading..."
	var fade_out := create_tween()
	fade_out.tween_property(_overlay, "color:a", 1.0, 0.25)
	fade_out.parallel().tween_property(_loading, "modulate:a", 1.0, 0.25)
	await fade_out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "color:a", 0.0, 0.35)
	fade_in.parallel().tween_property(_loading, "modulate:a", 0.0, 0.2)
	await fade_in.finished
	_busy = false


func ghost_data(index: int) -> Dictionary:
	if not _ghost_cache.has(index):
		var data := {}
		var file := FileAccess.open(GHOST_DIR + "level_%d.json" % index, FileAccess.READ)
		if file:
			data = JSON.parse_string(file.get_as_text()) as Dictionary
		_ghost_cache[index] = data if data != null else {}
	return _ghost_cache[index]


func dev_time(index: int) -> float:
	return float(ghost_data(index).get("time", -1.0))


func save_ghost(index: int, seconds: float, times: PackedFloat32Array, points: PackedVector2Array) -> void:
	if not OS.is_debug_build() or times.size() < 2:
		return
	var existing := dev_time(index)
	if existing > 0.0 and seconds >= existing:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GHOST_DIR))
	var flat: Array = []
	for point in points:
		flat.append(roundi(point.x))
		flat.append(roundi(point.y))
	var file := FileAccess.open(GHOST_DIR + "level_%d.json" % index, FileAccess.WRITE)
	if file == null:
		push_warning("could not save the dev ghost")
		return
	file.store_string(JSON.stringify({"time": snappedf(seconds, 0.01), "t": Array(times), "p": flat}))
	_ghost_cache.erase(index)
	print("[Game] new dev ghost for level %d: %.1f s (commit ghosts/level_%d.json to share it)" % [index, seconds, index])


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "best_times", best_times)
	config.set_value("settings", "muted", muted)
	config.save(SAVE_PATH)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.06, 0.06, 0.08, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	# the mute button lives on every screen, top right.
	var top := CanvasLayer.new()
	top.layer = 120
	add_child(top)
	_mute_button = Button.new()
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.custom_minimum_size = Vector2(150, 40)
	_mute_button.anchor_left = 1.0
	_mute_button.anchor_right = 1.0
	_mute_button.offset_left = -166.0
	_mute_button.offset_right = -16.0
	_mute_button.offset_top = 12.0
	_mute_button.offset_bottom = 52.0
	_mute_button.add_theme_font_size_override("font_size", 20)
	_mute_button.add_theme_color_override("font_color", Color("#1b1b1b"))
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		if state == "hover":
			box.bg_color = Color("#ec3750")
		else:
			box.bg_color = Color("#f2ead3")
		box.border_color = Color("#1b1b1b")
		box.set_border_width_all(4)
		box.set_corner_radius_all(5)
		_mute_button.add_theme_stylebox_override(state, box)
	_mute_button.pressed.connect(toggle_mute)
	top.add_child(_mute_button)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 8)
	_fps_label.visible = false
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.add_theme_color_override("font_color", Color("#ffffff"))
	_fps_label.add_theme_color_override("font_outline_color", Color("#1b1b1b"))
	_fps_label.add_theme_constant_override("outline_size", 8)
	top.add_child(_fps_label)
	_loading = Label.new()
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.add_theme_font_size_override("font_size", 36)
	_loading.add_theme_color_override("font_color", Color("#f2ead3"))
	_loading.modulate.a = 0.0
	layer.add_child(_loading)
