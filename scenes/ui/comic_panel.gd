class_name ComicPanel
extends Control
# dialogue box, typewriter text and story cues. speaker chooses the box style.

enum Kind { NARRATOR, RADIO, BUBBLE }

const INK := Color("#1b1b1b")
const PAPER := Color("#f2ead3")
const GOLD := Color("#f2d9a0")
const GREEN := Color("#6cff8a")
const BARS := 130.0  ## height of each cinematic bar
const VOICE_ROOT := "res://audio/voice/"

# a stage cue/direction started ("" = back to normal). Level acts it out.
signal stage(cue: String)
# a new line started; who is speaking it (the level uses this to point the camera).
signal line_started(who: String)

const DIRECTION_SECONDS := 2.8

var active := false
# who is who in the world, so bubbles know where to point. set by Level.
var shooter_node: Node2D
var target_node: Node2D
var actor_node: Node2D  ## a cutscene extra (the dog) who speaks instead of the target, while they exist
# recordings are looked up as res://audio/voice/<voice_id>_<section>_<line number>.ogg|mp3|wav.
var voice_id := ""

var _lines: PackedStringArray = []
var _speaker := ""
var _section := "story"
var _on_done := Callable()
var _index := 0
var _chars := 0.0
var _time := 0.0
var _bars := 0.0  # 0 = hidden, 1 = fully in
var _last_blip := 0
var _direction_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func play(speaker: String, lines: PackedStringArray, on_done: Callable, section := "story") -> void:
	if lines.is_empty():
		on_done.call()
		return
	_speaker = speaker
	_lines = lines
	_section = section
	_on_done = on_done
	_index = 0
	active = true
	visible = true
	_start_line()


func _who(index: int) -> String:
	var line := _lines[index]
	if "|" in line:
		return line.get_slice("|", 0)
	else:
		return _speaker


func _text(index: int) -> String:
	var line := _lines[index]
	if "|" in line:
		return line.get_slice("|", 1)
	else:
		return line


func _is_direction(index: int) -> bool:
	var text := _text(index).strip_edges()
	return text.begins_with("(") and text.ends_with(")")


func _cue(index: int) -> String:
	var line := _lines[index]
	if _is_direction(index):
		return _text(index).strip_edges().trim_prefix("(").trim_suffix(")")
	if line.count("|") >= 2:
		return line.get_slice("|", 2)
	else:
		return ""


func _kind(index: int) -> Kind:
	var who := _who(index).to_lower()
	if who.contains("narrator"):
		return Kind.NARRATOR
	if who == "sarge":
		return Kind.RADIO
	return Kind.BUBBLE


func _type_speed(kind: Kind) -> float:
	if kind == Kind.NARRATOR:
		return 26.0
	if kind == Kind.RADIO:
		return 45.0
	return 55.0


func _start_line() -> void:
	_chars = 0.0
	_last_blip = 0
	if _is_direction(_index):
		_direction_left = DIRECTION_SECONDS
	else:
		_direction_left = 0.0
	Sfx.stop_voice()
	stage.emit(_cue(_index))
	line_started.emit(_who(_index))
	var kind := _kind(_index)
	if kind == Kind.RADIO:
		Sfx.play("switch_01", -12.0, 1.6)  # radio click
	elif kind == Kind.NARRATOR and voice_id != "":
		var base := "%s%s_%s_%d" % [VOICE_ROOT, voice_id, _section, _index]
		for extension in ["ogg", "mp3", "wav"]:
			if ResourceLoader.exists(base + "." + extension):
				Sfx.play_voice(base + "." + extension)
				break


func _process(delta: float) -> void:
	if not active:
		return
	# real time, so panels still type during slow-mo.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_time += real_delta
	var kind := _kind(_index)
	_chars += real_delta * _type_speed(kind)
	if _direction_left > 0.0:
		_direction_left -= real_delta
		if _direction_left <= 0.0:
			_advance()
			return
	_bars = move_toward(_bars, 1.0 if kind == Kind.NARRATOR else 0.0, real_delta * 2.5)
	# a quiet tick every few letters, like a speaking blip.
	if kind != Kind.NARRATOR and int(_chars) >= _last_blip + 3 and _chars < _text(_index).length():
		_last_blip = int(_chars)
		Sfx.play("switch_02", -28.0, 1.5 if kind == Kind.RADIO else randf_range(1.1, 1.4))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not active:
		return
	var click := event as InputEventMouseButton
	var pressed := (click != null and click.pressed) or event.is_action_pressed("primary")
	if not pressed:
		return
	if click != null and Game.over_mute_button(click.position):
		return  # that click is for the mute button
	get_viewport().set_input_as_handled()
	if _is_direction(_index):
		_advance()
		return
	if _chars < _text(_index).length():
		_chars = 9999.0  # first click: finish typing
		return
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		active = false
		visible = false
		_bars = 0.0
		Sfx.stop_voice()
		stage.emit("")
		_on_done.call()
	else:
		_start_line()


func _draw() -> void:
	if not active:
		return
	var size := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var text := _text(_index).substr(0, int(_chars))
	var done := _chars >= _text(_index).length()
	_draw_bars(size)
	if _is_direction(_index):
		return  # a stage direction is only shown, never printed
	match _kind(_index):
		Kind.NARRATOR:
			_draw_narrator(font, size, text, done)
		Kind.RADIO:
			_draw_radio(font, text, done)
		Kind.BUBBLE:
			_draw_bubble(font, size, text, done)


func _draw_bars(size: Vector2) -> void:
	var height := BARS * smoothstep(0.0, 1.0, _bars)
	if height <= 0.5:
		return
	draw_rect(Rect2(0, 0, size.x, height), Color.BLACK)
	draw_rect(Rect2(0, size.y - height, size.x, height), Color.BLACK)


func _draw_narrator(font: Font, size: Vector2, text: String, done: bool) -> void:
	if _bars < 0.9:
		return
	var rect := Rect2(size.x * 0.12, size.y - BARS + 22.0, size.x * 0.76, BARS - 30.0)
	draw_multiline_string(font, rect.position + Vector2(0, 26), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30, 2, GOLD)
	draw_string(font, Vector2(size.x * 0.12, BARS - 40.0), "the narrator", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GOLD, 0.6))
	if done and fmod(_time, 1.0) < 0.6:
		draw_string(font, Vector2(size.x - 120.0, size.y - 18.0), "click", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(GOLD, 0.7))


func _draw_radio(font: Font, text: String, done: bool) -> void:
	var box := Rect2(36.0, 36.0, 620.0, 150.0)
	draw_rect(Rect2(box.position + Vector2(8, 8), box.size), INK)
	draw_rect(box, Color("#0d1f16"))
	for y in range(0, int(box.size.y), 6):
		draw_line(box.position + Vector2(0, y), box.position + Vector2(box.size.x, y), Color(0, 0, 0, 0.25), 2.0)
	for i in range(14):  # static
		var spot := box.position + Vector2(randf() * box.size.x, randf() * box.size.y)
		draw_rect(Rect2(spot, Vector2(randf_range(4.0, 22.0), 2.0)), Color(GREEN, 0.12))
	draw_rect(box, GREEN, false, 4.0)
	draw_string(font, box.position + Vector2(16, 28), "%s // radio" % _who(_index), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GREEN, 0.7))
	draw_multiline_string(font, box.position + Vector2(16, 66), text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32.0, 30, 3, GREEN)
	if done and fmod(_time, 0.8) < 0.5:
		draw_string(font, box.end - Vector2(80, 14), "click", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GREEN)


func _draw_bubble(font: Font, size: Vector2, text: String, done: bool) -> void:
	var who := _who(_index)
	# measure the finished line, even while typing. otherwise the bubble grows every letter.
	var full := _text(_index)
	var anchor := shooter_node if who.to_lower() == _speaker.to_lower() else (actor_node if is_instance_valid(actor_node) else target_node)
	var point := size / 2.0
	if anchor:
		point = anchor.get_global_transform_with_canvas().origin
	var font_size := 30 if full.length() <= 100 else (24 if full.length() <= 150 else 20)
	# measure the whole line up front, so the box is the right size from the first letter.
	var width := clampf(font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 44.0, 260.0, 620.0)
	var text_size := font.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, width - 40.0, font_size)
	var box := Rect2(0, 0, width, text_size.y + 56.0)
	box.position = Vector2(clampf(point.x - width / 2.0, 20.0, size.x - width - 20.0), clampf(point.y - 120.0 - box.size.y, 52.0, maxf(size.y - box.size.y - 40.0, 52.0)))
	# a gentle bob so it feels alive.
	box.position.y += sin(_time * 3.0) * 3.0
	var tail_x := clampf(point.x, box.position.x + 30.0, box.end.x - 30.0)
	# a short stubby tail pointing towards the speaker (never a long spike across the screen).
	var base := Vector2(tail_x, box.end.y - 2.0)
	var toward := (Vector2(clampf(point.x, 20.0, size.x - 20.0), point.y - 50.0) - base)
	var tip := base + toward.normalized() * minf(toward.length(), 44.0) if toward.length() > 1.0 else base + Vector2(0, 24)
	var tail := PackedVector2Array([base + Vector2(-14, 0), base + Vector2(14, 0), tip])
	draw_rect(Rect2(box.position + Vector2(7, 7), box.size), Color(INK, 0.5))
	draw_rect(box, Color.WHITE)
	draw_rect(box, INK, false, 5.0)
	draw_colored_polygon(tail, Color.WHITE)
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), INK, 5.0)
	draw_rect(Rect2(tail_x - 14.0, box.end.y - 6.0, 28.0, 8.0), Color.WHITE)  # hides the border under the tail
	var tag := Rect2(box.position + Vector2(18, -22), Vector2(font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 24.0, 30))
	draw_rect(tag, Color("#f1c40f"))
	draw_rect(tag, INK, false, 4.0)
	draw_string(font, tag.position + Vector2(12, 22), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_multiline_string(font, box.position + Vector2(20, 18.0 + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, width - 40.0, font_size, -1, INK)
	if done and fmod(_time, 0.8) < 0.5:
		draw_string(font, box.end - Vector2(64, 10), "click", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ec3750"))
