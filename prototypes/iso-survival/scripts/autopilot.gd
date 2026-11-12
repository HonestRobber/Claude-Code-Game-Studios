# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends Node
## Scripted gameplay check. Drives the REAL input actions (Input.action_press),
## asserts outcomes, saves 1280x720 screenshots, quits with exit code = failures.

const Util := preload("res://scripts/util.gd")
const LB := preload("res://scripts/level_builder.gd")

var main: Node
var out_dir := ""
var checks := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var p: CharacterBody3D = main.player
	var z: CharacterBody3D = main.zombie
	var lv: Node3D = main.level
	var cab: Node3D = lv.container
	var inv: RefCounted = p.inventory

	await _frames(30)
	_check("start: zombie not hostile", z.state_name() in ["idle", "wandering"], z.state_name())
	_check("start: inventory empty", inv.total() == 0, str(inv.items))
	await _shot("01_start")

	# 8-direction: hold W+D for a few frames, verify the move vector is a snapped diagonal.
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _frames(6)
	var md: Vector3 = p.move_dir
	_release()
	var axes := Util.screen_axes(main.camera)
	var expect: Vector3 = (axes[0] + axes[1]).normalized()
	_check("8-dir: W+D moves screen up-right", md.distance_to(expect) < 0.01, "move_dir=%s expect=%s" % [md, expect])

	# Ground pickup.
	var start_pos := Vector3(2.5, 0, 6.2)
	_check("walk to bandage", await _walk_to(start_pos), str(p.global_position))
	_check("bandage targeted", p.current_target != null and p.current_target.get_prompt() == "Pick up Bandage",
		p.current_target.get_prompt() if p.current_target else "none")
	await _tap("interact")
	_check("pickup: bandage in inventory", inv.count("bandage") == 1, str(inv.items))

	# Into the house.
	for wp: Vector3 in [Vector3(LB.DOOR_X, 0, 1.5), Vector3(LB.DOOR_X, 0, -1.0), Vector3(-3.6, 0, -4.4)]:
		_check("walk to %s" % wp, await _walk_to(wp), str(p.global_position))
	await _frames(20)
	_check("house: player inside", lv.player_inside, "")
	_check("house: roof hidden", not lv.roof.visible, "")
	_check("cabinet targeted", p.current_target == cab, p.current_target.name if p.current_target else "none")
	await _shot("02_interior")

	# Search the cabinet.
	var before: int = inv.total()
	await _tap("interact")
	await _frames(20)
	_check("search: in progress", cab.is_searching, "progress=%.2f" % cab.progress)
	await _shot("03_searching")
	await _seconds(cab.search_time)
	_check("search: completed", cab.is_searched, "")
	_check("search: %d items added" % cab.rolls, inv.total() == before + cab.rolls, str(inv.items))
	await _frames(10)
	await _shot("04_looted")

	# Out of the house and toward the zombie.
	for wp: Vector3 in [Vector3(LB.DOOR_X, 0, -1.0), Vector3(LB.DOOR_X, 0, 1.6), Vector3(5, 0, 3)]:
		_check("walk to %s" % wp, await _walk_to(wp), str(p.global_position))
	_check("house: roof back after exit", lv.roof.visible and not lv.player_inside, "")
	var t := 0.0
	while t < 10.0 and z.state_name() != "CHASING":
		_steer((z.global_position - p.global_position).normalized())
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release()
	_check("zombie: starts chasing", z.state_name() == "CHASING", "%s at %.1f m" % [z.state_name(), z.distance_to_player()])
	var d0: float = z.distance_to_player()
	await _seconds(0.5)
	var d1: float = z.distance_to_player()
	_check("zombie: closes distance", d1 < d0 - 0.5, "%.2f -> %.2f m" % [d0, d1])
	await _shot("05_chase")

	var hp0: int = p.health
	t = 0.0
	while t < 6.0 and p.health >= hp0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check("zombie: attack damages player", p.health < hp0, "hp %d -> %d, state %s" % [hp0, p.health, z.state_name()])
	await _frames(5)
	await _shot("06_attacked")

	var hp1: int = p.health
	var bandages: int = inv.count("bandage")
	await _tap("heal")
	_check("heal: one bandage used, HP up", inv.count("bandage") == bandages - 1 and p.health > hp1,
		"bandages %d -> %d, hp %d -> %d" % [bandages, inv.count("bandage"), hp1, p.health])

	# Escape: run away; player is faster, zombie should lose track.
	var away := (p.global_position - z.global_position).normalized()
	t = 0.0
	while t < 9.0 and z.state_name() in ["CHASING", "ATTACKING"]:
		_steer(away)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release()
	_check("escape: zombie gives up", z.state_name() in ["idle", "wandering"], "%s at %.1f m" % [z.state_name(), z.distance_to_player()])

	# Death: walk into the zombie and stand still until killed.
	t = 0.0
	while t < 12.0 and z.distance_to_player() > 1.0:
		_steer((z.global_position - p.global_position).normalized())
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release()
	t = 0.0
	while t < 15.0 and p.alive:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check("death: player dies at 0 HP", not p.alive and p.health == 0, "hp=%d alive=%s" % [p.health, p.alive])
	await _frames(30)
	_check("death: zombie stops attacking", z.state_name() in ["idle", "wandering"], z.state_name())
	Input.action_press("move_up")
	await _frames(10)
	_release()
	_check("death: no movement while dead", p.move_dir == Vector3.ZERO, str(p.move_dir))
	await _shot("07_dead")

	print("AUTOPILOT RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(failures)


# --- helpers ----------------------------------------------------------------

func _check(label: String, ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("CHECK %s  %s  %s" % ["PASS" if ok else "FAIL", label, detail])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _walk_to(target: Vector3, tol := 0.3, timeout := 10.0) -> bool:
	var p: CharacterBody3D = main.player
	var t := 0.0
	while t < timeout:
		var d := target - p.global_position
		d.y = 0.0
		if d.length() < tol:
			_release()
			return true
		_steer(d.normalized())
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release()
	return false


## Converts a world direction into analog strengths on the four move actions.
func _steer(world_dir: Vector3) -> void:
	var axes := Util.screen_axes(main.camera)
	var vx := world_dir.dot(axes[0])
	var vy := -world_dir.dot(axes[1])
	_axis("move_right", "move_left", vx)
	_axis("move_down", "move_up", vy)


func _axis(pos: StringName, neg: StringName, v: float) -> void:
	Input.action_release(pos)
	Input.action_release(neg)
	if v > 0.05:
		Input.action_press(pos, v)
	elif v < -0.05:
		Input.action_press(neg, -v)


func _release() -> void:
	for a: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _shot(shot_name: String) -> void:
	if out_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, shot_name]
	var err := img.save_png(path)
	print("SHOT %s size=%s err=%d" % [path, img.get_size(), err])
