class_name Ghost
extends Node2D
# recorded positions played against the run timer. no collision, just a ghost.

const INK := Color("#1b1b1b")
const BODY := Color(0.55, 0.8, 1.0, 0.55)

var time := 0.0

var _times: Array = []
var _points: Array = []  # flat: x0, y0, x1, y1...
var _velocity := Vector2.RIGHT


func setup(data: Dictionary) -> void:
	_times = data.get("t", [])
	_points = data.get("p", [])
	if _times.size() > 0:
		position = Vector2(_points[0], _points[1])
	z_index = -1


func _process(_delta: float) -> void:
	if _times.is_empty():
		return
	# find the two recorded frames either side of `time` and blend between them.
	var last := _times.size() - 1
	var index := 0
	if time >= float(_times[last]):
		index = last
	else:
		# binary search finds the first sample at/after this time. interpolate from the previous sample.
		index = _times.bsearch(time)
	var here := _point(index)
	var before := _point(maxi(index - 1, 0))
	if index > 0 and index <= last:
		var span := float(_times[index]) - float(_times[index - 1])
		var blend := clampf((time - float(_times[index - 1])) / maxf(span, 0.0001), 0.0, 1.0)
		here = before.lerp(here, blend)
		if span > 0.0:
			_velocity = (_point(index) - before) / span
	position = here
	# fade out once the run is over.
	if time < float(_times[last]) + 0.5:
		modulate.a = 1.0
	else:
		modulate.a = 0.0
	queue_redraw()


func _point(index: int) -> Vector2:
	return Vector2(_points[index * 2], _points[index * 2 + 1])


func _draw() -> void:
	# limbs trail behind the direction of travel and flap with the clock.
	var back := (-_velocity).angle() if _velocity.length() > 80.0 else PI / 2.0
	var wobble := sin(time * 14.0) * 0.5
	for limb: Array in [[Vector2(-6, 4), back - 0.5 + wobble], [Vector2(6, 4), back + 0.5 - wobble],
			[Vector2(-5, 14), back - 0.3 - wobble], [Vector2(5, 14), back + 0.3 + wobble]]:
		var start: Vector2 = limb[0]
		draw_line(start, start + Vector2.from_angle(limb[1]) * 28.0, BODY, 9.0)
	draw_circle(Vector2(0, 6), 12.0, BODY)
	draw_circle(Vector2(0, -16), 20.0, BODY)  # comically big head
	draw_arc(Vector2(0, -16), 20.0, 0.0, TAU, 20, Color(INK, 0.4), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-14, -44), "dev", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
