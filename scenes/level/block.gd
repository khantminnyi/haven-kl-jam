@tool
class_name Block
extends StaticBody2D
# one solid rectangle. kind chooses the bounce, danger and drawing.

enum Kind {
	STONE,  ## normal ground. barely bouncy.
	BRICK,  ## dead: soaks up nearly all your speed.
	BOUNCY,  ## springy: always throws you back harder than you came in.
	SPIKES,  ## kills you if you hit a spiky side fast.
	EXPLOSIVE,  ## blows up when touched or shot and launches you away.
	LAVA,  ## instant death.
	METAL,  ## ricochet plate: almost perfect bounce, sparks.
	STICKY,  ## goo: you stick to it, reload, and can shoot off again.
	GLASS,  ## solid until a bullet hits it, then it shatters.
}

# which sides of a SPIKES block have spikes (only those sides are dangerous).
@export_flags("Top", "Bottom", "Left", "Right") var spike_sides := 1

@export var kind := Kind.STONE:
	set(value):
		kind = value
		queue_redraw()
@export var size := Vector2(256, 64):
	set(value):
		size = value
		_rebuild()
# each level has its own ground colours so levels don't all look the same.
@export_enum("dirt", "grass", "planet", "sand", "snow", "stone") var theme := "stone":
	set(value):
		theme = value
		queue_redraw()

const INK := Color("#1b1b1b")
# per theme: ground fill, the strip along the top, and the colour of the pen marks.
const PALETTES := {
	"dirt": [Color("#6b4a36"), Color("#3f2c20"), Color("#52382a")],  # churned-up mud
	"grass": [Color("#7a5236"), Color("#5fae3c"), Color("#66442c")],  # soil with a grass top
	"snow": [Color("#efe3c8"), Color("#58b5b0"), Color("#d9cba8")],  # kitchen tiles
	"sand": [Color("#d9b36c"), Color("#b98b4a"), Color("#c49f5c")],
	"planet": [Color("#6a5a8a"), Color("#9a86c8"), Color("#57487a")],
	"stone": [Color("#74787f"), Color("#565a61"), Color("#63676e")],
}

static var _cache := {}

# bouncy blocks as pillows: soft and harmless even to the frailest character (grandma).
@export var soft := false
var exploded := false
var _frame := -1
var _seed := 0
func _ready() -> void:
	add_to_group("blocks")
	add_to_group("boil")
	_seed = hash(position)
	_rebuild()


func _boil() -> void:
	if Paint.on_screen(self, size.length() / 2.0):
		queue_redraw()


func bounciness() -> float:
	match kind:
		Kind.BRICK:
			return 0.15
		Kind.BOUNCY:
			return 1.12
		Kind.SPIKES:
			return 0.2
		Kind.METAL:
			return 0.95
	return 0.28


func is_spiky_side(normal: Vector2) -> bool:
	if kind != Kind.SPIKES:
		return false
	if normal.y < -0.7:
		return spike_sides & 1 != 0
	if normal.y > 0.7:
		return spike_sides & 2 != 0
	if normal.x < -0.7:
		return spike_sides & 4 != 0
	return spike_sides & 8 != 0


func impact_fx(point: Vector2, normal: Vector2, speed: float) -> void:
	if speed < 250.0:
		return
	Sfx.bounce(kind, speed)
	var colours := {Kind.METAL: Color("#fff3b0"), Kind.BOUNCY: Color("#ff8fc8"), Kind.SPIKES: Color("#ec3750"), Kind.STICKY: Color("#7bd36a")}
	var fill: Color = PALETTES.get(theme, PALETTES["stone"])[0]
	Block.burst(get_parent(), point, colours.get(kind, fill.lightened(0.3)), int(clampf(speed / 60.0, 6.0, 30.0)), speed * 0.45, normal, 55.0)
	if kind == Kind.METAL:
		flash(point, Color("#cfe8ff"), 1.2, 1.5, 0.15)


func explode() -> void:
	if exploded:
		return
	# mark it first so neighbouring tnt cannot recurse back into this same explosion.
	exploded = true
	$Collision.set_deferred("disabled", true)
	visible = false
	Sfx.play("explosion", 2.0)
	Block.burst(get_parent(), global_position, Color("#ff9a3c"), 48, 700.0)
	flash(global_position, Color("#ffb347"), 2.5, 6.0, 0.5)
	Block.blast(get_tree(), global_position, 170.0)  # tnt takes brick walls and other tnt with it


func crumble() -> void:
	if exploded:
		return
	# mark it first so neighbouring tnt cannot recurse back into this same explosion.
	exploded = true
	$Collision.set_deferred("disabled", true)
	visible = false
	Sfx.pick(["wooden_01", "wooden_02", "wooden_03", "slam_02"], 2.0)
	Block.burst(get_parent(), global_position, Color("#8d8f96"), 36, 520.0)
	Block.burst(get_parent(), global_position, Color("#5f6168"), 18, 380.0)


static func blast(tree: SceneTree, at: Vector2, reach: float) -> void:
	for node: Node in tree.get_nodes_in_group("blocks"):
		var block := node as Block
		if block == null or block.exploded or (block.kind != Kind.BRICK and block.kind != Kind.EXPLOSIVE):
			continue
		var rect := Rect2(block.global_position - block.size / 2.0, block.size)
		# test the closest point of the box, not its centre. explosions should reach the edge of a long wall.
		var nearest := Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y))
		if nearest.distance_to(at) <= reach:
			if block.kind == Kind.BRICK:
				block.crumble()
			else:
				block.explode()


func shatter() -> void:
	if exploded:
		return
	# mark it first so neighbouring tnt cannot recurse back into this same explosion.
	exploded = true
	$Collision.set_deferred("disabled", true)
	visible = false
	Sfx.pick(["glass_01", "glass_02", "glass_03"], 2.0)
	Block.burst(get_parent(), global_position, Color("#bfe9ff"), 40, 450.0)


func flash(at: Vector2, colour: Color, energy: float, reach: float, seconds: float) -> void:
	var light := PointLight2D.new()
	light.texture = Block.glow_texture()
	light.color = colour
	light.energy = energy
	light.texture_scale = reach
	light.global_position = at
	get_parent().add_child(light)
	var fade := light.create_tween().set_ignore_time_scale(true)
	fade.tween_property(light, "energy", 0.0, seconds)
	fade.tween_callback(light.queue_free)


static func burst(parent: Node, at: Vector2, colour: Color, amount: int, speed: float, direction := Vector2.UP, spread := 180.0) -> void:
	var bits := CPUParticles2D.new()
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = amount
	bits.lifetime = 0.8
	bits.direction = direction
	bits.spread = spread
	bits.initial_velocity_min = speed * 0.35
	bits.initial_velocity_max = speed
	bits.gravity = Vector2(0, 1300)
	bits.scale_amount_min = 4.0
	bits.scale_amount_max = 10.0
	bits.color = colour
	parent.add_child(bits)
	bits.global_position = at
	bits.emitting = true
	# cleanup uses real time so slow-mo does not leave particle nodes hanging around forever.
	bits.get_tree().create_timer(1.3, true, false, true).timeout.connect(bits.queue_free)


func _rebuild() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var collider := get_node_or_null("Collision") as CollisionShape2D
	if collider == null:
		collider = CollisionShape2D.new()
		collider.name = "Collision"
		add_child(collider)
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	if Engine.is_editor_hint() and owner != null:
		# let the editor pick the whole block through its collision rectangle.
		collider.owner = owner
		set_meta("_edit_group_", true)


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	var marks := mini(int(size.x * size.y / 7000.0), 60)
	match kind:
		Kind.STONE:
			var palette: Array = PALETTES.get(theme, PALETTES["stone"])
			draw_rect(r, palette[0])
			Paint.scribble(self, r.grow(-8.0), palette[2], marks, _seed)
			# a strip along the top (mud, grass, counter top...) with its own shaky edge.
			draw_rect(Rect2(r.position, Vector2(size.x, minf(14.0, size.y))), palette[1])
			Paint.line(self, r.position + Vector2(0, 14), Vector2(r.end.x, r.position.y + 14.0), palette[1].darkened(0.3), 3.0, _seed + 9)
		Kind.BRICK:
			draw_rect(r, Color("#8d8f96"))
			var y := r.position.y + 28.0
			var row := 0
			while y < r.end.y - 6.0 and row < 14:
				Paint.line(self, Vector2(r.position.x, y), Vector2(r.end.x, y), Color("#5f6168"), 3.0, _seed + row)
				y += 28.0
				row += 1
		Kind.BOUNCY when soft:
			_draw_pillow(r)
		Kind.BOUNCY:
			draw_rect(r, Color("#ff8fc8"))
			# zig-zag springs doodled along the top.
			var zig := PackedVector2Array()
			var x := r.position.x
			var up := true
			while x <= r.end.x:
				zig.append(Vector2(x, r.position.y - (18.0 if up else 4.0)) + Paint.jitter(_seed + int(x) + Paint.frame(), 2.0))
				x += 16.0
				up = not up
			if zig.size() > 1:
				draw_polyline(zig, INK, 4.0)
		Kind.SPIKES:
			draw_rect(r, Color("#7a7078"))
			_draw_spikes(r)
		Kind.EXPLOSIVE:
			draw_rect(r, Color("#e8742c"))
			Paint.line(self, r.position, r.end, Color("#b3501a"), 4.0, _seed + 5)
			Paint.line(self, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color("#b3501a"), 4.0, _seed + 6)
			draw_string(ThemeDB.fallback_font, Vector2(-20, 8) + Paint.jitter(_seed + Paint.frame(), 1.5), "tnt", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
		Kind.LAVA:
			draw_rect(r, Color("#e8502a"))
			# a yellow wave that sloshes along the top.
			var wave := PackedVector2Array()
			var wx := r.position.x
			while wx <= r.end.x:
				wave.append(Vector2(wx, r.position.y + 10.0 + sin(wx * 0.08 + Paint.frame() * 0.9) * 5.0))
				wx += 12.0
			if wave.size() > 1:
				draw_polyline(wave, Color("#ffd23f"), 5.0)
		Kind.METAL:
			draw_rect(r, Color("#9fb4c8"))
			var shine := r.position.y + 18.0
			var n := 0
			while shine < r.end.y - 10.0 and n < 12:
				Paint.line(self, Vector2(r.position.x + 8.0, shine + 12.0), Vector2(r.end.x - 8.0, shine), Color("#e6f1fa"), 3.0, _seed + n, 1.5)
				shine += 48.0
				n += 1
		Kind.STICKY:
			draw_rect(r, Color("#7bd36a"))
			Paint.scribble(self, r.grow(-6.0), Color("#4fa843"), maxi(marks, 4), _seed)
			# drips hanging off the bottom.
			var dx := r.position.x + 12.0
			while dx < r.end.x - 6.0:
				draw_circle(Vector2(dx, r.end.y + 4.0 + float(hash(_seed + int(dx)) % 8)), 6.0, Color("#7bd36a"))
				dx += 26.0
		Kind.GLASS:
			draw_rect(r, Color(0.75, 0.92, 1.0, 0.5))
			var glint := r.position.y + 14.0
			while glint < r.end.y - 20.0:
				Paint.line(self, Vector2(r.position.x + 8.0, glint + 18.0), Vector2(r.end.x - 8.0, glint), Color(1, 1, 1, 0.9), 3.0, _seed, 1.0)
				glint += 64.0
	Paint.rect(self, r, INK, 4.0, _seed)


func _draw_spikes(r: Rect2) -> void:
	# each side: flag, start corner, direction along the edge, direction the spikes point, length.
	var sides := [
		[1, r.position, Vector2.RIGHT, Vector2.UP, size.x],
		[2, Vector2(r.position.x, r.end.y), Vector2.RIGHT, Vector2.DOWN, size.x],
		[4, r.position, Vector2.DOWN, Vector2.LEFT, size.y],
		[8, Vector2(r.end.x, r.position.y), Vector2.DOWN, Vector2.RIGHT, size.y],
	]
	for side: Array in sides:
		if spike_sides & int(side[0]) == 0:
			continue
		var count := int(float(side[4]) / 32.0)
		for i in range(count):
			var a: Vector2 = side[1] + side[2] * (i * 32.0)
			var b: Vector2 = a + side[2] * 32.0
			var tip: Vector2 = (a + b) / 2.0 + side[3] * 26.0 + Paint.jitter(_seed + i * 3 + int(side[0]) * 50 + Paint.frame(), 2.0)
			draw_colored_polygon(PackedVector2Array([a, tip, b]), Color("#e9e4dc"))
			draw_polyline(PackedVector2Array([a, tip, b]), INK, 3.0)


func _draw_pillow(r: Rect2) -> void:
	draw_rect(r, Color("#f6e3d0"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 12.0)), Color("#ffb3c9"))
	var x := r.position.x + 32.0
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y + 12.0), Vector2(x, r.end.y), Color("#e7c3a6"), 3.0)
		x += 64.0
	var tuft := r.position.x + 32.0
	while tuft < r.end.x + 1.0:
		draw_circle(Vector2(tuft, r.position.y + r.size.y / 2.0 + 6.0), 6.0, Color("#c0466a"))
		draw_circle(Vector2(tuft, r.position.y + r.size.y / 2.0 + 6.0), 6.0, INK, false, 2.0)
		tuft += 64.0
	for i in range(int(r.size.x / 22.0)):  # stitched edge
		draw_line(Vector2(r.position.x + 6.0 + i * 22.0, r.position.y + 5.0), Vector2(r.position.x + 15.0 + i * 22.0, r.position.y + 5.0), Color("#c0466a"), 2.0)


static func glow_texture() -> Texture2D:
	if not _cache.has("glow"):
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		_cache["glow"] = tex
	return _cache["glow"]
