@tool
class_name Sign
extends Node2D
# level text drawn directly into the world.

@export var text := "note":
	set(value):
		text = value
		queue_redraw()


func _ready() -> void:
	z_index = 5


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, 320.0, 28)
	draw_set_transform(Vector2.ZERO, -0.05, Vector2.ONE)
	var at := Vector2(-160.0, -text_size.y / 2.0 + 20.0)
	draw_multiline_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 320.0, 28, -1, 8, Color("#1b1b1b"))
	draw_multiline_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 320.0, 28, -1, Color("#f2ead3"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
