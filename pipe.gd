extends Node2D
# Attach to the "Pipe" root node (Node2D or Area2D both work).
# Hitboxes are generated from the Sprite2D sizes, so you don't need
# to set up collision shapes for the top/bottom pipes yourself.

signal hit

var speed := 250.0
var running := false
var scored := false

var _center_offset := 0.0


# Horizontal offset of the pipe sprites' center from this node's origin
func center_offset() -> float:
	var sprites := find_children("*", "Sprite2D", true, false)
	if sprites.is_empty():
		return 0.0
	var first: Sprite2D = sprites[0]
	return to_local(first.to_global(first.get_rect().get_center())).x


# World x of the pipe's center (used for scoring and despawning)
func center_x() -> float:
	return global_position.x + _center_offset


# Called by main.gd right after the pipe is added to the scene
func setup(p_speed: float) -> void:
	speed = p_speed
	_center_offset = center_offset()
	for sprite in find_children("*", "Sprite2D", true, false):
		_add_hitbox(sprite)
	running = true


func _add_hitbox(sprite: Sprite2D) -> void:
	var rect := sprite.get_rect()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	var area := Area2D.new()
	area.add_child(collider)
	sprite.add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		hit.emit()


func _physics_process(delta: float) -> void:
	if not running:
		return
	position.x -= speed * delta
	if center_x() < -200.0:
		queue_free()
