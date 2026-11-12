# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends CharacterBody3D
## Zombie: idle/wander around home, chase on sight or sound, melee attack on contact.

signal state_changed(state_name: String)

enum State { IDLE, WANDER, CHASE, ATTACK }

const Util := preload("res://scripts/util.gd")
const STATE_NAMES := ["idle", "wandering", "CHASING", "ATTACKING"]

var state: State = State.IDLE
var target: CharacterBody3D
var rng: RandomNumberGenerator
var home := Vector3.ZERO

var walk_speed := 1.2
var chase_speed := 3.2
var detect_radius := 9.0
var hear_radius := 3.0
var lose_radius := 15.0
var lose_sight_time := 3.0
var attack_range := 1.25
var attack_damage := 10
var attack_cooldown := 1.0
var wander_radius := 5.0
var pause_min := 1.0
var pause_max := 2.5

var _agent: NavigationAgent3D
var _alert: Label3D
var _timer := 0.0
var _attack_cd := 0.0
var _unseen := 0.0
var _repath := 0.0
var _gravity := 9.8


func configure(cfg: Dictionary, player: CharacterBody3D, random: RandomNumberGenerator) -> void:
	target = player
	rng = random
	home = Util.vec3(cfg["home"])
	walk_speed = float(cfg["walk_speed"])
	chase_speed = float(cfg["chase_speed"])
	detect_radius = float(cfg["detect_radius"])
	hear_radius = float(cfg["hear_radius"])
	lose_radius = float(cfg["lose_radius"])
	lose_sight_time = float(cfg["lose_sight_time"])
	attack_range = float(cfg["attack_range"])
	attack_damage = int(cfg["attack_damage"])
	attack_cooldown = float(cfg["attack_cooldown"])
	wander_radius = float(cfg["wander_radius"])
	pause_min = float(cfg["wander_pause_min"])
	pause_max = float(cfg["wander_pause_max"])


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)

	add_child(Util.mesh_capsule(0.22, 0.8, Color(0.3, 0.27, 0.22), Vector3(0, 0.4, 0)))  # trousers
	add_child(Util.mesh_capsule(0.3, 0.9, Color(0.55, 0.3, 0.26), Vector3(0, 0.95, 0)))  # torn shirt
	add_child(Util.mesh_sphere(0.21, Color(0.52, 0.68, 0.42), Vector3(0, 1.55, 0)))  # head
	for side in [-1.0, 1.0]:
		add_child(Util.mesh_box(Vector3(0.12, 0.12, 0.6), Color(0.52, 0.68, 0.42), Vector3(0.26 * side, 1.2, 0.32)))  # arms forward
		var eye := Util.mesh_box(Vector3(0.06, 0.04, 0.03), Color(1, 0.1, 0.05), Vector3(0.08 * side, 1.58, 0.19))
		eye.material_override = Util.material(Color(1, 0.1, 0.05), 3.0)
		add_child(eye)

	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 96
	_alert.outline_size = 18
	_alert.modulate = Color(1, 0.2, 0.15)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.no_depth_test = true
	_alert.position = Vector3(0, 2.25, 0)
	_alert.visible = false
	add_child(_alert)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.6
	# Baked navmesh surface sits ~0.5 above the body origin; without this offset the
	# 3D waypoint distance never drops below path_desired_distance and the path stalls.
	_agent.path_height_offset = 0.5
	add_child(_agent)
	_timer = rng.randf_range(pause_min, pause_max)


func state_name() -> String:
	return STATE_NAMES[state]


func distance_to_player() -> float:
	return _flat(target.global_position - global_position).length()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	_attack_cd = maxf(_attack_cd - delta, 0.0)

	var dist := distance_to_player()
	var player_alive: bool = target.alive
	var perceives := player_alive and (dist <= hear_radius or (dist <= detect_radius and _has_los()))
	var move := Vector3.ZERO

	match state:
		State.IDLE:
			_timer -= delta
			if perceives:
				_set_state(State.CHASE)
			elif _timer <= 0.0:
				_agent.target_position = _pick_wander_point()
				_set_state(State.WANDER)
		State.WANDER:
			if perceives:
				_set_state(State.CHASE)
			elif _agent.is_navigation_finished():
				_timer = rng.randf_range(pause_min, pause_max)
				_set_state(State.IDLE)
			else:
				move = _steer(walk_speed)
		State.CHASE:
			if not player_alive:
				_set_state(State.IDLE)
			else:
				_unseen = 0.0 if perceives else _unseen + delta
				if dist > lose_radius or _unseen > lose_sight_time:
					_timer = pause_max
					_set_state(State.IDLE)
				elif dist <= attack_range and _has_los():  # no hits through walls
					_set_state(State.ATTACK)
				else:
					_repath -= delta
					if _repath <= 0.0:
						_agent.target_position = target.global_position
						_repath = 0.2
					move = _steer(chase_speed)
		State.ATTACK:
			_face(target.global_position - global_position)
			if not player_alive:
				_set_state(State.IDLE)
			elif dist > attack_range * 1.3 or not _has_los():
				_set_state(State.CHASE)
			elif _attack_cd <= 0.0:
				target.take_damage(attack_damage)
				_attack_cd = attack_cooldown

	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()


func _steer(spd: float) -> Vector3:
	var next := _agent.get_next_path_position()
	var dir := _flat(next - global_position)
	if OS.has_environment("ZDEBUG") and Engine.get_physics_frames() % 20 == 0:
		print("ZDBG st=%s pos=%s next=%s tgt=%s fin=%s reach=%s path=%d" % [state_name(), global_position, next, _agent.target_position, _agent.is_navigation_finished(), _agent.is_target_reachable(), _agent.get_current_navigation_path().size()])
	if dir.length() < 0.2:
		# Navmesh not ready, no path, or waypoint underfoot: steer straight at the target.
		dir = _flat(_agent.target_position - global_position)
	if dir.length() < 0.05:
		return Vector3.ZERO
	dir = dir.normalized()
	_face(dir)
	return dir * spd


func _face(dir: Vector3) -> void:
	var d := _flat(dir)
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)


func _has_los() -> bool:
	var from := global_position + Vector3(0, 1.5, 0)
	var to := target.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _pick_wander_point() -> Vector3:
	var a := rng.randf() * TAU
	var r := rng.randf_range(1.5, wander_radius)
	var p := home + Vector3(cos(a) * r, 0, sin(a) * r)
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		p = NavigationServer3D.map_get_closest_point(map, p)
	return p


func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	_alert.visible = s == State.CHASE or s == State.ATTACK
	state_changed.emit(state_name())


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
