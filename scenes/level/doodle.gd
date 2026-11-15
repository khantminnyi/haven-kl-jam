@tool
class_name Doodle
extends Node2D
# background junk drawn from lines and shapes. no collision.

const INK := Color("#1b1b1b")

@export var theme := "dirt":
	set(value):
		theme = value
		queue_redraw()
@export var pick := 0:
	set(value):
		pick = value
		queue_redraw()

var _frame := -1
func _ready() -> void:
	z_index = -1
	add_to_group("boil")


func _boil() -> void:
	if Paint.on_screen(self, 120.0):
		queue_redraw()


func _draw() -> void:
	var seed_value := pick * 17
	match theme:
		"dirt":
			match pick % 5:
				0:  # sandbags
					for bag: Vector2 in [Vector2(-22, 22), Vector2(22, 22), Vector2(0, 4)]:
						draw_rect(Rect2(bag - Vector2(22, 10), Vector2(44, 20)), Color("#b89b6a"))
						Paint.rect(self, Rect2(bag - Vector2(22, 10), Vector2(44, 20)), INK, 3.0, seed_value + int(bag.x))
				1:  # barbed wire
					for post_x in [-26.0, 26.0]:
						Paint.line(self, Vector2(post_x, 32), Vector2(post_x, -14), INK, 4.0, seed_value)
					var wire := PackedVector2Array()
					for i in range(17):
						wire.append(Vector2(-30.0 + i * 3.75, -4.0 + sin(i * 1.6) * 9.0) + Paint.jitter(seed_value + i + Paint.frame(), 1.5))
					draw_polyline(wire, INK, 2.5)
				2:  # a grave: cross with a helmet on it
					Paint.line(self, Vector2(0, 32), Vector2(0, -24), Color("#5a4632"), 6.0, seed_value)
					Paint.line(self, Vector2(-16, -6), Vector2(16, -6), Color("#5a4632"), 6.0, seed_value + 1)
					draw_circle(Vector2(0, -28), 13.0, INK)
					draw_circle(Vector2(0, -28), 10.0, Color("#4d6a30"))
				3:  # smoking crater
					draw_arc(Vector2(0, 30), 26.0, PI, TAU, 12, INK, 4.0)
					for i in range(4):
						var rise := fmod(Paint.frame() * 5.0 + i * 22.0, 90.0)
						draw_circle(Vector2(sin(i * 2.0 + rise * 0.05) * 10.0, 14.0 - rise), 8.0 + rise * 0.12, Color(0.3, 0.3, 0.32, 0.5 * (1.0 - rise / 90.0)))
				4:  # tank trap
					Paint.line(self, Vector2(-26, 32), Vector2(26, -20), INK, 7.0, seed_value)
					Paint.line(self, Vector2(26, 32), Vector2(-26, -20), INK, 7.0, seed_value + 1)
		"grass":
			match pick % 4:
				0:  # flower
					Paint.line(self, Vector2(0, 32), Vector2(0, -4), Color("#3f8a2e"), 4.0, seed_value)
					for i in range(5):
						draw_circle(Vector2(0, -10) + Vector2.from_angle(i * TAU / 5.0) * 9.0, 7.0, Color("#ff8fc8"))
					draw_circle(Vector2(0, -10), 6.0, Color("#f1c40f"))
				1:  # bush
					for blob: Vector2 in [Vector2(-18, 18), Vector2(16, 16), Vector2(0, 2)]:
						draw_circle(blob, 20.0, INK)
						draw_circle(blob, 17.0, Color("#4f9c38"))
				2:  # mushroom
					draw_rect(Rect2(-6, 8, 12, 24), Color("#efe3c8"))
					draw_circle(Vector2(0, 6), 20.0, INK)
					draw_circle(Vector2(0, 6), 17.0, Color("#ec3750"))
					draw_circle(Vector2(-7, 0), 4.0, Color.WHITE)
					draw_circle(Vector2(8, 6), 3.0, Color.WHITE)
				3:  # picket fence
					for i in range(4):
						var post := Rect2(-30.0 + i * 16.0, -6, 10, 38)
						draw_rect(post, Color("#efe3c8"))
						Paint.rect(self, post, INK, 3.0, seed_value + i)
		_:
			match pick % 4:
				0:  # milk carton
					draw_rect(Rect2(-12, -6, 24, 38), Color.WHITE)
					Paint.rect(self, Rect2(-12, -6, 24, 38), INK, 3.0, seed_value)
					draw_colored_polygon(PackedVector2Array([Vector2(-12, -6), Vector2(0, -20), Vector2(12, -6)]), Color("#338eda"))
				1:  # stack of plates
					for i in range(5):
						Paint.line(self, Vector2(-22, 30.0 - i * 6.0), Vector2(22, 30.0 - i * 6.0), INK, 4.0, seed_value + i, 1.5)
				2:  # cheese
					draw_colored_polygon(PackedVector2Array([Vector2(-26, 32), Vector2(26, 32), Vector2(26, 0)]), Color("#f1c40f"))
					draw_polyline(PackedVector2Array([Vector2(-26, 32), Vector2(26, 32), Vector2(26, 0), Vector2(-26, 32)]), INK, 3.0)
					draw_circle(Vector2(12, 22), 4.0, Color("#c99a0a"))
				3:  # bottle
					draw_rect(Rect2(-8, 0, 16, 32), Color("#58b5b0"))
					draw_rect(Rect2(-3, -16, 6, 16), Color("#58b5b0"))
					Paint.rect(self, Rect2(-8, 0, 16, 32), INK, 3.0, seed_value)
