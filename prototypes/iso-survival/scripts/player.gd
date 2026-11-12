# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends CharacterBody3D
## Survivor: screen-relative 8-direction movement, interaction, health.

signal health_changed(current: int, maximum: int)
signal died
signal notify(text: String)

const Util := preload("res://scripts/util.gd")
const Inventory := preload("res://scripts/inventory.gd")

var speed := 4.5
var max_health := 100
var health := 100
var interact_range := 1.8
var bandage_heal := 25
var inventory: Inventory = Inventory.new()
var camera: Camera3D
var alive := true
## Nearest interactable in range with a non-empty prompt, or null.
var current_target: Node3D = null
## Last applied world-space move direction (unit or zero). Read by the autopilot.
var move_dir := Vector3.ZERO

var _gravity := 9.8
var _model: Node3D


func configure(cfg: Dictionary) -> void:
	speed = float(cfg["speed"])
	max_health = int(cfg["max_health"])
	health = max_health
	interact_range = float(cfg["interact_range"])
	bandage_heal = int(cfg["bandage_heal"])


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)

	_model = Node3D.new()
	add_child(_model)
	_model.add_child(Util.mesh_capsule(0.22, 0.8, Color(0.22, 0.24, 0.3), Vector3(0, 0.4, 0)))  # legs
	_model.add_child(Util.mesh_capsule(0.3, 0.9, Color(0.2, 0.45, 0.85), Vector3(0, 0.95, 0)))  # jacket
	_model.add_child(Util.mesh_sphere(0.2, Color(0.93, 0.76, 0.6), Vector3(0, 1.55, 0)))  # head
	_model.add_child(Util.mesh_box(Vector3(0.42, 0.5, 0.2), Color(0.45, 0.32, 0.18), Vector3(0, 1.0, -0.3)))  # backpack
	_model.add_child(Util.mesh_box(Vector3(0.14, 0.06, 0.12), Color(0.2, 0.2, 0.2), Vector3(0, 1.58, 0.2)))  # visor = facing cue


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	move_dir = Vector3.ZERO
	if alive:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v.length() > 0.2:
			move_dir = _screen_to_world(snap8(v))
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	move_and_slide()
	if move_dir != Vector3.ZERO:
		rotation.y = atan2(move_dir.x, move_dir.z)

	if not alive:
		current_target = null
		return
	current_target = _find_target()
	if Input.is_action_just_pressed("interact") and current_target != null:
		current_target.interact(self)
		current_target = null  # a pickup frees itself; never hold a dangling ref
	if Input.is_action_just_pressed("heal"):
		use_bandage()


## Snaps an input vector to the nearest of 8 screen directions (unit length).
static func snap8(v: Vector2) -> Vector2:
	return Vector2.from_angle(snappedf(v.angle(), PI / 4.0))


func _screen_to_world(v: Vector2) -> Vector3:
	var axes := Util.screen_axes(camera)
	return (axes[0] * v.x + axes[1] * -v.y).normalized()


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_d := interact_range
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		if node == null or node.is_queued_for_deletion() or node.get_prompt() == "":
			continue
		var d := Vector2(node.global_position.x - global_position.x, node.global_position.z - global_position.z).length()
		if d <= best_d:
			best_d = d
			best = node
	return best


func use_bandage() -> void:
	if health >= max_health:
		notify.emit("Already at full health")
		return
	if not inventory.remove("bandage", 1):
		notify.emit("No bandages")
		return
	health = mini(health + bandage_heal, max_health)
	health_changed.emit(health, max_health)
	notify.emit("Used Bandage (+%d HP)" % bandage_heal)


func take_damage(amount: int) -> void:
	if not alive:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		alive = false
		_model.rotation.x = deg_to_rad(-85.0)
		_model.position.y = 0.3
		died.emit()
