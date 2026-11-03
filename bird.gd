extends CharacterBody2D

signal flapped

enum State { READY, PLAYING, DEAD }

@export var gravity := 2400.0
@export var flap_velocity := -780.0
@export var max_fall_speed := 1500.0

var state := State.READY
var floor_y := 1.0e9   # set by main.gd; the dead bird stops falling here

var _start_y := 0.0
var _time := 0.0
var _flap_queued := false

@onready var sprite: Node2D = $BirdSprite
@onready var body_shape: CollisionShape2D = $BirdCollision


func _ready() -> void:
	_start_y = position.y
	_ensure_flap_action()


# Registers a "flap" input action (space / left click) if you haven't made one
func _ensure_flap_action() -> void:
	if InputMap.has_action("flap"):
		return
	InputMap.add_action("flap")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("flap", key)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("flap", click)


# Unhandled input, so clicking the pause button doesn't also make the bird flap
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flap"):
		_flap_queued = true


func _physics_process(delta: float) -> void:
	match state:
		State.READY:
			_time += delta
			position.y = _start_y + sin(_time * 5.0) * 12.0
			if _flap_queued:
				state = State.PLAYING
				_flap()
		State.PLAYING:
			if _flap_queued:
				_flap()
			_fall(delta)
			sprite.rotation = clampf(velocity.y / 900.0, -0.45, 1.3)
		State.DEAD:
			if center().y < floor_y:
				_fall(delta)
				sprite.rotation = clampf(velocity.y / 900.0, -0.45, 1.3)
				if center().y >= floor_y:
					position.y -= center().y - floor_y
					velocity = Vector2.ZERO
	_flap_queued = false


# Where the bird visually is, regardless of where the Bird node's origin sits
func center() -> Vector2:
	return body_shape.global_position


# World-space rectangle covering the bird's collision shape
func hit_rect() -> Rect2:
	var half := Vector2(30, 30)
	var shape = body_shape.shape
	if shape is RectangleShape2D:
		half = shape.size * 0.5
	elif shape is CircleShape2D:
		half = Vector2.ONE * shape.radius
	elif shape is CapsuleShape2D:
		half = Vector2(shape.radius, shape.height * 0.5)
	half *= body_shape.global_scale.abs()
	return Rect2(center() - half, half * 2.0)


func _flap() -> void:
	velocity.y = flap_velocity
	flapped.emit()


func _fall(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	position.y += velocity.y * delta


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity.y = maxf(velocity.y, 0.0)
