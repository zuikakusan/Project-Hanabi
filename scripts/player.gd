extends CharacterBody3D

@export var move_speed: float = 4.6

var can_move := true
var _last_direction := Vector3.FORWARD


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0

	var direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	velocity = direction * move_speed

	if direction.length_squared() > 0.0:
		_last_direction = direction
		look_at(global_position + _last_direction, Vector3.UP)

	move_and_slide()
