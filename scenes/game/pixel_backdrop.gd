class_name PixelBackdrop
# three tiny background images, enlarged and scrolled at different speeds.

const W := 480
const H := 270
const SCALE := 5.0


static func build(level: Node2D, tint: Color, ruins: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.scene_file_path)  # same level, same scenery every time
	var sky_top := tint.darkened(0.6)
	var sky_bottom := tint.lightened(0.1)
	# anything the layers don't cover shows this colour instead of the default cream.
	RenderingServer.set_default_clear_color(sky_top)
	var images: Array[Image] = [
		_sky(sky_top, sky_bottom, rng),
		_hills(tint.darkened(0.3), 0.55, 34.0, rng, false, false),
		_hills(tint.darkened(0.55), 0.7, 22.0, rng, ruins, not ruins),
	]
	var speeds := [0.03, 0.12, 0.28]
	for i in range(images.size()):
		var layer := Parallax2D.new()
		layer.scroll_scale = Vector2(speeds[i], speeds[i] * 0.3)
		layer.repeat_size = Vector2(W * SCALE, 0.0)
		layer.repeat_times = 5
		layer.z_index = -100 + i
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(images[i])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.scale = Vector2(SCALE, SCALE)
		sprite.position = Vector2(-400.0, -250.0)
		layer.add_child(sprite)
		level.add_child(layer)
		level.move_child(layer, i)


static func _sky(top: Color, bottom: Color, rng: RandomNumberGenerator) -> Image:
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var bands := 10
	for y in range(H):
		# step the gradient into flat bands, the pixel-art way.
		var band := floorf(float(y) / H * bands) / (bands - 1)
		image.fill_rect(Rect2i(0, y, W, 1), top.lerp(bottom, band))
	for i in range(90):
		image.set_pixel(rng.randi_range(0, W - 1), rng.randi_range(0, int(H * 0.55)), Color(1, 1, 0.9, rng.randf_range(0.4, 1.0)))
	# moon with a bite out of it.
	var moon := Vector2i(rng.randi_range(90, W - 90), 52)
	for y in range(-16, 17):
		for x in range(-16, 17):
			if x * x + y * y <= 256 and (x - 7) * (x - 7) + (y + 5) * (y + 5) > 150:
				image.set_pixel(moon.x + x, moon.y + y, Color(1.0, 0.96, 0.8))
	return image


static func _hills(colour: Color, base: float, height: float, rng: RandomNumberGenerator, ruins: bool, trees: bool) -> Image:
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var phase_a := rng.randf() * TAU
	var phase_b := rng.randf() * TAU
	var edge := colour.lightened(0.18)
	for x in range(W):
		# two sine waves whose periods divide the width, so the layer tiles without a seam.
		var wave := sin(x * TAU * 2.0 / W + phase_a) * 0.6 + sin(x * TAU * 5.0 / W + phase_b) * 0.4
		var y := int(H * base - wave * height)
		y -= y % 2
		image.fill_rect(Rect2i(x, y, 1, H - y), colour)
		image.fill_rect(Rect2i(x, y, 1, 2), edge)
	for i in range(9):
		var x := rng.randi_range(8, W - 30)
		var ground := int(H * base) + 6
		if ruins:
			# a broken building: a block with window holes and a jagged top.
			var wide := rng.randi_range(12, 22)
			var tall := rng.randi_range(24, 56)
			image.fill_rect(Rect2i(x, ground - tall, wide, tall + 30), colour)
			image.fill_rect(Rect2i(x + rng.randi_range(0, wide / 2), ground - tall - 6, wide / 3, 6), colour)
			for row in range(ground - tall + 4, ground - 6, 8):
				for column in range(x + 3, x + wide - 3, 6):
					if rng.randf() < 0.6:
						image.fill_rect(Rect2i(column, row, 3, 4), Color(1.0, 0.75, 0.35, 0.9) if rng.randf() < 0.2 else Color(0, 0, 0, 0))
		elif trees:
			# a lollipop tree.
			var tall := rng.randi_range(18, 34)
			image.fill_rect(Rect2i(x + 5, ground - tall, 3, tall + 30), colour)
			for dy in range(-9, 10):
				for dx in range(-9, 10):
					if dx * dx + dy * dy <= 81:
						image.set_pixel(clampi(x + 6 + dx, 0, W - 1), clampi(ground - tall + dy, 0, H - 1), colour if dy > -3 else edge)
	return image
