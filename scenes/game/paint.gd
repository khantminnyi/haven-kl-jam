class_name Paint
# ps. this is the woobly effect on blocks (and basically everything else).
# chop lines into bits, nudge the points, change the seed every 170ms. ms paint goes brrr.

const INK := Color("#1b1b1b")


static func frame() -> int:
	return int(Time.get_ticks_msec() / 170)


static func on_screen(item: Node2D, reach: float) -> bool:
	var viewport := item.get_viewport()
	if viewport == null:
		return true
	var zoom := item.get_canvas_transform().get_scale().x
	var at := item.get_global_transform_with_canvas().origin
	var size := viewport.get_visible_rect().size
	var margin := reach * zoom + 40.0
	return at.x > -margin and at.y > -margin and at.x < size.x + margin and at.y < size.y + margin


static func jitter(seed_value: int, amount: float) -> Vector2:
	var h := hash(seed_value)
	return Vector2(float(h % 1000) / 500.0 - 1.0, float((h / 1000) % 1000) / 500.0 - 1.0) * amount


static func line(canvas: CanvasItem, a: Vector2, b: Vector2, colour := INK, width := 4.0, seed_value := 0, wobble := 2.5) -> void:
	# about one point per 28px. more points = busier scribble, not better collision.
	var steps := maxi(int(a.distance_to(b) / 28.0), 1)
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var fraction := float(i) / steps
		var straight_point := a.lerp(b, fraction)
		var point_seed := seed_value * 31 + i * 7 + frame() * 13
		var offset := jitter(point_seed, wobble)
		points.append(straight_point + offset)
	canvas.draw_polyline(points, colour, width)


static func rect(canvas: CanvasItem, r: Rect2, colour := INK, width := 4.0, seed_value := 0, wobble := 2.5) -> void:
	var over := Vector2(3, 0)
	var down := Vector2(0, 3)
	line(canvas, r.position - over, Vector2(r.end.x, r.position.y) + over, colour, width, seed_value + 1, wobble)
	line(canvas, Vector2(r.end.x, r.position.y) - down, r.end + down, colour, width, seed_value + 2, wobble)
	line(canvas, r.end + over, Vector2(r.position.x, r.end.y) - over, colour, width, seed_value + 3, wobble)
	line(canvas, Vector2(r.position.x, r.end.y) + down, r.position - down, colour, width, seed_value + 4, wobble)


static func scribble(canvas: CanvasItem, r: Rect2, colour: Color, count: int, seed_value: int) -> void:
	for i in range(count):
		var h := hash(seed_value * 97 + i * 13)
		var at := r.position + Vector2(float(h % 997) / 997.0 * r.size.x, float((h / 997) % 991) / 991.0 * r.size.y)
		var stroke := Vector2.from_angle(float(h % 628) / 100.0) * (6.0 + float(h % 9))
		canvas.draw_line(at, at + stroke, colour, 3.0)
