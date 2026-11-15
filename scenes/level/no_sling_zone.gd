@tool
class_name NoSlingZone
extends Area2D
# striped area that counts entries/exits to block shooting or the jet.

@export var label := "no shooting"
# true: no slinging inside. false: slinging works but the jet (holding fart) is switched off.
@export var bans_shots := true
@export var size := Vector2(256, 256):
	set(value):
		size = value
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("boil")


func _on_body_entered(body: Node2D) -> void:
	if not body is Shooter:
		return
	# counts instead of a yes/no flag because zones can overlap.
	if bans_shots:
		body.no_sling_zones += 1
	else:
		body.no_jet_zones += 1


func _on_body_exited(body: Node2D) -> void:
	if not body is Shooter:
		return
	if bans_shots:
		body.no_sling_zones -= 1
	else:
		body.no_jet_zones -= 1


func _boil() -> void:
	if Paint.on_screen(self, size.length() / 2.0):
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, Color(0.93, 0.22, 0.31, 0.12))
	var step := 36.0
	var shift := fmod(Time.get_ticks_msec() / 1000.0 * 20.0, step)
	var x := rect.position.x - rect.size.y + shift
	while x < rect.end.x:
		# clip each stripe to the rectangle so it doesn't spill out.
		var a := Vector2(x, rect.end.y)
		var b := Vector2(x + rect.size.y, rect.position.y)
		if a.x < rect.position.x:
			a = Vector2(rect.position.x, rect.end.y - (rect.position.x - x))
		if b.x > rect.end.x:
			b = Vector2(rect.end.x, rect.position.y + (b.x - rect.end.x))
		draw_line(a, b, Color(0.93, 0.22, 0.31, 0.35), 6.0)
		x += step
	draw_rect(rect, Color(0.93, 0.22, 0.31, 0.7), false, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(8, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.85, 0.8))
