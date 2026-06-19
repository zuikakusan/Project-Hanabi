extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")

const INTERACT_RANGE := 1.8
const EXIT_RANGE := 2.3

const COLOR_WALL := Color(0.42, 0.37, 0.27)
const COLOR_WALL_DARK := Color(0.26, 0.24, 0.21)
const COLOR_ROOM_B_FLOOR := Color(0.34, 0.33, 0.29)
const COLOR_ROOM_A_FLOOR := Color(0.31, 0.28, 0.24)
const COLOR_OUTDOOR_FLOOR := Color(0.48, 0.35, 0.22)
const COLOR_OLD_WOOD := Color(0.36, 0.22, 0.12)
const COLOR_DARK_WOOD := Color(0.24, 0.14, 0.08)
const COLOR_PAPER_YELLOW := Color(0.86, 0.78, 0.55)
const COLOR_DUSK_ORANGE := Color(1.0, 0.52, 0.18)
const COLOR_FLUORESCENT_GREEN := Color(0.28, 1.0, 0.25)

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
var end_overlay: ColorRect
var current_interactable: Node3D
var message_open := false
var camera_offset := Vector3(0.0, 15.0, 12.0)
var camera_focus_x := 0.0


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
	env.background_color = Color(0.24, 0.22, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.66, 0.48)
	env.ambient_light_energy = 0.55
	environment.environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.name = "DuskLight"
	light.light_color = Color(1.0, 0.66, 0.38)
	light.light_energy = 1.75
	light.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	add_child(light)


func _build_level() -> void:
	var world := Node3D.new()
	world.name = "WhiteboxMap"
	add_child(world)

	_add_floor(world, "RoomB_CementFloor", Vector3(0.0, -0.06, 8.0), Vector3(10.0, 0.12, 8.0), COLOR_ROOM_B_FLOOR)
	_add_floor(world, "RoomA_DirtyFloor", Vector3(0.0, -0.06, 0.0), Vector3(10.0, 0.12, 7.0), COLOR_ROOM_A_FLOOR)
	_add_floor(world, "Outdoor_DuskGround", Vector3(0.0, -0.06, -7.0), Vector3(10.0, 0.12, 6.0), COLOR_OUTDOOR_FLOOR)

	_build_walls(world)
	_add_door(world, "DoorB", "obj_door_b", Vector3(3.5, 1.0, 3.75), Vector3(1.8, 2.0, 0.35), COLOR_OLD_WOOD)
	_add_door(world, "DoorA", "obj_door_a", Vector3(3.5, 1.0, -3.75), Vector3(1.8, 2.0, 0.35), COLOR_DARK_WOOD)

	_add_note(world)
	_add_cabinet(world)
	_add_exit(world)
	_add_room_b_atmosphere(world)
	_add_room_a_atmosphere(world)
	_add_outdoor_atmosphere(world)


func _build_walls(parent: Node) -> void:
	var wall_color := COLOR_WALL

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

	_add_solid_box(parent, "Outdoor_LeftBoundary", Vector3(-5.0, 1.0, -7.0), Vector3(0.35, 2.0, 6.3), COLOR_WALL_DARK)
	_add_solid_box(parent, "Outdoor_RightBoundary", Vector3(5.0, 1.0, -7.0), Vector3(0.35, 2.0, 6.3), COLOR_WALL_DARK)
	_add_solid_box(parent, "Outdoor_Top_Left", Vector3(-1.2, 1.0, -4.0), Vector3(7.6, 2.0, 0.35), COLOR_WALL_DARK)
	_add_solid_box(parent, "Outdoor_Top_Right", Vector3(4.7, 1.0, -4.0), Vector3(0.6, 2.0, 0.35), COLOR_WALL_DARK)
	_add_solid_box(parent, "Outdoor_BottomBoundary", Vector3(0.0, 1.0, -10.0), Vector3(10.3, 2.0, 0.35), COLOR_WALL_DARK)


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
	mesh_instance.set_surface_override_material(0, _material(Color(0.18, 0.64, 0.68)))
	player.add_child(mesh_instance)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "TopDownCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.near = 0.1
	camera.far = 100.0
	var focus := _get_camera_focus()
	camera.position = focus + camera_offset
	add_child(camera)
	camera.look_at(focus, Vector3.UP)
	camera.current = true


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	end_overlay = ColorRect.new()
	end_overlay.name = "EndOverlay"
	end_overlay.color = Color(0.05, 0.04, 0.03, 0.42)
	end_overlay.anchor_right = 1.0
	end_overlay.anchor_bottom = 1.0
	end_overlay.visible = false
	canvas.add_child(end_overlay)

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
	mesh.set_surface_override_material(0, _material(COLOR_PAPER_YELLOW))
	note.add_child(mesh)

	var green_mark := MeshInstance3D.new()
	green_mark.name = "FluorescentMark"
	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(0.52, 0.025, 0.08)
	green_mark.mesh = mark_mesh
	green_mark.position = Vector3(0.08, 0.065, 0.18)
	green_mark.rotation_degrees.y = 18.0
	green_mark.set_surface_override_material(0, _emissive_material(COLOR_FLUORESCENT_GREEN, 0.75))
	note.add_child(green_mark)

	_add_label(note, "发黄纸条", Vector3(0.0, 0.55, 0.0))


func _add_cabinet(parent: Node) -> void:
	var cabinet := _add_solid_box(parent, "CabinetA", Vector3(-3.5, 0.5, 0.5), Vector3(1.2, 1.0, 0.8), COLOR_OLD_WOOD)
	cabinet.set_meta("interact_id", "obj_cabinet_a")
	cabinet.add_to_group("interactable")
	_add_floor(cabinet, "CabinetGreenCrack", Vector3(0.0, 0.18, -0.42), Vector3(0.72, 0.035, 0.035), COLOR_FLUORESCENT_GREEN)
	_add_label(cabinet, "旧木柜", Vector3(0.0, 0.9, 0.0))


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
	mesh.set_surface_override_material(0, _material(Color(0.92, 0.58, 0.2)))
	exit.add_child(mesh)
	_add_floor(exit, "FaintGreenEdgeNorth", Vector3(0.0, 0.055, 1.02), Vector3(3.1, 0.035, 0.08), COLOR_FLUORESCENT_GREEN)
	_add_floor(exit, "FaintGreenEdgeSouth", Vector3(0.0, 0.055, -1.02), Vector3(3.1, 0.035, 0.08), COLOR_FLUORESCENT_GREEN)
	_add_label(exit, "门外黄昏", Vector3(0.0, 0.65, 0.0))


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

	var label_text := "里屋门" if door_name == "DoorB" else "出口门"
	_add_label(door, label_text, Vector3(0.0, 1.45, 0.0))
	if door_name == "DoorA":
		_add_floor(door, "LockGreenGleam", Vector3(-0.55, 0.06, -0.2), Vector3(0.12, 0.12, 0.06), COLOR_FLUORESCENT_GREEN)
	return door


func _add_room_b_atmosphere(parent: Node) -> void:
	_add_floor(parent, "OldTableTop", Vector3(-3.6, 0.42, 7.15), Vector3(1.5, 0.12, 0.85), COLOR_DARK_WOOD)
	_add_floor(parent, "OldTableLegA", Vector3(-4.2, 0.18, 6.8), Vector3(0.12, 0.36, 0.12), COLOR_DARK_WOOD)
	_add_floor(parent, "OldTableLegB", Vector3(-3.0, 0.18, 7.5), Vector3(0.12, 0.36, 0.12), COLOR_DARK_WOOD)
	_add_label_marker(parent, "旧木桌", Vector3(-3.6, 0.88, 7.15))

	_add_floor(parent, "DirtyWindow", Vector3(-4.78, 1.25, 10.15), Vector3(0.08, 0.82, 1.45), Color(0.57, 0.61, 0.58))
	_add_floor(parent, "OldNewspaper", Vector3(1.95, 0.62, 11.78), Vector3(1.05, 0.78, 0.035), Color(0.74, 0.66, 0.47))
	_add_floor(parent, "RoomB_WastePaperA", Vector3(-1.8, 0.02, 6.1), Vector3(0.55, 0.035, 0.35), Color(0.62, 0.57, 0.46))
	_add_floor(parent, "RoomB_WastePaperB", Vector3(-2.35, 0.025, 6.35), Vector3(0.42, 0.035, 0.24), Color(0.55, 0.52, 0.43))
	_add_floor(parent, "RoomB_GreenChalkMark", Vector3(-4.78, 0.68, 5.75), Vector3(0.07, 0.58, 0.16), COLOR_FLUORESCENT_GREEN)


func _add_room_a_atmosphere(parent: Node) -> void:
	_add_floor(parent, "RoomA_DragMarkA", Vector3(-0.8, 0.015, -0.9), Vector3(2.6, 0.025, 0.16), Color(0.19, 0.16, 0.13))
	_add_floor(parent, "RoomA_DragMarkB", Vector3(-0.2, 0.016, -1.35), Vector3(1.8, 0.025, 0.12), Color(0.18, 0.15, 0.12))
	_add_floor(parent, "RoomA_WaterStain", Vector3(4.78, 0.72, 1.45), Vector3(0.07, 1.1, 0.62), Color(0.25, 0.22, 0.17))
	_add_floor(parent, "DoorA_DuskSeam", Vector3(3.5, 0.54, -3.93), Vector3(1.9, 0.06, 0.08), COLOR_DUSK_ORANGE)
	_add_floor(parent, "CabinetDustPatch", Vector3(-3.5, 0.02, 1.15), Vector3(1.7, 0.035, 0.58), Color(0.48, 0.45, 0.36))


func _add_outdoor_atmosphere(parent: Node) -> void:
	_add_floor(parent, "FadedRoad", Vector3(0.0, 0.015, -8.45), Vector3(2.3, 0.035, 3.0), Color(0.38, 0.34, 0.31))
	_add_floor(parent, "DistantWallLeft", Vector3(-3.1, 0.55, -9.72), Vector3(3.2, 1.1, 0.16), Color(0.22, 0.24, 0.25))
	_add_floor(parent, "DistantWallRight", Vector3(3.1, 0.55, -9.72), Vector3(3.2, 1.1, 0.16), Color(0.22, 0.24, 0.25))
	_add_floor(parent, "TreeShadowA", Vector3(-3.2, 0.02, -7.25), Vector3(1.2, 0.03, 0.28), Color(0.11, 0.18, 0.12))
	_add_floor(parent, "TreeShadowB", Vector3(2.4, 0.02, -6.6), Vector3(1.45, 0.03, 0.24), Color(0.1, 0.16, 0.12))
	_add_floor(parent, "RoadGreenCrack", Vector3(1.35, 0.04, -8.95), Vector3(0.75, 0.035, 0.06), COLOR_FLUORESCENT_GREEN)


func _add_label_marker(parent: Node, text: String, pos: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = text
	marker.position = pos
	parent.add_child(marker)
	_add_label(marker, text, Vector3.ZERO)


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

	var focus := _get_camera_focus()
	var target_pos := focus + camera_offset
	camera.global_position = camera.global_position.lerp(target_pos, clampf(delta * 7.0, 0.0, 1.0))
	camera.look_at(focus, Vector3.UP)


func _get_camera_focus() -> Vector3:
	return Vector3(camera_focus_x, player.global_position.y, player.global_position.z)


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
		end_overlay.visible = true
		_show_message("你走出了屋子。\n外面的天色不太对。")


func _interact_with(interactable: Node3D) -> void:
	var interact_id := String(interactable.get_meta("interact_id", ""))
	match interact_id:
		"obj_note_x":
			has_read_note_x = true
			_show_message("纸条上写着：\n别待在这个房间。")
		"obj_door_b":
			_handle_door_b(interactable)
		"obj_cabinet_a":
			_handle_cabinet(interactable)
		"obj_door_a":
			_handle_door_a(interactable)


func _handle_door_b(door: Node3D) -> void:
	if door_b_open:
		_show_message("里屋门已经开着。")
	elif not has_read_note_x:
		_show_message("门没有锁，但你突然不太想碰它。")
	else:
		door_b_open = true
		_open_door(door)
		_show_message("门轴响了一下。")


func _handle_cabinet(cabinet: Node3D) -> void:
	if cabinet_a_searched:
		_show_message("柜子里只剩一层灰。")
	else:
		cabinet_a_searched = true
		has_key_door_a = true
		var mesh := cabinet.get_node_or_null("Mesh") as MeshInstance3D
		if mesh != null:
			mesh.set_surface_override_material(0, _material(Color(0.44, 0.28, 0.16)))
		_show_message("柜子底下压着一把小钥匙。")


func _handle_door_a(door: Node3D) -> void:
	if door_a_open:
		_show_message("出口门已经开着。")
	elif not has_key_door_a:
		_show_message("门从另一边锁住了。")
	else:
		door_a_open = true
		_open_door(door)
		_show_message("钥匙转了一圈，门开了。")


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


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _material(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
