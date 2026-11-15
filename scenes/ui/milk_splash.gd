class_name MilkSplash
extends Control
# the milk ending: growing circles and drips until the screen fills.

const MILK := Color("#fdfdfb")
const RIM := Color("#d9e4f2")
const SPLASH_SECONDS := 2.6  ## how long the splashing lasts before the final fill
const HOLD_SECONDS := 0.7  ## how long the screen stays white afterwards

var _splashes: Array[Dictionary] = []
var _age := -1.0
var _spawned := 0
var _on_done := Callable()
var _finished := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func start(from: Vector2, on_done: Callable) -> void:
	_age = 0.0
	_on_done = on_done
	_spawn(from, 70.0)  # the first squirt comes from the character
	Sfx.play("splash_01", 2.0, 0.9)


func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta / maxf(Engine.time_scale, 0.001)
	# the splash rate speeds up so it feels like a flood.
	var want := int(pow(_age / SPLASH_SECONDS, 1.6) * 46.0)
	while _spawned < want and _age < SPLASH_SECONDS:
		var size := get_viewport_rect().size
		_spawn(Vector2(randf() * size.x, randf() * size.y), randf_range(90.0, 220.0))
		if _spawned % 5 == 0:
			Sfx.pick(["splash_01", "plop_01"], -4.0, randf_range(0.8, 1.3))
	if _age > SPLASH_SECONDS + HOLD_SECONDS and not _finished:
		_finished = true
		_on_done.call()
	queue_redraw()


func _spawn(at: Vector2, radius: float) -> void:
	_spawned += 1
	var droplets: Array[Vector2] = []
	for i in range(7):
		droplets.append(Vector2.from_angle(randf() * TAU) * randf_range(0.9, 1.9))
	_splashes.append({"at": at, "radius": radius, "born": _age, "droplets": droplets, "drip": randf_range(80.0, 260.0)})


func _draw() -> void:
	if _age < 0.0:
		return
	for splash: Dictionary in _splashes:
		var grow := clampf((_age - float(splash["born"])) / 0.25, 0.0, 1.0)
		grow = 1.0 - pow(1.0 - grow, 3.0)  # fast out, then settles
		var radius := float(splash["radius"]) * grow
		var at: Vector2 = splash["at"]
		for droplet: Vector2 in splash["droplets"]:
			draw_circle(at + droplet * radius * 1.1, radius * 0.16 * grow, MILK)
		draw_circle(at, radius, RIM)
		draw_circle(at, radius * 0.94, MILK)
		# a drip that slides down from the bottom of the splash.
		var length := float(splash["drip"]) * clampf((_age - float(splash["born"])) / 1.2, 0.0, 1.0)
		draw_rect(Rect2(at.x - radius * 0.18, at.y, radius * 0.36, length), MILK)
		draw_circle(at + Vector2(0, length), radius * 0.18, MILK)
	# the last second: everything goes white.
	var fill := clampf((_age - (SPLASH_SECONDS - 0.4)) / 0.6, 0.0, 1.0)
	if fill > 0.0:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(MILK, fill))
