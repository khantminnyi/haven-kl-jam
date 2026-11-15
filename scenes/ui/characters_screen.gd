class_name CharactersScreen
extends Control
# character cards with a back button. drawings and text from the card data.

signal closed

const INK := Color("#1b1b1b")
const PAPER := Color("#f2ead3")
const YELLOW := Color("#f1c40f")
const RED := Color("#ec3750")

# one entry per character. `unlock` is how many levels must be open (Game.unlocked).
const CARDS: Array[Dictionary] = [
	{
		"name": "the soldier", "look": CharacterRig.Look.SOLDIER, "unlock": 1, "colour": Color("#6f8f45"),
		"story": "a commando. the last one standing of his platoon. sarge shouts at him over the radio.",
		"trick": "space throws a grenade. it brings down brick walls and sets off tnt",
		"weak": "enemy bullets. nothing else, he is built different",
	},
	{
		"name": "mama coco", "look": CharacterRig.Look.GRANDMA, "unlock": 3, "colour": Color("#ec3750"),
		"story": "a cool grandma with an rpg. a dog stole her slippers and she wants them back.",
		"trick": "hold space or right mouse in the air to float down slowly, keeping her speed",
		"weak": "frail: a hard landing costs a heart. pillows are soft, so bounce on those",
	},
	{
		"name": "the lactose guy", "look": CharacterRig.Look.LACTOSE, "unlock": 4, "colour": Color("#338eda"),
		"story": "loves dairy. is lactose intolerant. his only line is MILK.",
		"trick": "hold space to keep farting: a jetpack. the gas sets off tnt",
		"weak": "no weapon, and a limited tank. red zones ban farting",
	},
]

var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := Button.new()
	back.text = "back"
	back.custom_minimum_size = Vector2(220, 52)
	back.position = Vector2(1030, 22)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)


func _process(delta: float) -> void:
	_time += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2d5c"))
	draw_string_outline(font, Vector2(40, 74), "le characters", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, 14, INK)
	draw_string(font, Vector2(40, 74), "le characters", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, YELLOW)
	var width := (size.x - 40.0 * 2.0 - 30.0 * 2.0) / 3.0
	for i in range(CARDS.size()):
		_draw_card(font, CARDS[i], Rect2(40.0 + i * (width + 30.0), 100.0, width, 610.0))


func _draw_card(font: Font, card: Dictionary, box: Rect2) -> void:
	var open := Game.unlocked >= int(card["unlock"])
	var look: CharacterRig.Look = card["look"]
	var spec: Dictionary = CharacterRig.LOOKS[look]
	draw_rect(Rect2(box.position + Vector2(8, 8), box.size), INK)
	draw_rect(box, PAPER)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 190.0)), Color(card["colour"], 0.9) if open else Color("#55504a"))
	Paint.rect(self, box, INK, 5.0, int(box.position.x))  # wobbly ms paint outline
	var bob := sin(_time * 2.0) * 4.0
	CharacterRig.draw_portrait(self, look, box.position + Vector2(box.size.x / 2.0, 100.0 + bob), 150.0, Color.WHITE if open else Color.BLACK)
	if not open:
		draw_string(font, box.position + Vector2(20, 240), "???", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, INK)
		draw_string(font, box.position + Vector2(20, 290), "reach level %d to meet them" % (int(card["unlock"]) + 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(INK, 0.7))
		return
	draw_string(font, box.position + Vector2(20, 228), String(card["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, INK)
	# stats, straight from the character's data.
	var hearts := int(spec.get("health", 3))
	var shots := int(spec.get("air_shots", 1))
	var rows := [["health", "%d hearts" % hearts], ["air shots", str(shots)], ["shoots", _weapon(spec)]]
	for i in range(rows.size()):
		var y := 268.0 + i * 28.0
		draw_string(font, box.position + Vector2(20, y), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, 0.6))
		draw_string(font, box.position + Vector2(150, y), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	var y := 348.0
	var text_width := box.size.x - 40.0
	for entry: Array in [["story", card["story"], INK], ["trick", card["trick"], Color("#1f7a4a")], ["weakness", card["weak"], RED]]:
		draw_string(font, box.position + Vector2(20, y), String(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, 0.6))
		var text := String(entry[1])
		draw_multiline_string(font, box.position + Vector2(20, y + 24.0), text, HORIZONTAL_ALIGNMENT_LEFT, text_width, 18, -1, entry[2])
		# move down by however tall that text really was, so nothing overlaps.
		y += 24.0 + font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, text_width, 18).y + 16.0


func _weapon(spec: Dictionary) -> String:
	match int(spec.get("shot", Bullet.Style.BULLET)):
		Bullet.Style.ROCKET:
			return "rockets"
		Bullet.Style.FART:
			return "gas (no gun)"
	return "bullets"
