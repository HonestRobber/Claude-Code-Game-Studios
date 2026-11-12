# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends CanvasLayer
## Compact HUD: health + inventory (top-left), threat (top-right),
## interaction prompt + search bar (bottom-centre), toast, controls, death screen.

const PANEL_BG := Color(0.05, 0.06, 0.08, 0.78)
const TEXT := Color(0.95, 0.95, 0.92)
const DIM := Color(0.7, 0.72, 0.75)

var player: Node
var zombie: Node
var container: Node
var items_cfg: Dictionary

var _hp_bar: ProgressBar
var _hp_fill: StyleBoxFlat
var _hp_label: Label
var _inv_title: Label
var _inv_box: VBoxContainer
var _threat: Label
var _prompt: Label
var _search_bar: ProgressBar
var _toast: Label
var _toast_t := 0.0
var _death: Control


func _ready() -> void:
	layer = 10
	_build_status_panel()
	_build_threat_panel()
	_build_prompt()
	_build_toast()
	_build_controls()
	_build_death()


func bind(p: Node, z: Node, c: Node, items: Dictionary) -> void:
	player = p
	zombie = z
	container = c
	items_cfg = items
	player.health_changed.connect(_on_health)
	player.died.connect(func() -> void: _death.visible = true)
	player.notify.connect(show_toast)
	player.inventory.changed.connect(_refresh_inventory)
	_on_health(player.health, player.max_health)
	_refresh_inventory()


func _process(delta: float) -> void:
	if player == null:
		return
	# Threat readout.
	var st: String = zombie.state_name()
	var dist: float = zombie.distance_to_player()
	_threat.text = "ZOMBIE  %s  %.0f m" % [st, dist]
	var hot := st == "CHASING" or st == "ATTACKING"
	_threat.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if hot else DIM)

	# Interaction prompt / search progress.
	var tgt: Variant = player.current_target
	if is_instance_valid(tgt) and not (tgt as Node).is_queued_for_deletion():
		_prompt.text = "[E]  %s" % tgt.get_prompt()
		_prompt.visible = true
	else:
		_prompt.visible = false
	_search_bar.visible = container.is_searching
	_search_bar.value = container.progress * 100.0

	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.0
	_toast.modulate.a = 1.0


func _on_health(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "%d" % current
	var r := float(current) / float(maximum)
	_hp_fill.bg_color = Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.8, 0.35), r)


func _refresh_inventory() -> void:
	for c in _inv_box.get_children():
		c.queue_free()
	var inv: Dictionary = player.inventory.items
	_inv_title.text = "INVENTORY  (%d)" % player.inventory.total()
	if inv.is_empty():
		_inv_box.add_child(_label("empty", 15, DIM))
		return
	var ids := inv.keys()
	ids.sort()
	for id: String in ids:
		var cfg: Dictionary = items_cfg.get(id, {"name": id, "color": "#ffffff"})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var sw := ColorRect.new()
		sw.color = Color.html(String(cfg["color"]))
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var name_l := _label(String(cfg["name"]), 15, TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(_label("x%d" % int(inv[id]), 15, TEXT))
		_inv_box.add_child(row)


# --- construction -----------------------------------------------------------

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _bar(fill: Color) -> Array:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.17)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return [bar, fg]


func _build_status_panel() -> void:
	var p := _panel()
	p.position = Vector2(16, 16)
	p.custom_minimum_size = Vector2(250, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_row.add_child(_label("HP", 15, DIM))
	var made := _bar(Color(0.3, 0.8, 0.35))
	_hp_bar = made[0]
	_hp_fill = made[1]
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_label = _label("100", 15, TEXT)
	_hp_label.custom_minimum_size = Vector2(30, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)
	v.add_child(hp_row)
	v.add_child(HSeparator.new())
	_inv_title = _label("INVENTORY", 13, DIM)
	v.add_child(_inv_title)
	_inv_box = VBoxContainer.new()
	_inv_box.add_theme_constant_override("separation", 2)
	v.add_child(_inv_box)


func _build_threat_panel() -> void:
	var p := _panel()
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_threat = _label("ZOMBIE", 16, DIM)
	p.add_child(_threat)


func _build_prompt() -> void:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_END
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(v)
	_prompt = _label("", 20, TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	v.add_child(_prompt)
	var made := _bar(Color(0.95, 0.75, 0.25))
	_search_bar = made[0]
	_search_bar.custom_minimum_size = Vector2(220, 10)
	_search_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_search_bar.visible = false
	v.add_child(_search_bar)


func _build_toast() -> void:
	_toast = _label("", 18, Color(1, 0.92, 0.6))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.modulate.a = 0.0
	add_child(_toast)


func _build_controls() -> void:
	var l := _label("WASD move   E interact   H bandage   R restart", 13, DIM)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(l)


func _build_death() -> void:
	_death = ColorRect.new()
	(_death as ColorRect).color = Color(0.35, 0, 0, 0.55)
	_death.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.visible = false
	var l := _label("YOU DIED\npress R to restart", 40, TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death.add_child(l)
	add_child(_death)
