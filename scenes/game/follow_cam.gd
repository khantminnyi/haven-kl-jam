class_name FollowCam
extends Camera2D
# camera follows a little ahead, pulls back at speed and shakes on hits.

@export var base_zoom := 0.85
@export var slowmo_zoom := 1.2
@export var fast_zoom := 0.7
@export var fast_speed := 1300.0  ## speed at which the camera is fully pulled back
@export var look_ahead := 0.18  ## seconds of velocity to lead by
@export var follow_sharpness := 9.0
@export var zoom_sharpness := 3.0
@export var slowmo_zoom_sharpness := 1.6  ## lower = slower, smoother push-in during slow-mo

var shooter: Shooter
var override_active := false
var override_point := Vector2.ZERO
var override_zoom := 0.0  # 0 = the default overview zoom
var _shake := 0.0
func _ready() -> void:
	add_to_group("cam")


func _process(delta: float) -> void:
	if shooter == null:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var want_position := override_point
	var want_zoom := base_zoom * 0.8
	if override_zoom > 0.0:
		want_zoom = override_zoom
	var sharpness := zoom_sharpness
	if not override_active:
		# peek 0.18 seconds along velocity, capped at 260px so fast launches cannot throw the camera miles away.
		var ahead := shooter.velocity * look_ahead
		ahead = ahead.limit_length(260.0)
		want_position = shooter.global_position + ahead
		if shooter.slowmo_active:
			want_zoom = slowmo_zoom
			sharpness = slowmo_zoom_sharpness
		else:
			# fast = zoom out. more space ahead makes the same speed easier to read.
			var speed_fraction := shooter.velocity.length() / fast_speed
			speed_fraction = clampf(speed_fraction, 0.0, 1.0)
			want_zoom = lerpf(base_zoom, fast_zoom, speed_fraction)
	# 1-exp(-k*dt) gives a smooth catch-up at different frame rates. bigger k = less lag.
	var follow_amount := 1.0 - exp(-follow_sharpness * real_delta)
	var zoom_amount := 1.0 - exp(-sharpness * real_delta)
	global_position = global_position.lerp(want_position, follow_amount)
	zoom = zoom.lerp(Vector2.ONE * want_zoom, zoom_amount)
	# screen shake fades out quickly.
	_shake = move_toward(_shake, 0.0, real_delta * 60.0)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func shake(amount: float) -> void:
	# keep the stronger shake. stacking every hit forever would make this unplayable lol.
	_shake = maxf(_shake, amount)


func snap_to(point: Vector2, zoom_level: float) -> void:
	global_position = point
	zoom = Vector2.ONE * zoom_level
	reset_smoothing()
