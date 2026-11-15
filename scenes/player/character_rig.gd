@tool
class_name CharacterRig
extends Node2D
# the floppy picture attached to the player. springs for looks, no physics joints.

enum Look { SOLDIER, GRANDPA, GRANDMA, LACTOSE }
enum Prop { RIFLE, SLIPPER, SPRITE, NONE }
enum Ability { NONE, GLIDE, JET, GRENADE }

const INK := Color("#1b1b1b")
const ROOT := "res://art/kenney_modular-characters/PNG/"
# kenney parts are big; this shrinks them to game size.
const PART_SCALE := 0.19
# comically big heads, so faces read from far away.
static var head_scale := 1.5  # the konami code makes this huge

# each look is just a list of which part files to use.
const LOOKS := {
	# the toy soldier: hand-edited sprites (art/sprites/soldier), so the body wobbles as one piece.
	Look.SOLDIER: {
		"sprites": "res://art/sprites/soldier/", "helmet": false, "prop": Prop.SPRITE, "ability": Ability.GRENADE,
		"body_height": 74.0, "head_height": 60.0, "prop_length": 84.0,
	},
	# the lactose intolerant man has no weapon. he is the weapon.
	Look.LACTOSE: {
		"sprites": "res://art/sprites/lactose/", "helmet": false, "body_height": 70.0, "head_height": 60.0, "back_height": 112.0,
		"prop": Prop.NONE, "shot": Bullet.Style.FART, "air_shots": 2, "ability": Ability.JET,
	},
	# hand-made sprite character: a folder with head_calm/head_ow/head_scream/body/prop pngs.
	# no separate limbs, so the whole body wobbles instead. sizes are in game pixels.
	Look.GRANDMA: {
		"sprites": "res://art/sprites/grandma/", "helmet": false, "prop": Prop.SPRITE, "shot": Bullet.Style.ROCKET, "ability": Ability.GLIDE,
		"body_height": 62.0, "head_height": 58.0, "prop_length": 74.0,
		# frail but not glass: three hearts, and only a hard knock (faster than hurt_speed) into a
		# surface costs one. pillows (soft bouncy blocks) never hurt her.
		"health": 3, "hurt_speed": 750.0,
	},
}

@export var look := Look.SOLDIER
@export var limb_stiffness := 55.0
@export var limb_damping := 2.5
@export var flail := 0.035  ## random limb jitter per unit of speed

var _shooter: Shooter
var _parts := {}  # loaded textures for the current look
var _rot := 0.0  # body rotation; spins while flying
var _spin := 0.0
var _limbs: Array[Dictionary] = []
var _loose: Array[Dictionary] = []  # body parts that flew off on death
var _prop_free := false
var _prop_pos := Vector2.ZERO
var _prop_vel := Vector2.ZERO
var _prop_rot := 0.0
var _flash := 0.0  # muzzle flash timer
var _flash_dir := Vector2.RIGHT
var _speech := ""
var _speech_timer := 0.0
var _hurt_timer := 0.0
var _scales := {}  # per-part scale for sprite characters (kenney parts use PART_SCALE)
var _sprite_mode := false
var _stretch := 0.0  # 0 = normal, 1 = fully stretched like a pulled rubber band
var _stretch_vel := 0.0
var _stretch_dir := Vector2.RIGHT
var _bullet_pos := Vector2.ZERO
var _bullet_vel := Vector2.ZERO
var _bullet_on := false
# story tricks: show the character from behind, and (lactose guy) with a stained backside.
var back_view := false
var stained := false
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_shooter = get_parent() as Shooter
	var spec: Dictionary = LOOKS[look]
	if spec.has("sprites"):
		_load_sprite_character(spec)
		return
	for key in ["shirt", "sleeve", "leg", "waist", "shoe"]:
		_parts[key] = load(ROOT + spec[key])
	for piece in ["head", "hand"]:
		_parts[piece] = load(ROOT + spec["skin"] + piece + ".png")
	for key in ["head", "eyes_small", "eyes_large", "mouth_calm", "mouth_scream", "mouth_hurt", "hair"]:
		_scales[key] = PART_SCALE * head_scale
	_parts["eyes_small"] = load(ROOT + "Face/Eyes/%s_small.png" % spec["eyes"])
	_parts["eyes_large"] = load(ROOT + "Face/Eyes/%s_large.png" % spec["eyes"])
	_parts["mouth_calm"] = load(ROOT + "Face/Mouth/mouth_straight.png")
	_parts["mouth_scream"] = load(ROOT + "Face/Mouth/mouth_oh.png")
	_parts["mouth_hurt"] = load(ROOT + "Face/Mouth/mouth_teethLower.png")
	if spec["hair"] != "":
		_parts["hair"] = load(ROOT + spec["hair"])
	# limbs: where they attach on the body, which texture, and its pivot inside the texture.
	_limbs = [
		_limb(Vector2(-9, -9), "sleeve", Vector2(30, 25), true),
		_limb(Vector2(-6, 13), "leg", Vector2(55, 10), false),
		_limb(Vector2(6, 13), "leg", Vector2(55, 10), false),
		_limb(Vector2(9, -9), "sleeve", Vector2(30, 25), true),
	]


func _load_sprite_character(spec: Dictionary) -> void:
	_sprite_mode = true
	var folder: String = spec["sprites"]
	for key in ["head_calm", "head_ow", "head_scream", "body"]:
		_parts[key] = load(folder + key + ".png")
	if spec["prop"] == Prop.SPRITE:
		_parts["prop"] = load(folder + "prop.png")
	if spec.has("back_height"):  # a picture of the character from behind, for story shots
		_parts["back"] = load(folder + "back.png")
		_scales["back"] = float(spec["back_height"]) / _parts["back"].get_height()
	# work out scales so each picture comes out the size we asked for, whatever its resolution.
	_scales["body"] = float(spec["body_height"]) / _parts["body"].get_height()
	for key in ["head_calm", "head_ow", "head_scream"]:
		_scales[key] = float(spec["head_height"]) / _parts["head_calm"].get_height() * head_scale / 1.5
	if spec["prop"] == Prop.SPRITE:
		_scales["prop"] = float(spec["prop_length"]) / _parts["prop"].get_width()


func _centre(key: String) -> Vector2:
	var tex: Texture2D = _parts[key]
	return Vector2(tex.get_width(), tex.get_height()) / 2.0


func _limb(anchor: Vector2, key: String, pivot: Vector2, is_arm: bool) -> Dictionary:
	return {"anchor": anchor, "key": key, "pivot": pivot, "arm": is_arm, "angle": PI / 2.0, "vel": 0.0}


func kick(strength: float) -> void:
	var amount := clampf(strength / 60.0, 4.0, 30.0)
	for limb in _limbs:
		limb["vel"] += randf_range(-1.0, 1.0) * amount
	var direction := signf(_shooter.velocity.x) if absf(_shooter.velocity.x) > 1.0 else 1.0
	_spin = direction * randf_range(7.0, 15.0)
	_hurt_timer = 0.35


func say(text: String) -> void:
	# the lactose guy only has one thing on his mind.
	if look == Look.LACTOSE:
		_speech = ["MILK", "MILK MILK", "I WANT MILK"].pick_random()
	else:
		_speech = text
	_speech_timer = 0.8


func fire(direction: Vector2) -> void:
	if shot_style() == Bullet.Style.FART:
		return
	_flash = 0.12
	_flash_dir = direction


func shot_style() -> int:
	return LOOKS[look].get("shot", Bullet.Style.BULLET)


func ability() -> int:
	return LOOKS[look].get("ability", Ability.NONE)


func max_health() -> int:
	return LOOKS[look].get("health", 3)


func hurt_speed() -> float:
	return LOOKS[look].get("hurt_speed", INF)


func air_shots() -> int:
	return LOOKS[look].get("air_shots", 1)


func explode(body_velocity: Vector2) -> void:
	# only now do you let go of the weapon.
	_prop_free = true
	_prop_pos = global_position
	_prop_vel = body_velocity * 0.3 + Vector2(randf_range(-300.0, 300.0), -500.0)
	var pieces := [["head", Vector2(0, -38), Vector2(86, 84)]]
	if _sprite_mode:
		pieces = [["head_scream", Vector2(0, -40), _centre("head_scream")], ["body", Vector2(0, 4), _centre("body")]]
	for limb in _limbs:
		pieces.append([limb["key"], limb["anchor"], limb["pivot"]])
	for piece: Array in pieces:
		var push := Vector2.from_angle(randf() * TAU) * randf_range(350.0, 900.0)
		_loose.append({
			"key": piece[0], "pivot": piece[2], "pos": global_position + _body(piece[1]),
			"vel": body_velocity * 0.4 + push + Vector2(0, -500), "rot": randf() * TAU,
			"spin": randf_range(-18.0, 18.0),
		})
	say("")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_speech_timer = maxf(_speech_timer - real_delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	_flash = maxf(_flash - real_delta, 0.0)
	var flying := _shooter.launched_once and not _shooter.is_grounded()
	var speed := _shooter.velocity.length()
	# hold f to make em go brrr. this changes the flailing, not the player collision shape.
	var ragdoll := Input.is_action_pressed("ragdoll")  # hold F: everything goes floppy
	if not _shooter.launched_once:
		_rot = 0.0
	elif flying:
		_rot += _spin * delta
		_spin = lerpf(_spin, signf(_spin) * 4.0, 1.0 - exp(-1.5 * delta))
	else:
		_rot = lerp_angle(_rot, PI / 2.0, 1.0 - exp(-10.0 * delta))  # flop over on the ground
	# limbs trail behind the motion when flying, hang down otherwise.
	var rest := PI / 2.0
	if flying and speed > 80.0:
		rest = (-_shooter.velocity).angle() - _rot
	for limb in _limbs:
		# shortest angle back to rest, not the long way round when crossing -pi/pi.
		var error := wrapf(rest - float(limb["angle"]), -PI, PI)
		# spring pulls towards rest; damping fights angular speed. fake ragdoll, no physics joints.
		limb["vel"] += (error * limb_stiffness * (0.25 if ragdoll else 1.0) - float(limb["vel"]) * limb_damping) * delta
		if flying or ragdoll:
			limb["vel"] += randf_range(-1.0, 1.0) * maxf(speed, 300.0 if ragdoll else 0.0) * flail * (10.0 if ragdoll else 1.0) * delta * 60.0
		limb["angle"] += float(limb["vel"]) * delta
	for part in _loose:
		part["vel"].y += 1800.0 * delta
		part["pos"] += part["vel"] * delta
		part["rot"] += float(part["spin"]) * delta
	if _bullet_on:
		_bullet_vel.y += 1400.0 * delta
		_bullet_pos += _bullet_vel * delta
	_update_stretch(delta)
	if _prop_free:
		_prop_vel.y += 1800.0 * delta
		_prop_pos += _prop_vel * delta
		_prop_rot += 11.0 * delta
	queue_redraw()


func _update_stretch(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _shooter.dragging and _shooter.launched_once:
		var pull: Vector2 = _shooter._pull()
		if pull.length() > 1.0:
			_stretch_dir = -pull.normalized()
		else:
			_stretch_dir = _stretch_dir
		_stretch = move_toward(_stretch, clampf(pull.length() / _shooter.max_pull, 0.0, 1.0), real_delta * 6.0)
		_stretch_vel = 0.0
	else:
		# spring back to 0 and overshoot a little: that's the jelly wobble.
		_stretch_vel += (-_stretch * 260.0 - _stretch_vel * 9.0) * real_delta
		_stretch += _stretch_vel * real_delta
	var along := 1.0 + _stretch * 0.9
	var across := 1.0 / sqrt(maxf(along, 0.2))
	var turn := Transform2D(_stretch_dir.angle(), Vector2.ZERO)
	transform = turn * Transform2D.IDENTITY.scaled(Vector2(along, across)) * turn.affine_inverse()


func _body(point: Vector2) -> Vector2:
	return point.rotated(_rot)


func _draw_part(key: String, at: Vector2, angle: float, pivot: Vector2, flip := false) -> void:
	var tex: Texture2D = _parts[key]
	var size: float = _scales.get(key, PART_SCALE)
	var scale := Vector2(-size if flip else size, size)
	draw_set_transform(at, angle, scale)
	draw_texture(tex, -pivot)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_limb(limb: Dictionary) -> void:
	if _shooter.alive == false:
		return  # it's flying around in _loose now
	var at := _body(limb["anchor"])
	var flip: bool = limb["arm"] and float(limb["anchor"].x) < 0.0
	# the sprites point down by default, so "pointing down" (PI/2) means no extra rotation.
	var angle := float(limb["angle"]) - PI / 2.0 + _rot
	_draw_part(limb["key"], at, angle, limb["pivot"], flip)
	var tex: Texture2D = _parts[limb["key"]]
	var end_local := Vector2(tex.get_width() - limb["pivot"].x - 20.0, tex.get_height() - limb["pivot"].y - 15.0)
	if limb["arm"]:
		var hand_offset := Vector2(end_local.x * (-1.0 if flip else 1.0), end_local.y) * PART_SCALE
		_draw_part("hand", at + hand_offset.rotated(angle), angle, Vector2(30, 35))
	else:
		_draw_part("shoe", at + Vector2(0, end_local.y * PART_SCALE).rotated(angle), angle, Vector2(30, 10))


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 16.0, Color("#33d6a6"))
		draw_string(ThemeDB.fallback_font, Vector2(-20, -24), "start", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		return
	for part in _loose:
		_draw_part(part["key"], to_local(part["pos"]), part["rot"], part["pivot"])
	if _prop_free:
		_draw_prop(to_local(_prop_pos), _prop_rot)
	if _bullet_on:
		var b := to_local(_bullet_pos)
		draw_circle(b, 4.0, INK)
		draw_circle(b, 2.5, Color("#f1c40f"))
	if _sprite_mode:
		_draw_sprite_character()
		return
	_draw_limb(_limbs[0])
	_draw_limb(_limbs[1])
	_draw_limb(_limbs[2])
	_draw_part("waist", _body(Vector2(0, 14)), _rot, Vector2(76, 23))
	_draw_part("shirt", _body(Vector2(0, -2)), _rot, Vector2(76, 87))
	if stained:
		draw_circle(_body(Vector2(0, 15)), 9.0, Color("#6b4423"))
		draw_circle(_body(Vector2(-3, 20)), 5.0, Color("#6b4423"))
	if _shooter.alive:
		_draw_head(_body(Vector2(0, -38)))
	_draw_limb(_limbs[3])
	if not _prop_free:
		# while aiming, the prop points at the mouse (where the "bullet" would go).
		var aim := _shooter.aim_direction().angle() if _shooter.dragging else 0.0
		_draw_prop(_body(Vector2(9, -4)), aim)
	if _flash > 0.0:
		var tip := _flash_dir * 48.0
		draw_circle(tip, 18.0, Color("#ffe066"))
		draw_circle(tip, 9.0, Color.WHITE)
	if _speech_timer > 0.0 and _speech != "":
		var font := ThemeDB.fallback_font
		var at := Vector2(20.0, -58.0 - (0.8 - _speech_timer) * 24.0)
		draw_string_outline(font, at, _speech, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, 10, Color("#f2ead3"))
		draw_string(font, at, _speech, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, INK)


func _draw_sprite_character() -> void:
	if back_view and _parts.has("back"):
		_draw_part("back", _body(Vector2(0, -14)), _rot, _centre("back"))
		if stained:
			draw_circle(_body(Vector2(0, 24)), 9.0, Color("#6b4423"))
			draw_circle(_body(Vector2(-4, 30)), 5.0, Color("#6b4423"))
		_draw_overlays()
		return
	if _shooter.alive:
		_draw_part("body", _body(Vector2(0, 4)), _rot, _centre("body"))
		var panicking := _shooter.launched_once and not _shooter.is_grounded()
		var head := "head_ow" if _hurt_timer > 0.0 else ("head_scream" if panicking else "head_calm")
		_draw_part(head, _body(Vector2(0, -40)), _rot, _centre(head))
	if not _prop_free and _shooter.alive:
		var aim := _shooter.aim_direction().angle() if _shooter.dragging else 0.0
		_draw_prop(_body(Vector2(4, -6)), aim)
	_draw_overlays()


func _draw_overlays() -> void:
	if _flash > 0.0:
		var tip := _flash_dir * 48.0
		draw_circle(tip, 18.0, Color("#ffe066"))
		draw_circle(tip, 9.0, Color.WHITE)
	if _speech_timer > 0.0 and _speech != "":
		var font := ThemeDB.fallback_font
		var at := Vector2(20.0, -58.0 - (0.8 - _speech_timer) * 24.0)
		draw_string_outline(font, at, _speech, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, 10, Color("#f2ead3"))
		draw_string(font, at, _speech, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, INK)


func _draw_head(head: Vector2) -> void:
	_draw_part("head", head, _rot, Vector2(86, 84))
	var panicking := _shooter.launched_once and not _shooter.is_grounded()
	# the eye picture is a single eye, so draw it twice, one each side of the nose.
	var eyes := "eyes_large" if panicking else "eyes_small"
	var eye_size := Vector2(_parts[eyes].get_width(), _parts[eyes].get_height())
	if back_view:
		if _parts.has("hair"):
			_draw_part("hair", head + _body(Vector2(0, -9) * head_scale), _rot, Vector2(80, 60))
		return  # we only see the back of his head
	for side in [1.0, -1.0]:
		_draw_part(eyes, head + _body(Vector2(0, -1) * head_scale), _rot, eye_size / 2.0 + Vector2(side * 30.0, 0.0))
	var mouth := "mouth_hurt" if _hurt_timer > 0.0 else ("mouth_scream" if panicking else "mouth_calm")
	_draw_part(mouth, head + _body(Vector2(0, 10) * head_scale), _rot, Vector2(20, 10))
	if _parts.has("hair"):
		_draw_part("hair", head + _body(Vector2(0, -9) * head_scale), _rot, Vector2(80, 60))
	if LOOKS[look]["helmet"]:
		var helmet := PackedVector2Array()
		for i in range(13):
			helmet.append(head + Vector2.from_angle(PI + i * PI / 12.0 + _rot) * 18.5 * head_scale + _body(Vector2(0, -4) * head_scale))
		draw_colored_polygon(helmet, Color("#4d6a30"))
		draw_polyline(helmet, INK, 3.0)
		draw_line(helmet[0], helmet[12], INK, 4.0)


func _draw_prop(at: Vector2, angle: float) -> void:
	draw_set_transform(at, angle, Vector2(0.65, 0.65))
	match LOOKS[look]["prop"]:
		Prop.RIFLE:
			draw_rect(Rect2(-14.0, -4.0, 66.0, 8.0), INK)
			draw_rect(Rect2(-24.0, -3.0, 14.0, 15.0), INK)
			draw_rect(Rect2(6.0, -12.0, 22.0, 7.0), INK)
			draw_rect(Rect2(-12.0, -2.0, 62.0, 4.0), Color("#707070"))
		Prop.SPRITE:
			draw_set_transform(at, angle, Vector2.ONE * float(_scales["prop"]))
			draw_texture(_parts["prop"], -_centre("prop"))
		Prop.SLIPPER:
			draw_rect(Rect2(-6.0, -9.0, 44.0, 18.0), INK)
			draw_rect(Rect2(-3.0, -6.0, 38.0, 12.0), Color("#c0466a"))
			draw_rect(Rect2(8.0, -10.0, 12.0, 20.0), Color("#f2ead3"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- portraits (character overview screen) ---------------------------------------------------

static var _portrait_cache := {}


static func draw_portrait(canvas: CanvasItem, look: Look, centre: Vector2, size: float, tint := Color.WHITE) -> void:
	var spec: Dictionary = LOOKS[look]
	if not _portrait_cache.has(look):
		var loaded := {}
		if spec.has("sprites"):
			loaded["head"] = load(String(spec["sprites"]) + "head_calm.png")
		else:
			loaded["head"] = load(ROOT + spec["skin"] + "head.png")
			loaded["eyes"] = load(ROOT + "Face/Eyes/%s_large.png" % spec["eyes"])
			loaded["mouth"] = load(ROOT + "Face/Mouth/mouth_straight.png")
			if spec["hair"] != "":
				loaded["hair"] = load(ROOT + spec["hair"])
		_portrait_cache[look] = loaded
	var parts: Dictionary = _portrait_cache[look]
	var head: Texture2D = parts["head"]
	if spec.has("sprites"):
		var factor := size / head.get_height()
		canvas.draw_set_transform(centre, 0.0, Vector2.ONE * factor)
		canvas.draw_texture(head, -Vector2(head.get_width(), head.get_height()) / 2.0, tint)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var k := size / (head.get_height() * PART_SCALE * head_scale)  # rig units -> pixels
	var unit := PART_SCALE * head_scale * k
	var pieces := [["head", Vector2.ZERO, Vector2(86, 84)], ["eyes", Vector2(0, -1), Vector2(40.5, 10.5)], ["eyes", Vector2(0, -1), Vector2(-19.5, 10.5)], ["mouth", Vector2(0, 10), Vector2(20, 10)], ["hair", Vector2(0, -9), Vector2(80, 60)]]
	for piece: Array in pieces:
		if not parts.has(piece[0]):
			continue
		canvas.draw_set_transform(centre + piece[1] * head_scale * k, 0.0, Vector2.ONE * unit)
		canvas.draw_texture(parts[piece[0]], -piece[2], tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if spec["helmet"]:
		var helmet := PackedVector2Array()
		for i in range(13):
			helmet.append(centre + Vector2(0, -4) * head_scale * k + Vector2.from_angle(PI + i * PI / 12.0) * 18.5 * head_scale * k)
		canvas.draw_colored_polygon(helmet, Color("#4d6a30") * tint)
		canvas.draw_polyline(helmet, INK, 3.0 * k)
