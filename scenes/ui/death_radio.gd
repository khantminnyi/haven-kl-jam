class_name DeathRadio
extends Control
# delayed sarge radio chatter after death.

const INK := Color("#1b1b1b")
const GREEN := Color("#6cff8a")

var _radio: PackedStringArray = []
var _wait := -1.0
var _age := 0.0
var _shown := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_after(seconds: float, radio: PackedStringArray) -> void:
	if radio.is_empty():
		return
	_wait = seconds
	_radio = radio


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _wait >= 0.0:
		_wait -= real_delta
		if _wait <= 0.0:
			_wait = -1.0
			_shown = true
			visible = true
	if _shown:
		_age += real_delta
		queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	var font := ThemeDB.fallback_font
	var count := mini(int(_age / 1.0) + 1, _radio.size())
	var box := Rect2(30.0, 20.0, 430.0, 36.0 + count * 36.0)
	draw_rect(Rect2(box.position + Vector2(6, 6), box.size), INK)
	draw_rect(box, Color("#10231a"))
	draw_rect(box, GREEN, false, 4.0)
	for i in range(count):
		draw_string(font, box.position + Vector2(16, 40 + i * 36), _radio[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GREEN)
