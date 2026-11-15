@tool
class_name Pickup
extends Area2D
# crate = smash counter. power pickup = a few seconds of unlimited shots.

enum Kind { SMASH, POWER }

const INK := Color("#1b1b1b")

@export var kind := Kind.SMASH:
	set(value):
		kind = value
		queue_redraw()
@export var icon := "bolt":
	set(value):
		icon = value
		queue_redraw()
var _frame := -1
var _taken := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	add_to_group("boil")


func _boil() -> void:
	if Paint.on_screen(self, 60.0):
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	var shooter := body as Shooter
	if shooter == null or _taken or not shooter.alive:
		return
	_taken = true
	if kind == Kind.SMASH:
		shooter.smashed += 1
		# each crate in a row sounds a bit higher: smash lots, quickly.
		Sfx.play("wooden_02", 0.0, 0.9 + minf(shooter.smashed * 0.07, 1.0))
		Block.burst(get_parent(), global_position, Color("#b8864f"), 16, 500.0, shooter.velocity.normalized(), 70.0)
	else:
		shooter.start_power(4.0)
		Sfx.play("bell_02", 0.0, 1.3)
		Block.burst(get_parent(), global_position, Color("#f1c40f"), 20, 400.0)
	queue_free()


func _draw() -> void:
	if kind == Kind.SMASH:
		var box := Rect2(-20, -20, 40, 40)
		draw_rect(box, Color("#b8864f"))
		Paint.line(self, box.position, box.end, Color("#7a5530"), 3.0, 3)
		Paint.line(self, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), Color("#7a5530"), 3.0, 4)
		Paint.rect(self, box, INK, 3.0, 5)
	else:
		var bob := Vector2(0, sin(Time.get_ticks_msec() / 250.0) * 5.0)
		match icon:
			"ammo":
				_draw_ammo(bob)
			"tea":
				_draw_tea(bob)
			"cheese":
				_draw_cheese(bob)
			_:
				_draw_bolt(bob)


func _draw_ammo(bob: Vector2) -> void:
	var box := Rect2(Vector2(-22, -10) + bob, Vector2(44, 28))
	draw_rect(box.grow(3.0), INK)
	draw_rect(box, Color("#5b6b3a"))
	for i in range(4):  # brass bullets poking out of the top
		var x := box.position.x + 7.0 + i * 10.0
		draw_rect(Rect2(x - 1.0, box.position.y - 14.0, 8.0, 15.0), INK)
		draw_rect(Rect2(x, box.position.y - 12.0, 6.0, 13.0), Color("#e0b341"))
	draw_string(ThemeDB.fallback_font, box.position + Vector2(6, 22), "AMMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f2ead3"))


func _draw_tea(bob: Vector2) -> void:
	var cup := Rect2(Vector2(-16, -8) + bob, Vector2(30, 26))
	draw_rect(cup.grow(3.0), INK)
	draw_rect(cup, Color.WHITE)
	draw_rect(Rect2(cup.position + Vector2(0, 8), Vector2(30, 5)), Color("#ec3750"))
	draw_arc(Vector2(cup.end.x + 2.0, cup.position.y + 12.0), 8.0, -PI / 2.0, PI / 2.0, 10, INK, 5.0)
	for i in range(2):  # steam
		var x := cup.position.x + 8.0 + i * 12.0
		Paint.line(self, Vector2(x, cup.position.y - 4.0), Vector2(x + 3.0, cup.position.y - 20.0), Color(1, 1, 1, 0.9), 3.0, i + 7, 3.0)


func _draw_cheese(bob: Vector2) -> void:
	var wedge := PackedVector2Array([Vector2(-24, 14), Vector2(24, 14), Vector2(24, -6), Vector2(-24, 4)])
	for i in range(wedge.size()):
		wedge[i] += bob
	draw_colored_polygon(wedge, Color("#f2c53d"))
	var outline := wedge.duplicate()
	outline.append(wedge[0])
	draw_polyline(outline, INK, 3.0)
	for hole: Vector3 in [Vector3(-10, 6, 4), Vector3(8, 4, 5), Vector3(14, 10, 3)]:
		draw_circle(Vector2(hole.x, hole.y) + bob, hole.z, Color("#d99a1c"))


func _draw_bolt(bob: Vector2) -> void:
	if true:
		var bolt := PackedVector2Array([Vector2(6, -26), Vector2(-14, 4), Vector2(-2, 4), Vector2(-8, 26), Vector2(14, -6), Vector2(2, -6)])
		for i in range(bolt.size()):
			bolt[i] += bob
		draw_colored_polygon(bolt, Color("#f1c40f"))
		bolt.append(bolt[0])
		draw_polyline(bolt, INK, 3.0)
