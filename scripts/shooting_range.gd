extends Node3D

const MOVE_SPEED := 5.2
const AIM_MIN_DISTANCE := 0.75
const SNAP_THROW_TIME := 0.48
const SNAP_THROW_SPEED := 14.0
const SNAP_EXPLOSION_RADIUS := 1.8
const CRACKER_THROW_TIME := 0.75
const CRACKER_THROW_SPEED := 10.0
const CRACKER_FUSE_TIME := 5.0
const CRACKER_EXPLOSION_RADIUS := 2.8
const THROW_COOLDOWN := 0.55
const CAMERA_OFFSET := Vector3(-12.0, 14.0, 12.0)

const WEAPON_SNAP := "snap"
const WEAPON_CRACKER := "cracker"

var player: CharacterBody3D
var camera: Camera3D
var crosshair: MeshInstance3D
var aim_line: MeshInstance3D
var weapon_label: Label
var status_label: Label
var hint_label: Label

var current_weapon := WEAPON_SNAP
var aim_direction := Vector3.FORWARD
var aim_point := Vector3.ZERO
var cracker_lit := false
var cracker_fuse := 0.0
var throw_cooldown := 0.0

var targets: Array[Node3D] = []
var projectiles: Array[Dictionary] = []
var explosions: Array[Dictionary] = []


func _ready() -> void:
	_build_lighting()
	_build_range()
	_build_player()
	_build_camera()
	_build_aim_helpers()
	_build_ui()
	_select_weapon(WEAPON_SNAP)


func _process(delta: float) -> void:
	_update_mouse_aim()
	_update_camera()
	_update_aim_helpers()
	_update_cracker_fuse(delta)
	_update_projectiles(delta)
	_update_explosions(delta)
	_update_ui()

	if throw_cooldown > 0.0:
		throw_cooldown = maxf(0.0, throw_cooldown - delta)


func _physics_process(_delta: float) -> void:
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
	player.velocity = direction * MOVE_SPEED
	player.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif key_event.keycode == KEY_1:
			_select_weapon(WEAPON_SNAP)
		elif key_event.keycode == KEY_2:
			_select_weapon(WEAPON_CRACKER)

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_throw_current_weapon()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_try_light_current_weapon()


func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.32, 0.34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.72)
	env.ambient_light_energy = 1.15
	env.tonemap_exposure = 1.08
	env.tonemap_white = 1.25
	environment.environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.name = "RangeLight"
	light.light_color = Color(1.0, 0.82, 0.58)
	light.light_energy = 1.8
	light.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	add_child(light)


func _build_range() -> void:
	var world := Node3D.new()
	world.name = "ShootingRangeWhitebox"
	add_child(world)

	_add_floor(world, "RangeFloor", Vector3.ZERO, Vector3(28.0, 0.12, 24.0), Color(0.48, 0.50, 0.47))
	_add_solid_box(world, "NorthWall", Vector3(0.0, 1.0, -12.0), Vector3(28.0, 2.0, 0.35), Color(0.25, 0.26, 0.27))
	_add_solid_box(world, "SouthWall", Vector3(0.0, 1.0, 12.0), Vector3(28.0, 2.0, 0.35), Color(0.25, 0.26, 0.27))
	_add_solid_box(world, "WestWall", Vector3(-14.0, 1.0, 0.0), Vector3(0.35, 2.0, 24.0), Color(0.25, 0.26, 0.27))
	_add_solid_box(world, "EastWall", Vector3(14.0, 1.0, 0.0), Vector3(0.35, 2.0, 24.0), Color(0.25, 0.26, 0.27))

	_add_solid_box(world, "Obstacle", Vector3(2.8, 0.65, -2.2), Vector3(2.2, 1.3, 2.2), Color(0.38, 0.38, 0.36))
	_add_solid_box(world, "LowBarrier", Vector3(-4.8, 0.45, -2.8), Vector3(3.4, 0.9, 0.75), Color(0.36, 0.34, 0.31))

	_add_target(world, "T1", Vector3(-4.0, 0.75, -5.8))
	_add_target(world, "T2", Vector3(4.5, 0.75, -8.4))
	_add_target(world, "T3", Vector3(-6.4, 0.75, 5.2))
	_add_target(world, "T4", Vector3(6.8, 0.75, 1.7))


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(-3.0, 0.72, 4.0)
	player.collision_layer = 1
	player.collision_mask = 1
	add_child(player)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	collision.shape = capsule
	player.add_child(collision)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.4
	body.mesh = capsule_mesh
	body.set_surface_override_material(0, _material(Color(0.13, 0.70, 0.82)))
	player.add_child(body)

	var nose := MeshInstance3D.new()
	nose.name = "FacingMarker"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.18, 0.16, 0.62)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 0.2, -0.55)
	nose.set_surface_override_material(0, _material(Color(1.0, 0.78, 0.22)))
	player.add_child(nose)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ShootingCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	_update_camera()
	camera.look_at(player.global_position, Vector3.UP)
	camera.current = true


func _build_aim_helpers() -> void:
	crosshair = MeshInstance3D.new()
	crosshair.name = "MouseCrosshair"
	var cross_mesh := CylinderMesh.new()
	cross_mesh.top_radius = 0.22
	cross_mesh.bottom_radius = 0.22
	cross_mesh.height = 0.035
	cross_mesh.radial_segments = 24
	crosshair.mesh = cross_mesh
	crosshair.set_surface_override_material(0, _material(Color(1.0, 0.86, 0.22)))
	add_child(crosshair)

	aim_line = MeshInstance3D.new()
	aim_line.name = "AimLine"
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.055, 0.045, 1.0)
	aim_line.mesh = line_mesh
	aim_line.set_surface_override_material(0, _material(Color(1.0, 0.86, 0.22, 0.45)))
	add_child(aim_line)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	weapon_label = Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.position = Vector2(24, 22)
	weapon_label.add_theme_font_size_override("font_size", 24)
	weapon_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	canvas.add_child(weapon_label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(24, 56)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.80, 1.0, 0.84))
	canvas.add_child(status_label)

	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.position = Vector2(24, 92)
	hint_label.text = "WASD 移动  鼠标瞄准  左键投掷  右键点火  1 摔炮  2 擦炮"
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.86))
	canvas.add_child(hint_label)


func _update_camera() -> void:
	if camera == null or player == null:
		return

	camera.global_position = player.global_position + CAMERA_OFFSET


func _get_screen_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length_squared() <= 0.0:
		return Vector3.ZERO

	var current_camera := get_viewport().get_camera_3d()
	if current_camera == null:
		return Vector3(input_vector.x, 0.0, -input_vector.y).normalized()

	var camera_right := current_camera.global_transform.basis.x
	var screen_right := Vector3(camera_right.x, 0.0, camera_right.z)
	if screen_right.length_squared() <= 0.0001:
		screen_right = Vector3.RIGHT
	else:
		screen_right = screen_right.normalized()

	var camera_up := current_camera.global_transform.basis.y
	var screen_up := Vector3(camera_up.x, 0.0, camera_up.z)
	if screen_up.length_squared() <= 0.0001:
		var camera_forward := -current_camera.global_transform.basis.z
		screen_up = Vector3(camera_forward.x, 0.0, camera_forward.z)
	else:
		screen_up = screen_up.normalized()

	var normalized_input := input_vector.normalized()
	return (screen_right * normalized_input.x + screen_up * normalized_input.y).normalized()


func _update_mouse_aim() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	if absf(ray_dir.y) < 0.001:
		return

	var t := -ray_origin.y / ray_dir.y
	var hit := ray_origin + ray_dir * t
	aim_point = Vector3(hit.x, 0.03, hit.z)

	var flat_delta := Vector3(aim_point.x - player.global_position.x, 0.0, aim_point.z - player.global_position.z)
	if flat_delta.length() >= AIM_MIN_DISTANCE:
		aim_direction = flat_delta.normalized()
		player.look_at(player.global_position + aim_direction, Vector3.UP)


func _update_aim_helpers() -> void:
	crosshair.global_position = aim_point

	var start := player.global_position + Vector3(0.0, 0.05, 0.0)
	var end := Vector3(aim_point.x, 0.08, aim_point.z)
	var delta := end - start
	delta.y = 0.0
	var length := delta.length()
	if length < 0.1:
		aim_line.visible = false
		return

	aim_line.visible = true
	aim_line.global_position = start + delta * 0.5
	var mesh := aim_line.mesh as BoxMesh
	mesh.size = Vector3(0.055, 0.045, length)
	aim_line.rotation = Vector3.ZERO
	aim_line.rotation.y = atan2(delta.x, delta.z)


func _update_cracker_fuse(delta: float) -> void:
	if not cracker_lit:
		return

	cracker_fuse -= delta
	if cracker_fuse <= 0.0:
		cracker_lit = false
		_create_explosion(player.global_position, CRACKER_EXPLOSION_RADIUS)
		_show_hint("擦炮在手边炸了。")


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[i]
		var node := projectile["node"] as Node3D
		projectile["age"] = float(projectile["age"]) + delta

		if bool(projectile["moving"]):
			var velocity := projectile["velocity"] as Vector3
			node.global_position += velocity * delta
			var flight_time := float(projectile["flight_time"])
			var progress := clampf(float(projectile["age"]) / flight_time, 0.0, 1.0)
			node.global_position.y = 0.18 + sin(progress * PI) * float(projectile["arc_height"])
			if progress >= 1.0:
				projectile["moving"] = false
				node.global_position.y = 0.18

		projectile["fuse"] = float(projectile["fuse"]) - delta
		if float(projectile["fuse"]) <= 0.0:
			_create_explosion(node.global_position, float(projectile["radius"]))
			node.queue_free()
			projectiles.remove_at(i)


func _update_explosions(delta: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var explosion := explosions[i]
		explosion["time"] = float(explosion["time"]) - delta
		var marker := explosion["node"] as Node3D
		if float(explosion["time"]) <= 0.0:
			marker.queue_free()
			explosions.remove_at(i)


func _select_weapon(weapon: String) -> void:
	current_weapon = weapon
	cracker_lit = false
	cracker_fuse = 0.0
	if current_weapon == WEAPON_SNAP:
		_show_hint("当前武器：摔炮")
	else:
		_show_hint("当前武器：擦炮")


func _try_light_current_weapon() -> void:
	if current_weapon == WEAPON_SNAP:
		_show_hint("摔炮不用点。")
		return

	if cracker_lit:
		_show_hint("擦炮已经点着了。")
		return

	cracker_lit = true
	cracker_fuse = CRACKER_FUSE_TIME
	_show_hint("点着了。")


func _try_throw_current_weapon() -> void:
	if throw_cooldown > 0.0:
		return

	if current_weapon == WEAPON_SNAP:
		_throw_projectile(WEAPON_SNAP, SNAP_THROW_SPEED, SNAP_THROW_TIME, SNAP_THROW_TIME, SNAP_EXPLOSION_RADIUS, 1.05, Color(0.92, 0.20, 0.16))
		throw_cooldown = THROW_COOLDOWN
		return

	if not cracker_lit:
		_show_hint("还没点着。")
		return

	_throw_projectile(WEAPON_CRACKER, CRACKER_THROW_SPEED, CRACKER_THROW_TIME, cracker_fuse, CRACKER_EXPLOSION_RADIUS, 1.25, Color(0.62, 0.62, 0.58))
	cracker_lit = false
	cracker_fuse = 0.0
	throw_cooldown = THROW_COOLDOWN


func _throw_projectile(kind: String, speed: float, flight_time: float, fuse: float, radius: float, arc_height: float, color: Color) -> void:
	var projectile := Node3D.new()
	projectile.name = "Projectile_%s" % kind
	add_child(projectile)
	projectile.global_position = player.global_position + aim_direction * 0.8 + Vector3(0.0, 0.18, 0.0)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.22, 0.22)
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(color))
	projectile.add_child(mesh_instance)

	projectiles.append({
		"node": projectile,
		"velocity": aim_direction * speed,
		"age": 0.0,
		"flight_time": flight_time,
		"fuse": fuse,
		"radius": radius,
		"arc_height": arc_height,
		"moving": true,
	})


func _create_explosion(world_position: Vector3, radius: float) -> void:
	var marker := Node3D.new()
	marker.name = "Explosion"
	add_child(marker)
	marker.global_position = Vector3(world_position.x, 0.08, world_position.z)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	mesh.radial_segments = 36
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(Color(1.0, 0.70, 0.18, 0.7)))
	marker.add_child(mesh_instance)

	explosions.append({
		"node": marker,
		"time": 0.32,
	})
	_hit_targets(world_position, radius)


func _hit_targets(world_position: Vector3, radius: float) -> void:
	for target in targets:
		if bool(target.get_meta("hit", false)):
			continue
		var distance := Vector2(target.global_position.x - world_position.x, target.global_position.z - world_position.z).length()
		if distance <= radius:
			target.set_meta("hit", true)
			var mesh := target.get_node_or_null("Mesh") as MeshInstance3D
			if mesh != null:
				mesh.set_surface_override_material(0, _material(Color(0.95, 0.18, 0.12)))
			_add_label(target, "命中", Vector3(0.0, 1.2, 0.0))
			_show_hint("命中")


func _update_ui() -> void:
	weapon_label.text = "当前武器：%s" % ("摔炮" if current_weapon == WEAPON_SNAP else "擦炮")
	if current_weapon == WEAPON_CRACKER:
		if cracker_lit:
			status_label.text = "点火状态：已点燃  倒计时：%.1f" % maxf(cracker_fuse, 0.0)
		else:
			status_label.text = "点火状态：未点火"
	else:
		status_label.text = "点火状态：不需要点火"


func _show_hint(text: String) -> void:
	hint_label.text = text


func _add_target(parent: Node, target_name: String, pos: Vector3) -> Node3D:
	var target := StaticBody3D.new()
	target.name = target_name
	target.position = pos
	target.set_meta("hit", false)
	parent.add_child(target)
	targets.append(target)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 1.5
	mesh.radial_segments = 16
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(Color(0.88, 0.84, 0.70)))
	target.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 1.5
	collision.shape = shape
	target.add_child(collision)

	_add_label(target, target_name, Vector3(0.0, 1.05, 0.0))
	return target


func _add_floor(parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = node_name
	floor_mesh.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	floor_mesh.mesh = mesh
	floor_mesh.set_surface_override_material(0, _material(color))
	parent.add_child(floor_mesh)
	return floor_mesh


func _add_solid_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(color))
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_label(parent: Node3D, text: String, local_pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = local_pos
	label.font_size = 30
	label.modulate = Color(1.0, 1.0, 1.0)
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat
