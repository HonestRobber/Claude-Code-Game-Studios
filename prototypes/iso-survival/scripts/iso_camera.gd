# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends Camera3D
## Orthographic isometric follow camera (classic 45° yaw, 35.26° pitch).

const OFFSET := Vector3(14, 14, 14)

var target: Node3D
var follow_sharpness := 8.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 17.0
	near = 0.1
	far = 100.0
	current = true


func snap_to_target() -> void:
	look_at_from_position(target.global_position + OFFSET, target.global_position, Vector3.UP)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + OFFSET
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_sharpness * delta))
