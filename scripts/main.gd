extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")

const INTERACT_RANGE := 1.8
const EXIT_RANGE := 2.3

var has_read_note_x := false
var door_b_open := false
var has_key_door_a := false
var cabinet_a_searched := false
var door_a_open := false
var demo_finished := false

var player: CharacterBody3D
var camera: Camera3D
var prompt_label: Label
var message_panel: PanelContainer
var message_label: Label
var current_interactable: Node3D
var message_open := false
var camera_offset := Vector3(0.0, 15.0, 12.0)


func _ready() -> void:
	_build_lighting()
	_build_level()
	_build_player()
	_build_camera()
	_build_ui()


func _process(delta: float) -> void:
	_update_camera(delta)

	if demo_finished:
		prompt_label.visible = false
		return

	if not message_open:
		_update_current_interactable()
		_check_exit_trigger()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		get_tree().quit()
		return

	if message_open:
		if key_event.keycode == KEY_E or key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER:
			_hide_message()
		return

	if key_event.keycode == KEY_E and current_interactable != null:
		_interact_with(current_interactable)


func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.ambient_light_energy = 0.85
	environment.environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.light_energy = 2.0
	light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	add_child(light)


func _build_level() -> void:
	var world := Node3D.new()
	world.name = "WhiteboxMap"
	add_child(world)

	_add_floor(world, "RoomB_Floor", Vector3(0.0, -0.06, 8.0), Vector3(10.0, 0.12, 8.0), Color(0.42, 0.43, 0.43))
	_add_floor(world, "RoomA_Floor", Vector3(0.0, -0.06, 0.0), Vector3(10.0, 0.12, 7.0), Color(0.36, 0.37, 0.38))
	_add_floor(world, "Outdoor_Floor", Vector3(0.0, -0.06, -7.0), Vector3(10.0, 0.12, 6.0), Color(0.28, 0.42, 0.30))

	_build_walls(world)
	_add_door(world, "DoorB", "obj_door_b", Vector3(3.5, 1.0, 3.75), Vector3(1.8, 2.0, 0.35), Color(0.18, 0.38, 0.95))
	_add_door(world, "DoorA", "obj_door_a", Vector3(3.5, 1.0, -3.75), Vector3(1.8, 2.0, 0.35), Color(0.95, 0.28, 0.12))

	_add_note(world)
	_add_cabinet(world)
	_add_exit(world)


func _build_walls(parent: Node) -> void:
	var wall_color := Color(0.16, 0.16, 0.17)

	_add_solid_box(parent, "RoomB_TopWall", Vector3(0.0, 1.0, 12.0), Vector3(10.3, 2.0, 0.35), wall_color)
	_add_solid_box(parent, "RoomB_LeftWall", Vector3(-5.0, 1.0, 8.0), Vector3(0.35, 2.0, 8.3), wall_color)
	_add_solid_box(parent, "RoomB_RightWall", Vector3(5.0, 1.0, 8.0), Vector3(0.35, 2.0, 8.3), wall_color)
	_add_solid_box(parent, "RoomB_BottomWall_Left", Vector3(-1.2, 1.0, 4.0), Vector3(7.6, 2.0, 0.35), wall_color)
	_add_solid_box(parent, "RoomB_BottomWall_Right", Vector3(4.7, 1.0, 4.0), Vector3(0.6, 2.0, 0.35), wall_color)

	_add_solid_box(parent, "RoomA_LeftWall", Vector3(-5.0, 1.0, 0.0), Vector3(0.35, 2.0, 7.3), wall_color)
	_add_solid_box(parent, "RoomA_RightWall", Vector3(5.0, 1.0, 0.0), Vector3(0.35, 2.0, 7.3), wall_color)
	_add_solid_box(parent, "RoomA_TopWall_Left", Vector3(-1.2, 1.0, 3.5), Vector3(7.6, 2.0, 0.35), wall_color)
	_add_solid_box(parent, "RoomA_TopWall_Right", Vector3(4.7, 1.0, 3.5), Vector3(0.6, 2.0, 0.35), wall_color)
	_add_solid_box(parent, "RoomA_BottomWall_Left", Vector3(-1.2, 1.0, -3.5), Vector3(7.6, 2.0, 0.35), wall_color)
	_add_solid_box(parent, "RoomA_BottomWall_Right", Vector3(4.7, 1.0, -3.5), Vector3(0.6, 2.0, 0.35), wall_color)

	_add_solid_box(parent, "Outdoor_LeftBoundary", Vector3(-5.0, 1.0, -7.0), Vector3(0.35, 2.0, 6.3), wall_color)
	_add_solid_box(parent, "Outdoor_RightBoundary", Vector3(5.0, 1.0, -7.0), Vector3(0.35, 2.0, 6.3), wall_color)
	_add_solid_box(parent, "Outdoor_Top_Left", Vector3(-1.2, 1.0, -4.0), Vector3(7.6, 2.0, 0.35), wall_color)
	_add_solid_box(parent, "Outdoor_Top_Right", Vector3(4.7, 1.0, -4.0), Vector3(0.6, 2.0, 0.35), wall_color)
	_add_solid_box(parent, "Outdoor_BottomBoundary", Vector3(0.0, 1.0, -10.0), Vector3(10.3, 2.0, 0.35), wall_color)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(-3.0, 0.72, 10.0)
	player.collision_layer = 1
	player.collision_mask = 1
	add_child(player)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.4

	var collision := CollisionShape3D.new()
	collision.shape = capsule
	player.add_child(collision)

	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.4
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Body"
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(Color(0.0, 0.85, 0.95)))
	player.add_child(mesh_instance)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "TopDownCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.near = 0.1
	camera.far = 100.0
	camera.position = player.position + camera_offset
	add_child(camera)
	camera.look_at(player.global_position, Vector3.UP)
	camera.current = true


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	prompt_label = Label.new()
	prompt_label.name = "InteractPrompt"
	prompt_label.text = "按 E 互动"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 26)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	prompt_label.anchor_left = 0.0
	prompt_label.anchor_right = 1.0
	prompt_label.anchor_top = 0.82
	prompt_label.anchor_bottom = 0.90
	prompt_label.visible = false
	canvas.add_child(prompt_label)

	message_panel = PanelContainer.new()
	message_panel.name = "MessagePanel"
	message_panel.anchor_left = 0.18
	message_panel.anchor_right = 0.82
	message_panel.anchor_top = 0.72
	message_panel.anchor_bottom = 0.94
	message_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.06, 0.88)
	panel_style.border_color = Color(0.78, 0.74, 0.62)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	message_panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(message_panel)

	message_label = Label.new()
	message_label.name = "MessageText"
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.86))
	message_panel.add_child(message_label)


func _add_note(parent: Node) -> void:
	var note := Node3D.new()
	note.name = "NoteX"
	note.position = Vector3(0.0, 0.05, 8.0)
	note.set_meta("interact_id", "obj_note_x")
	note.add_to_group("interactable")
	parent.add_child(note)

	var mesh := MeshInstance3D.new()
	mesh.name = "Paper"
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.08, 0.65)
	mesh.mesh = box
	mesh.set_surface_override_material(0, _material(Color(0.95, 0.93, 0.82)))
	note.add_child(mesh)
	_add_label(note, "纸条 X", Vector3(0.0, 0.55, 0.0))


func _add_cabinet(parent: Node) -> void:
	var cabinet := _add_solid_box(parent, "CabinetA", Vector3(-3.5, 0.5, 0.5), Vector3(1.2, 1.0, 0.8), Color(0.45, 0.26, 0.12))
	cabinet.set_meta("interact_id", "obj_cabinet_a")
	cabinet.add_to_group("interactable")
	_add_label(cabinet, "柜子", Vector3(0.0, 0.9, 0.0))


func _add_exit(parent: Node) -> void:
	var exit := Node3D.new()
	exit.name = "ExitEnd"
	exit.position = Vector3(0.0, 0.02, -8.0)
	parent.add_child(exit)

	var mesh := MeshInstance3D.new()
	mesh.name = "ExitMarker"
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.05, 2.0)
	mesh.mesh = box
	mesh.set_surface_override_material(0, _material(Color(0.2, 0.95, 0.35)))
	exit.add_child(mesh)
	_add_label(exit, "END", Vector3(0.0, 0.65, 0.0))


func _add_door(parent: Node, door_name: String, interact_id: String, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var door := Node3D.new()
	door.name = door_name
	door.position = pos
	door.set_meta("interact_id", interact_id)
	door.add_to_group("interactable")
	parent.add_child(door)

	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 1
	door.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(color))
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var label_text := "门 B" if door_name == "DoorB" else "门 A"
	_add_label(door, label_text, Vector3(0.0, 1.45, 0.0))
	return door


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
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_label(parent: Node3D, text: String, local_pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = local_pos
	label.font_size = 32
	label.modulate = Color(1.0, 1.0, 1.0)
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _update_camera(delta: float) -> void:
	if player == null or camera == null:
		return

	var target_pos := player.global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target_pos, clampf(delta * 7.0, 0.0, 1.0))
	camera.look_at(player.global_position, Vector3.UP)


func _update_current_interactable() -> void:
	var nearest: Node3D = null
	var nearest_distance := INTERACT_RANGE

	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D):
			continue
		var interactable := node as Node3D
		if _is_open_door(interactable):
			continue
		var distance := player.global_position.distance_to(interactable.global_position)
		if distance <= nearest_distance:
			nearest = interactable
			nearest_distance = distance

	current_interactable = nearest
	prompt_label.visible = current_interactable != null


func _check_exit_trigger() -> void:
	if door_a_open and player.global_position.distance_to(Vector3(0.0, 0.0, -8.0)) <= EXIT_RANGE:
		demo_finished = true
		_show_message("Demo 结束。")


func _interact_with(interactable: Node3D) -> void:
	var interact_id := String(interactable.get_meta("interact_id", ""))
	match interact_id:
		"obj_note_x":
			has_read_note_x = true
			_show_message("纸条上写着：\n离开房间。")
		"obj_door_b":
			_handle_door_b(interactable)
		"obj_cabinet_a":
			_handle_cabinet(interactable)
		"obj_door_a":
			_handle_door_a(interactable)


func _handle_door_b(door: Node3D) -> void:
	if door_b_open:
		_show_message("门已经打开了。")
	elif not has_read_note_x:
		_show_message("门像是能打开，但你还没有想好要去哪。")
	else:
		door_b_open = true
		_open_door(door)
		_show_message("门打开了。")


func _handle_cabinet(cabinet: Node3D) -> void:
	if cabinet_a_searched:
		_show_message("柜子是空的。")
	else:
		cabinet_a_searched = true
		has_key_door_a = true
		var mesh := cabinet.get_node_or_null("Mesh") as MeshInstance3D
		if mesh != null:
			mesh.set_surface_override_material(0, _material(Color(0.58, 0.39, 0.22)))
		_show_message("柜子里有一把钥匙。")


func _handle_door_a(door: Node3D) -> void:
	if door_a_open:
		_show_message("门已经打开了。")
	elif not has_key_door_a:
		_show_message("门上锁了。")
	else:
		door_a_open = true
		_open_door(door)
		_show_message("试着用刚才的钥匙，结果门打开了。")


func _open_door(door: Node3D) -> void:
	var mesh := door.get_node_or_null("Body/Mesh") as MeshInstance3D
	var collision := door.get_node_or_null("Body/Collision") as CollisionShape3D
	if mesh != null:
		mesh.visible = false
	if collision != null:
		collision.set_deferred("disabled", true)
	door.remove_from_group("interactable")


func _is_open_door(interactable: Node3D) -> bool:
	var interact_id := String(interactable.get_meta("interact_id", ""))
	return (interact_id == "obj_door_b" and door_b_open) or (interact_id == "obj_door_a" and door_a_open)


func _show_message(text: String) -> void:
	message_open = true
	prompt_label.visible = false
	message_label.text = text
	message_panel.visible = true
	player.set("can_move", false)


func _hide_message() -> void:
	message_open = false
	message_panel.visible = false
	player.set("can_move", not demo_finished)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat
