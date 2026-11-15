@tool
class_name LevelMap
extends Node2D
# old text-map generator. the shipped levels now use saved, movable nodes.
# manual_layout skips generation; the old map string is just a sketch in those scenes.

const TILE := 64.0
@export_storage var manual_layout := false
@export var level_size := Vector2(2304, 896):
	set(value):
		level_size = value
		if manual_layout:
			bounds = Rect2(Vector2.ZERO, value)
@export_tool_button("Make level editable") var bake_button = make_editable

func make_editable() -> void:
	if manual_layout or not is_node_ready() or owner == null:
		return
	level_size = bounds.size
	manual_layout = true
	var counts := {}
	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		var label: String = child.get_script().get_global_name()
		counts[label] = counts.get(label, 0) + 1
		child.name = label + str(counts[label])
		child.owner = owner
	notify_property_list_changed()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		Engine.get_singleton("EditorInterface").mark_scene_as_unsaved()

const KINDS := {"#": Block.Kind.STONE, "B": Block.Kind.BRICK, "M": Block.Kind.METAL, "O": Block.Kind.BOUNCY,
	"^": Block.Kind.SPIKES, "X": Block.Kind.EXPLOSIVE, "L": Block.Kind.LAVA, "K": Block.Kind.STICKY, "G": Block.Kind.GLASS}

@export_enum("dirt", "grass", "planet", "sand", "snow", "stone") var theme := "dirt":
	set(value):
		theme = value
		_rebuild()
@export var lamp_colour := Color(1.0, 0.65, 0.3)
@export var zones_ban_shots := true  ## false: the n zones only switch off the fart jet, you can still sling
@export var no_zone_label := "no shooting"  ## text shown on the striped no-shoot zones
@export var pillows := false  ## draw bouncy blocks as soft pillows (no damage, even for grandma)
@export var power_icon := "bolt"  ## how the `p` power-up looks: bolt, ammo, tea, cheese
@export var signs: PackedStringArray = []  ## texts for the map characters 1 to 9
@export_multiline var map := "":
	set(value):
		map = value
		_rebuild()

var bounds := Rect2()
func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	if manual_layout:
		bounds = Rect2(Vector2.ZERO, level_size)
		return
	for child in get_children():
		child.queue_free()
	var rows := map.split("\n", false)
	var height := rows.size()
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	bounds = Rect2(0, 0, width * TILE, height * TILE)
	var grid: Array[PackedStringArray] = []
	for row in rows:
		var cells := PackedStringArray()
		for x in range(width):
			cells.append(row[x] if x < row.length() else ".")
		grid.append(cells)
	for kind_char: String in KINDS:
		# build one block per merged rectangle. hundreds of separate floor tiles love catching your feet.
		for rect in _merge(grid, kind_char):
			_add_block(rect, KINDS[kind_char], grid)
	for rect in _merge(grid, "n"):
		var zone := NoSlingZone.new()
		zone.label = no_zone_label
		zone.bans_shots = zones_ban_shots
		zone.size = rect.size * TILE
		zone.position = (rect.position + rect.size / 2.0) * TILE
		add_child(zone)
	for y in range(height):
		for x in range(width):
			var cell := grid[y][x]
			var centre := Vector2(x + 0.5, y + 0.5) * TILE
			if cell == "*":
				var lamp := Lamp.new()
				lamp.colour = lamp_colour
				lamp.position = centre
				add_child(lamp)
			elif cell == "d":
				_add_decor(centre)
			elif cell == "e":
				var enemy := Enemy.new()
				enemy.position = centre + Vector2(0, 2)
				add_child(enemy)
			elif cell == "c" or cell == "p":
				var pickup := Pickup.new()
				if cell == "c":
					pickup.kind = Pickup.Kind.SMASH
				else:
					pickup.kind = Pickup.Kind.POWER
				pickup.icon = power_icon
				pickup.position = centre
				add_child(pickup)
			elif cell.is_valid_int() and int(cell) >= 1 and int(cell) <= signs.size():
				var sign := Sign.new()
				sign.text = signs[int(cell) - 1]
				sign.position = centre
				add_child(sign)
			elif cell == "S":
				_place("../Shooter", centre + Vector2(0, TILE / 2.0 - 18.0))
			elif cell == "T":
				_place("../Target", centre)
				_ground_target(grid, x, y)


func _ground_target(grid: Array[PackedStringArray], x: int, y: int) -> void:
	var target := get_node_or_null("../Target") as Target
	if target == null or target.picture == null:
		return
	for row in range(y, grid.size()):
		if KINDS.has(grid[row][x]):
			target.position.y = position.y + row * TILE - target.picture_height / 2.0
			return


func _place(path: String, at: Vector2) -> void:
	var node := get_node_or_null(path) as Node2D
	if node:
		node.position = position + at


func _add_block(rect: Rect2, kind: Block.Kind, grid: Array[PackedStringArray]) -> void:
	var block := Block.new()
	block.kind = kind
	block.theme = theme
	block.size = rect.size * TILE
	block.soft = pillows and kind == Block.Kind.BOUNCY
	block.position = (rect.position + rect.size / 2.0) * TILE
	if kind == Block.Kind.SPIKES:
		block.spike_sides = _open_sides(rect, grid)
	add_child(block)


func _open_sides(rect: Rect2, grid: Array[PackedStringArray]) -> int:
	var flags := 0
	var x0 := int(rect.position.x)
	var y0 := int(rect.position.y)
	var x1 := int(rect.end.x)
	var y1 := int(rect.end.y)
	if _any_open(grid, range(x0, x1), [y0 - 1]):
		flags |= 1
	if _any_open(grid, range(x0, x1), [y1]):
		flags |= 2
	if _any_open(grid, [x0 - 1], range(y0, y1)):
		flags |= 4
	if _any_open(grid, [x1], range(y0, y1)):
		flags |= 8
	return flags


func _any_open(grid: Array[PackedStringArray], xs: Array, ys: Array) -> bool:
	for y: int in ys:
		for x: int in xs:
			if y >= 0 and y < grid.size() and x >= 0 and x < grid[y].size() and not KINDS.has(grid[y][x]):
				return true
	return false


func _merge(grid: Array[PackedStringArray], wanted: String) -> Array[Rect2]:
	var open: Array[Rect2] = []
	var done: Array[Rect2] = []
	for y in range(grid.size()):
		var runs: Array[Rect2] = []
		var x := 0
		while x < grid[y].size():
			if grid[y][x] == wanted:
				var start := x
				while x < grid[y].size() and grid[y][x] == wanted:
					x += 1
				runs.append(Rect2(start, y, x - start, 1))
			else:
				x += 1
		var still_open: Array[Rect2] = []
		for rect in open:
			var match_index := -1
			for i in range(runs.size()):
				if runs[i].position.x == rect.position.x and runs[i].size.x == rect.size.x:
					match_index = i
					break
			if match_index >= 0:
				rect.size.y += 1
				runs.remove_at(match_index)
				still_open.append(rect)
			else:
				done.append(rect)
		still_open.append_array(runs)
		open = still_open
	done.append_array(open)
	return done


func _add_decor(centre: Vector2) -> void:
	var doodle := Doodle.new()
	doodle.theme = theme
	# pick by position, so the same map always gets the same scenery.
	doodle.pick = int(centre.x / 64.0) * 3 + int(centre.y / 64.0)
	doodle.position = centre
	add_child(doodle)
