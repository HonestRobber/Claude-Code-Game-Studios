# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends Node3D
## Searchable cabinet. Searching takes time and cancels if the searcher walks away.

signal searched(found: Array)

const Util := preload("res://scripts/util.gd")

var display_name := "Cabinet"
var search_time := 1.2
var rolls := 3
var loot_table: Array = []
var item_names: Dictionary = {}
var rng: RandomNumberGenerator
var interact_range := 1.8

var progress := 0.0
var is_searching := false
var is_searched := false
var _searcher: Node3D
var _door: MeshInstance3D
var _body_mesh: MeshInstance3D


func setup(cfg: Dictionary, items: Dictionary, table: Array, random: RandomNumberGenerator, reach: float) -> void:
	display_name = String(cfg["name"])
	search_time = float(cfg["search_time"])
	rolls = int(cfg["rolls"])
	loot_table = table
	rng = random
	interact_range = reach
	for id: String in items:
		item_names[id] = String(items[id]["name"])


func _ready() -> void:
	add_to_group("interactable")
	var size := Vector3(0.6, 1.3, 1.2)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)
	add_child(body)
	_body_mesh = Util.mesh_box(size, Color(0.45, 0.3, 0.18), Vector3(0, size.y * 0.5, 0))
	add_child(_body_mesh)
	# Door faces +X (into the room).
	_door = Util.mesh_box(Vector3(0.05, 1.1, 1.0), Color(0.62, 0.44, 0.26), Vector3(0.32, 0.65, 0))
	add_child(_door)
	add_child(Util.mesh_box(Vector3(0.06, 0.08, 0.08), Color(0.85, 0.75, 0.3), Vector3(0.36, 0.7, 0.35)))


func get_prompt() -> String:
	if is_searched:
		return ""
	if is_searching:
		return "Searching %s..." % display_name
	return "Search %s" % display_name


func interact(player: Node) -> void:
	if is_searched or is_searching:
		return
	_searcher = player
	is_searching = true
	progress = 0.0


func _process(delta: float) -> void:
	if not is_searching:
		return
	if not _searcher.alive:
		is_searching = false
		progress = 0.0
		return
	if _flat_dist(_searcher.global_position) > interact_range * 1.25:
		is_searching = false
		progress = 0.0
		_searcher.notify.emit("Search interrupted")
		return
	progress = minf(progress + delta / search_time, 1.0)
	if progress >= 1.0:
		_finish()


func _finish() -> void:
	is_searching = false
	is_searched = true
	var found: Array = []
	for i in rolls:
		var id := _roll()
		_searcher.inventory.add(id, 1)
		found.append(item_names.get(id, id))
	# Searched visual: door swung open, dark empty interior, top darkened.
	_door.rotation.y = deg_to_rad(-100.0)
	_door.position = Vector3(0.75, 0.65, 0.5)
	add_child(Util.mesh_box(Vector3(0.04, 1.0, 0.95), Color(0.08, 0.06, 0.05), Vector3(0.31, 0.65, 0)))
	_body_mesh.material_override = Util.material(Color(0.3, 0.2, 0.12))
	_searcher.notify.emit("Found: %s" % ", ".join(found))
	searched.emit(found)


func _roll() -> String:
	var total := 0.0
	for e: Dictionary in loot_table:
		total += float(e["weight"])
	var r := rng.randf() * total
	for e: Dictionary in loot_table:
		r -= float(e["weight"])
		if r <= 0.0:
			return String(e["id"])
	return String(loot_table[-1]["id"])


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
