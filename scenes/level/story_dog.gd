class_name StoryDog
extends Node2D
# the slipper-stealing dog in the intro. timed movement, no pathfinding.

const DOG := "res://art/sprites/grandma/target.png"
const SLIPPER := "res://art/sprites/grandma/slipper.png"
const HEIGHT := 84.0

var _texture: Texture2D
var _slipper: Texture2D
var _time := 0.0
var _floor_y := 0.0  # y of the ground, in this node's parent space
var _start_x := 0.0
var _slipper_x := 0.0
var _carrying := false


func start(feet: Vector2) -> void:
	_texture = load(DOG)
	_slipper = load(SLIPPER)
	_floor_y = feet.y
	_slipper_x = feet.x - 26.0
	_start_x = feet.x + 600.0
	position = Vector2(_start_x, _floor_y)
	z_index = 5


func _process(delta: float) -> void:
	_time += delta / maxf(Engine.time_scale, 0.001)
	var run := _run_progress()
	# x: in (0 to 1.5 s), grab (to 2.0 s), then away and stop (to 3.4 s).
	var grab_x := _slipper_x + 50.0
	var stop_x := _slipper_x + 330.0
	if _time < 1.5:
		position.x = lerpf(_start_x, grab_x, smoothstep(0.0, 1.0, _time / 1.5))
	elif _time < 2.0:
		position.x = grab_x
		_carrying = true
	else:
		position.x = lerpf(grab_x, stop_x, smoothstep(0.0, 1.0, (_time - 2.0) / 1.4))
	position.y = _floor_y - absf(sin(_time * 16.0)) * 12.0 * run
	queue_redraw()


func _run_progress() -> float:
	if (_time >= 1.5 and _time < 2.0) or _time > 3.4:
		return 0.0
	else:
		return 1.0


func _draw() -> void:
	if _texture == null:
		return
	# the picture faces left: run left towards her, then flip to run away to the right.
	var running_away := _time >= 2.0 and _time < 3.4
	var smug := _time >= 3.4
	var flip := -1.0 if running_away else 1.0
	var wide := HEIGHT * _texture.get_width() / _texture.get_height()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	draw_texture_rect(_texture, Rect2(-wide / 2.0, -HEIGHT, wide, HEIGHT), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the slipper: on the ground until the dog grabs it, then in his mouth.
	var slipper_at := Vector2(-wide * 0.45 * flip, -HEIGHT * 0.45) if _carrying or smug else Vector2(_slipper_x - position.x, -4.0 + (_floor_y - position.y))
	var slipper_size := Vector2(46.0, 46.0 * _slipper.get_height() / _slipper.get_width())
	draw_texture_rect(_slipper, Rect2(slipper_at - slipper_size / 2.0, slipper_size), false)
