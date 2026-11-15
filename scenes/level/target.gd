@tool
class_name Target
extends Area2D
# level finish marker. also the base drawing/trigger for enemies.

enum Style { DARTBOARD, ENEMY_SOLDIER, FRIDGE }

const INK := Color("#1b1b1b")

@export var style := Style.DARTBOARD:
	set(value):
		style = value
		queue_redraw()
@export var radius := 60.0
# optional picture (the dog...). if set, it is drawn instead of the Style.
@export var picture: Texture2D
@export var picture_height := 110.0

# the red toy soldier (enemies and the boss), cut from the team's sprite sheet.
const ENEMY_TEXTURE := "res://art/sprites/enemy/stand.png"

# enemies face the player: Enemy flips this when the player is on its other side.
var facing_left := true
var _enemy_tex: Texture2D


func _ready() -> void:
	if style == Style.ENEMY_SOLDIER:
		_enemy_tex = load(ENEMY_TEXTURE)
	if Engine.is_editor_hint():
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)


func explode() -> void:
	visible = false
	Sfx.play("explosion", 4.0, 1.1)
	for colour: Color in [Color("#ec3750"), Color("#f1c40f"), Color("#f2ead3"), Color("#1b1b1b")]:
		Block.burst(get_parent(), global_position, colour, 26, 900.0)


func _draw() -> void:
	if picture:
		var scale := picture_height / picture.get_height()
		var size := Vector2(picture.get_width(), picture.get_height()) * scale
		draw_texture_rect(picture, Rect2(-size / 2.0, size), false)
		return
	match style:
		Style.ENEMY_SOLDIER:
			if _enemy_tex == null:
				return
			# feet on the floor: the tile centre is 32 px above it, and the sprite is bigger than the circle.
			var h := radius * 2.7
			var w := h * _enemy_tex.get_width() / _enemy_tex.get_height()
			draw_set_transform(Vector2(0.0, 32.0 - h / 2.0), 0.0, Vector2(-1.0 if facing_left else 1.0, 1.0))
			draw_texture_rect(_enemy_tex, Rect2(-w / 2.0, -h / 2.0, w, h), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Style.FRIDGE:
			var body := Rect2(-34, -70, 68, 140)
			draw_rect(body.grow(3), INK)
			draw_rect(body, Color("#e8eef2"))
			draw_line(Vector2(-34, -20), Vector2(34, -20), INK, 3.0)
			draw_rect(Rect2(20, -58, 6, 28), INK)
			draw_rect(Rect2(20, -8, 6, 40), INK)
			draw_string(ThemeDB.fallback_font, Vector2(-24, 20), "MILK", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#338eda"))
		_:
			draw_line(Vector2(0.0, radius * 0.6), Vector2(0.0, radius + 20.0), INK, 8.0)
			for ring: Array in [[1.0, INK], [0.94, Color("#ec3750")], [0.68, Color.WHITE], [0.42, Color("#ec3750")], [0.16, Color.WHITE]]:
				draw_circle(Vector2.ZERO, radius * float(ring[0]), ring[1])
