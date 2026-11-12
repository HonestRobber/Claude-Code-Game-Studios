# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends Node3D
## Bootstrap: input map, environment, level, player, zombie, camera, HUD.
## Pass `-- --autopilot --shots=<dir>` to run the scripted gameplay check.

const Util := preload("res://scripts/util.gd")
const LevelBuilder := preload("res://scripts/level_builder.gd")
const Player := preload("res://scripts/player.gd")
const Zombie := preload("res://scripts/zombie.gd")
const IsoCamera := preload("res://scripts/iso_camera.gd")
const Hud := preload("res://scripts/hud.gd")
const Autopilot := preload("res://scripts/autopilot.gd")

var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var level: LevelBuilder
var player: Player
var zombie: Zombie
var camera: IsoCamera
var hud: Hud


func _ready() -> void:
	cfg = Util.load_tuning("res://data/tuning.json")
	rng.seed = int(cfg["seed"])
	_setup_input()
	_setup_environment()

	level = LevelBuilder.new()
	level.name = "Level"
	add_child(level)
	level.build(cfg, rng)

	camera = IsoCamera.new()
	add_child(camera)

	player = Player.new()
	player.name = "Player"
	player.configure(cfg["player"])
	player.camera = camera
	player.position = Vector3(0, 0, 8)
	add_child(player)

	zombie = Zombie.new()
	zombie.name = "Zombie"
	zombie.configure(cfg["zombie"], player, rng)
	zombie.position = zombie.home
	add_child(zombie)

	camera.target = player
	camera.snap_to_target()

	hud = Hud.new()
	add_child(hud)
	hud.bind(player, zombie, level.container, cfg["items"])

	var args := OS.get_cmdline_user_args()
	if "--autopilot" in args:
		var ap := Autopilot.new()
		ap.main = self
		for a in args:
			if a.begins_with("--shots="):
				ap.out_dir = a.trim_prefix("--shots=")
		add_child(ap)
	print("ISO_SURVIVAL ready renderer=%s adapter=%s" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart", false, true):  # ignore key echo
		get_tree().reload_current_scene()


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"heal": [KEY_H],
		"restart": [KEY_R],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
