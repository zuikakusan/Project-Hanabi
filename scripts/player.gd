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
	if Input.is_key_pressed(KEY_W):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1.0

	var direction := _get_screen_relative_direction(input_vector)
	velocity = direction * move_speed

	if direction.length_squared() > 0.0:
		_last_direction = direction
		look_at(global_position + _last_direction, Vector3.UP)

	move_and_slide()


func _get_screen_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length_squared() <= 0.0:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_vector.x, 0.0, -input_vector.y).normalized()

	var camera_right := camera.global_transform.basis.x
	var screen_right := Vector3(camera_right.x, 0.0, camera_right.z)
	if screen_right.length_squared() <= 0.0001:
		screen_right = Vector3.RIGHT
	else:
		screen_right = screen_right.normalized()

	var camera_up := camera.global_transform.basis.y
	var screen_up := Vector3(camera_up.x, 0.0, camera_up.z)
	if screen_up.length_squared() <= 0.0001:
		var camera_forward := -camera.global_transform.basis.z
		screen_up = Vector3(camera_forward.x, 0.0, camera_forward.z)
	else:
		screen_up = screen_up.normalized()

	var normalized_input := input_vector.normalized()
	return (screen_right * normalized_input.x + screen_up * normalized_input.y).normalized()
