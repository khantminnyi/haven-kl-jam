class_name WinCard
extends Control
# win image or sprite sheet, with a quick scale-in animation.

const FPS := 12.5

var _texture: Texture2D
var _frames := Vector2i.ONE
var _count := 1
var _width := 700.0
var _centre_y := 230.0
var _age := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_card(path: String, frames: Vector2i, count: int, width: float, centre_y: float) -> void:
	_texture = load(path) as Texture2D
	_frames = frames
	_count = count
	_width = width
	_centre_y = centre_y
	_age = 0.0


func _process(delta: float) -> void:
	if _age >= 0.0:
		_age += delta / maxf(Engine.time_scale, 0.001)
		queue_redraw()


func _draw() -> void:
	if _age < 0.0 or _texture == null:
		return
	var frame_size := Vector2(_texture.get_width() / float(_frames.x), _texture.get_height() / float(_frames.y))
	var index := mini(int(_age * FPS), _count - 1)
	var source := Rect2(Vector2(index % _frames.x, index / _frames.x) * frame_size, frame_size)
	var size := Vector2(_width, _width * frame_size.y / frame_size.x)
	# slam in from big, with a little overshoot and a tilt that settles.
	var t := clampf(_age / 0.35, 0.0, 1.0)
	var pop := 1.0 + (1.0 - t) * 1.8 + sin(t * PI) * 0.08
	draw_set_transform(Vector2(get_viewport_rect().size.x / 2.0, _centre_y), -0.08 * (1.0 - t), Vector2.ONE * pop)
	draw_texture_rect_region(_texture, Rect2(-size / 2.0, size), source, Color(1, 1, 1, t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
