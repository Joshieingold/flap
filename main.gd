extends Node2D
# Attach to the root Node2D.

const SAVE_PATH := "user://flappy.cfg"
@export var Minecraft: Font
@export var pipe_speed := 250.0
@export var spawn_interval := 1.7
@export var gap_variation := 200.0   # how far the gap can move up/down from where you placed it

@onready var bird = $Bird
@onready var pause_button = $PauseButton
@onready var death_zone = $DeathZone

var score := 0
var best := 0
var playing := false
var dead := false

var _pipe_template: Node
var _template_y := 0.0
var _template_offset := 0.0
var _spawn_timer: Timer
var _score_label: Label
var _message_label: Label
var _can_restart := false
var _death_boxes: Array[Rect2] = []


func _ready() -> void:
	_load_best()
	_build_ui()

	# Use the Pipe you already built as a template, then remove it from the scene
	var pipe_node = $Pipe
	_template_offset = pipe_node.center_offset()
	_template_y = pipe_node.position.y
	_pipe_template = pipe_node.duplicate()
	pipe_node.free()

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_spawn_pipe)
	add_child(_spawn_timer)

	bird.flapped.connect(_on_bird_flapped)

	var bottom_box = death_zone.get_node_or_null("BottomDeathBox")
	if bottom_box:
		bird.floor_y = bottom_box.global_position.y - 40.0

	_collect_death_boxes()

	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.focus_mode = Control.FOCUS_NONE   # so space doesn't "press" it
	pause_button.pressed.connect(_toggle_pause)

	_refresh_message()


func _process(_delta: float) -> void:
	if not playing or dead:
		return
	for pipe in get_tree().get_nodes_in_group("pipes"):
		if not pipe.scored and pipe.center_x() < bird.center().x:
			pipe.scored = true
			score += 1
			_score_label.text = str(score)


func _unhandled_input(event: InputEvent) -> void:
	if dead and _can_restart and event.is_action_pressed("flap"):
		get_tree().reload_current_scene()


func _on_bird_flapped() -> void:
	if playing:
		return
	playing = true
	_spawn_pipe()
	_spawn_timer.start()
	_refresh_message()


func _spawn_pipe() -> void:
	if dead:
		return
	var pipe = _pipe_template.duplicate()
	var x := get_viewport_rect().size.x + 150.0 - _template_offset
	pipe.position = Vector2(x, _template_y + randf_range(-gap_variation, gap_variation))
	add_child(pipe)
	# Draw pipes behind the ground overlay
	move_child(pipe, $GroundOverlay.get_index())
	pipe.add_to_group("pipes")
	pipe.setup(pipe_speed)
	pipe.hit.connect(_game_over)


# Reads the rectangles of the DeathZone's shapes (works for any node type)
func _collect_death_boxes() -> void:
	for node in death_zone.find_children("*", "CollisionShape2D", true, false):
		if node.shape is RectangleShape2D:
			var size: Vector2 = node.shape.size * node.global_scale.abs()
			_death_boxes.append(Rect2(node.global_position - size * 0.5, size))
	if _death_boxes.is_empty():
		push_warning("No rectangle shapes found under DeathZone.")


func _physics_process(_delta: float) -> void:
	if not playing or dead:
		return
	var r: Rect2 = bird.hit_rect()
	var mid_y := get_viewport_rect().size.y * 0.5
	for box in _death_boxes:
		var is_ceiling := box.get_center().y < mid_y
		# Dies on touching the box, or if it somehow got past it
		if (is_ceiling and r.position.y < box.end.y) or (not is_ceiling and r.end.y > box.position.y):
			_game_over()
			return


func _game_over() -> void:
	if dead:
		return
	dead = true
	_spawn_timer.stop()
	bird.die()
	for pipe in get_tree().get_nodes_in_group("pipes"):
		pipe.running = false
	if score > best:
		best = score
		_save_best()
	_refresh_message()
	await get_tree().create_timer(0.5).timeout
	_can_restart = true


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_refresh_message()


# ---------- UI (built in code so you don't have to add nodes) ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_score_label = _make_label(120)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_top = 110
	_score_label.offset_bottom = 290
	_score_label.text = "0"
	layer.add_child(_score_label)

	_message_label = _make_label(64)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_message_label)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", font_size / 6)
	if Minecraft:
		label.add_theme_font_override("font", Minecraft)
	return label


func _refresh_message() -> void:
	if get_tree().paused:
		_message_label.text = "PAUSED"
	elif dead:
		_message_label.text = "GAME OVER\nScore: %d\nBest: %d\n\nTap to retry" % [score, best]
	elif not playing:
		_message_label.text = "TAP TO FLAP"
	else:
		_message_label.text = ""


# ---------- High score ----------

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = cfg.get_value("score", "best", 0)


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.save(SAVE_PATH)
