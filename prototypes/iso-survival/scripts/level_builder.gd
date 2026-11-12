# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends Node3D
## Builds the map: ground, trees, a house with cutaway walls + hideable roof,
## interior props, the searchable cabinet, ground loot, and a baked navmesh.

signal player_inside_changed(inside: bool)

const Util := preload("res://scripts/util.gd")
const Pickup := preload("res://scripts/pickup.gd")
const LootContainer := preload("res://scripts/loot_container.gd")

const HOUSE_MIN := Vector2(-5.0, -6.0)  # x, z
const HOUSE_MAX := Vector2(3.0, 0.0)
const WALL_H := 2.4
const WALL_T := 0.25
const DOOR_X := -1.0
const DOOR_W := 1.6
const CUT_SCALE := 0.2

const GRASS := Color(0.31, 0.46, 0.24)
const WALL := Color(0.85, 0.8, 0.68)
const WALL_CUT_TOP := Color(0.55, 0.42, 0.3)
const FLOOR := Color(0.6, 0.45, 0.3)
const ROOF := Color(0.55, 0.2, 0.17)

var nav_region: NavigationRegion3D
var roof: Node3D
var container: Node3D
var player_inside := false
var _cutaway: Array[MeshInstance3D] = []


func build(cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Nav"
	add_child(nav_region)

	_static_box(Vector3(0, -0.5, 0), Vector3(90, 1, 90), GRASS, nav_region)
	# Dirt path from the door toward the spawn point (visual only).
	add_child(Util.mesh_box(Vector3(1.6, 0.02, 8.0), Color(0.5, 0.4, 0.28), Vector3(DOOR_X, 0.01, 4.0)))
	for t: Vector3 in [Vector3(8, 0, 6), Vector3(-9, 0, -2), Vector3(6, 0, -9), Vector3(-8, 0, 9), Vector3(15, 0, -3)]:
		_tree(t)
	_static_box(Vector3(-4.0, 0.3, 7.0), Vector3(1.2, 0.6, 0.9), Color(0.5, 0.5, 0.52), nav_region)  # rock

	_build_house()

	container = LootContainer.new()
	container.name = "Cabinet"
	# Own RNG stream: loot must not depend on how many wander rolls the zombie made.
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = rng.seed + 1
	container.setup(cfg["container"], cfg["items"], cfg["loot_table"], loot_rng, float(cfg["player"]["interact_range"]))
	container.position = Vector3(HOUSE_MIN.x + WALL_T * 0.5 + 0.35, 0, -4.6)
	nav_region.add_child(container)

	for entry: Dictionary in cfg["ground_loot"]:
		var id := String(entry["id"])
		var item: Dictionary = cfg["items"][id]
		var p := Pickup.new()
		p.setup(id, String(item["name"]), Color.html(String(item["color"])))
		p.position = Util.vec3(entry["pos"])
		add_child(p)

	_bake_navmesh()


func _build_house() -> void:
	var cx := (HOUSE_MIN.x + HOUSE_MAX.x) * 0.5
	var cz := (HOUSE_MIN.y + HOUSE_MAX.y) * 0.5
	var w := HOUSE_MAX.x - HOUSE_MIN.x
	var d := HOUSE_MAX.y - HOUSE_MIN.y
	var hy := WALL_H * 0.5

	add_child(Util.mesh_box(Vector3(w, 0.04, d), FLOOR, Vector3(cx, 0.02, cz)))
	add_child(Util.mesh_box(Vector3(2.2, 0.02, 1.6), Color(0.35, 0.45, 0.6), Vector3(cx + 0.6, 0.05, cz - 0.2)))  # rug

	# Back walls (north, west) stay full height; camera-facing walls (south, east) cut away when inside.
	_static_box(Vector3(cx, hy, HOUSE_MIN.y), Vector3(w + WALL_T, WALL_H, WALL_T), WALL, nav_region)
	_static_box(Vector3(HOUSE_MIN.x, hy, cz), Vector3(WALL_T, WALL_H, d), WALL, nav_region)
	_static_box(Vector3(HOUSE_MAX.x, hy, cz), Vector3(WALL_T, WALL_H, d), WALL, nav_region, true)
	var left_end := DOOR_X - DOOR_W * 0.5
	var right_start := DOOR_X + DOOR_W * 0.5
	var lw := left_end - HOUSE_MIN.x
	var rw := HOUSE_MAX.x - right_start
	_static_box(Vector3(HOUSE_MIN.x + lw * 0.5, hy, HOUSE_MAX.y), Vector3(lw, WALL_H, WALL_T), WALL, nav_region, true)
	_static_box(Vector3(right_start + rw * 0.5, hy, HOUSE_MAX.y), Vector3(rw + WALL_T, WALL_H, WALL_T), WALL, nav_region, true)

	# Interior props (colliders, so they shape the navmesh).
	_static_box(Vector3(1.9, 0.25, -4.7), Vector3(1.1, 0.5, 2.0), Color(0.3, 0.4, 0.7), nav_region)  # bed
	add_child(Util.mesh_box(Vector3(1.0, 0.12, 0.45), Color(0.95, 0.95, 0.92), Vector3(1.9, 0.56, -5.4)))  # pillow
	_static_box(Vector3(-0.5, 0.4, -3.6), Vector3(1.2, 0.8, 0.8), Color(0.5, 0.33, 0.2), nav_region)  # table
	_static_box(Vector3(-0.5, 0.25, -2.85), Vector3(0.45, 0.5, 0.45), Color(0.42, 0.28, 0.17), nav_region)  # chair

	roof = Node3D.new()
	roof.name = "Roof"
	roof.add_child(Util.mesh_box(Vector3(w + 0.8, 0.25, d + 0.8), ROOF, Vector3(cx, WALL_H + 0.12, cz)))
	roof.add_child(Util.mesh_box(Vector3(w + 0.9, 0.12, 0.5), ROOF.darkened(0.3), Vector3(cx, WALL_H + 0.3, cz)))
	add_child(roof)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w - WALL_T, WALL_H, d - WALL_T)
	shape.shape = box
	area.add_child(shape)
	area.position = Vector3(cx, hy, cz)
	area.body_entered.connect(_on_interior.bind(true))
	area.body_exited.connect(_on_interior.bind(false))
	add_child(area)


func _on_interior(body: Node3D, inside: bool) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = inside
	roof.visible = not inside
	for mi in _cutaway:
		var h: float = mi.get_meta("full_height")
		mi.scale.y = CUT_SCALE if inside else 1.0
		mi.position.y = (-h * 0.5 + h * CUT_SCALE * 0.5) if inside else 0.0
		(mi.material_override as StandardMaterial3D).albedo_color = WALL_CUT_TOP if inside else WALL
	player_inside_changed.emit(inside)


func _tree(pos: Vector3) -> void:
	var body := _static_box(pos + Vector3(0, 0.9, 0), Vector3(0.5, 1.8, 0.5), Color(0.4, 0.27, 0.15), nav_region)
	body.add_child(Util.mesh_sphere(1.2, Color(0.2, 0.38, 0.18), Vector3(0, 1.6, 0)))


func _static_box(center: Vector3, size: Vector3, color: Color, parent: Node, cutaway := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := Util.mesh_box(size, color)
	body.add_child(mi)
	parent.add_child(body)
	if cutaway:
		mi.set_meta("full_height", size.y)
		_cutaway.append(mi)
	return body


func _bake_navmesh() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	# Multiples of cell size/height, so the baker doesn't round them (and warn).
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh(false)
