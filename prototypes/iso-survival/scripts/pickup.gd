# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends Node3D
## Bobbing ground item. Interact to add it to the player's inventory.

const Util := preload("res://scripts/util.gd")

var item_id := ""
var display_name := ""
var color := Color.WHITE
var _mesh: MeshInstance3D
var _t := 0.0


func setup(id: String, item_name: String, item_color: Color) -> void:
	item_id = id
	display_name = item_name
	color = item_color


func _ready() -> void:
	add_to_group("interactable")
	_mesh = Util.mesh_box(Vector3(0.32, 0.32, 0.32), color)
	_mesh.material_override = Util.material(color, 0.6)
	add_child(_mesh)
	# Ground ring so loot reads at isometric zoom.
	var ring := Util.mesh_cylinder(0.38, 0.02, Color(1.0, 0.95, 0.6), Vector3(0, 0.07, 0))  # above the house floor slab (top y=0.04)
	ring.material_override = Util.material(Color(1.0, 0.92, 0.5), 0.8)
	add_child(ring)


func _process(delta: float) -> void:
	_t += delta
	_mesh.position.y = 0.4 + sin(_t * 3.0) * 0.07
	_mesh.rotation.y += delta * 1.5


func get_prompt() -> String:
	return "Pick up %s" % display_name


func interact(player: Node) -> void:
	player.inventory.add(item_id, 1)
	player.notify.emit("Picked up %s" % display_name)
	queue_free()
