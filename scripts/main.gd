extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")

const INTERACT_RANGE := 1.8
const EXIT_RANGE := 2.3
const AIM_MIN_DISTANCE := 0.75
const SNAP_THROW_TIME := 0.48
const SNAP_THROW_SPEED := 14.0
const SNAP_EXPLOSION_RADIUS := 1.8
const CRACKER_THROW_TIME := 0.75
const CRACKER_THROW_SPEED := 10.0
const CRACKER_FUSE_TIME := 5.0
const CRACKER_EXPLOSION_RADIUS := 2.8
const THROW_COOLDOWN := 0.55
const THROW_GROUND_Y := 0.18
const THROW_RAY_HEIGHT := 0.35
const THROW_WALL_PADDING := 0.28
const THROW_MIN_FLIGHT_TIME := 0.12

const ITEM_NONE := ""
const ITEM_SNAP := "snap"
const ITEM_CRACKER := "cracker"
const SNAP_BOX_CAPACITY := 30
const CRACKER_BOX_CAPACITY := 25
const HAND_CAPACITY := 5

const COLOR_WALL := Color(0.055, 0.055, 0.06)
const COLOR_WALL_DARK := Color(0.035, 0.035, 0.04)
const COLOR_ROOM_B_FLOOR := Color(0.46, 0.46, 0.45)
const COLOR_ROOM_A_FLOOR := Color(0.40, 0.40, 0.39)
const COLOR_OUTDOOR_FLOOR := Color(0.28, 0.62, 0.25)
const COLOR_OLD_WOOD := Color(0.36, 0.22, 0.12)
const COLOR_DARK_WOOD := Color(0.24, 0.14, 0.08)
const COLOR_PAPER_YELLOW := Color(0.88, 0.82, 0.63)
const COLOR_DUSK_YELLOW := Color(1.0, 0.74, 0.38)
const COLOR_COOL_SHADOW := Color(0.24, 0.40, 0.38)
const COLOR_DIRTY_WHITE := Color(0.76, 0.75, 0.66)

var has_read_note_x := false
var door_b_open := false
var has_key_door_a := false
var cabinet_a_searched := false
var door_a_open := false
var demo_finished := false

var player: CharacterBody3D
var camera: Camera3D
var prompt_label: Label
var inventory_status_label: Label
var message_panel: PanelContainer
var message_label: Label
var end_overlay: ColorRect
var crosshair: MeshInstance3D
var aim_line: MeshInstance3D
var current_interactable: Node3D
var message_open := false
var camera_offset := Vector3(-9.0, 10.0, 9.0)
var room_a_reveal_nodes: Array[Node3D] = []
var outdoor_reveal_nodes: Array[Node3D] = []
var inventory_slot_names := ["手", "1 左裤袋", "2 右裤袋"]
var hand_item := ITEM_NONE
var hand_count := 0
var pocket_items := [ITEM_SNAP, ITEM_CRACKER]
var pocket_counts := [SNAP_BOX_CAPACITY, CRACKER_BOX_CAPACITY]
var pocket_capacities := [SNAP_BOX_CAPACITY, CRACKER_BOX_CAPACITY]
var inventory_panels: Array[PanelContainer] = []
var inventory_slot_labels: Array[Label] = []
var inventory_item_labels: Array[Label] = []
var inventory_detail_labels: Array[Label] = []
var aim_direction := Vector3.FORWARD
var aim_point := Vector3.ZERO
var throw_landing_point := Vector3.ZERO
var cracker_lit := false
var cracker_fuse := 0.0
var throw_cooldown := 0.0
var inventory_hint_text := ""
var inventory_hint_time := 0.0
var targets: Array[Node3D] = []
var projectiles: Array[Dictionary] = []
var explosions: Array[Dictionary] = []


func _ready() -> void:
	_build_lighting()
	_build_level()
	_build_player()
	_build_camera()
	_build_aim_helpers()
	_build_ui()


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_mouse_aim()
	_update_aim_helpers()
	_update_cracker_fuse(delta)
	_update_projectiles(delta)
	_update_explosions(delta)
	_update_inventory_ui()

	if throw_cooldown > 0.0:
		throw_cooldown = maxf(0.0, throw_cooldown - delta)
	if inventory_hint_time > 0.0:
		inventory_hint_time = maxf(0.0, inventory_hint_time - delta)

	if demo_finished:
		prompt_label.visible = false
		return

	if not message_open:
		_update_current_interactable()
		_check_exit_trigger()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return

	if event is InputEventKey:
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
		elif key_event.keycode == KEY_1:
			_take_from_pocket(0)
		elif key_event.keycode == KEY_2:
			_take_from_pocket(1)
		elif key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT:
			_return_hand_to_pocket()

	if event is InputEventMouseButton and not message_open and not demo_finished:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_use_selected_item()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_try_secondary_use_selected_item()


func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.18, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.50, 0.52)
	env.ambient_light_energy = 0.85
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.15
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.96
	environment.environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.name = "DuskLight"
	light.light_color = Color(0.92, 0.90, 0.82)
	light.light_energy = 2.4
	light.rotation_degrees = Vector3(-54.0, 38.0, 0.0)
	add_child(light)

	var room_glow := OmniLight3D.new()
	room_glow.name = "SoftRoomFill"
	room_glow.light_color = Color(0.62, 0.66, 0.68)
	room_glow.light_energy = 0.36
	room_glow.omni_range = 18.0
	room_glow.position = Vector3(0.0, 4.2, 4.0)
	add_child(room_glow)

	var dusk_fill := OmniLight3D.new()
	dusk_fill.name = "DuskDoorFill"
	dusk_fill.light_color = Color(1.0, 0.66, 0.34)
	dusk_fill.light_energy = 0.38
	dusk_fill.omni_range = 9.0
	dusk_fill.position = Vector3(3.5, 2.2, -4.8)
	add_child(dusk_fill)


func _build_level() -> void:
	var world := Node3D.new()
	world.name = "WhiteboxMap"
	add_child(world)

	_add_floor(world, "RoomB_CementFloor", Vector3(0.0, -0.06, 8.0), Vector3(10.0, 0.12, 8.0), COLOR_ROOM_B_FLOOR)
	_register_reveal_node(_add_floor(world, "RoomA_DirtyFloor", Vector3(0.0, -0.06, 0.0), Vector3(10.0, 0.12, 7.0), COLOR_ROOM_A_FLOOR), "room_a")
	_register_reveal_node(_add_floor(world, "Outdoor_GrassField", Vector3(0.0, -0.10, 1.0), Vector3(30.0, 0.10, 32.0), COLOR_OUTDOOR_FLOOR), "outdoor")

	_build_walls(world)
	_add_door(world, "DoorB", "obj_door_b", Vector3(3.5, 1.0, 3.75), Vector3(1.8, 2.0, 0.35), COLOR_OLD_WOOD)
	_register_reveal_node(_add_door(world, "DoorA", "obj_door_a", Vector3(3.5, 1.0, -3.75), Vector3(1.8, 2.0, 0.35), COLOR_DARK_WOOD), "room_a")

	_add_note(world)
	_register_reveal_node(_add_cabinet(world), "room_a")
	_register_reveal_node(_add_exit(world), "outdoor")
	_add_room_b_atmosphere(world)
	_add_room_a_atmosphere(world)
	_add_outdoor_atmosphere(world)
	_add_shooting_targets(world)
	_set_room_a_visible(false)
	_set_outdoor_visible(false)


func _build_walls(parent: Node) -> void:
	var wall_color := COLOR_WALL

	_add_solid_box(parent, "RoomB_TopWall", Vector3(0.0, 1.35, 12.0), Vector3(10.3, 2.7, 0.35), wall_color)
	_add_solid_box(parent, "RoomB_LeftWall", Vector3(-5.0, 1.35, 8.0), Vector3(0.35, 2.7, 8.3), wall_color)
	_add_solid_box(parent, "RoomB_RightWall", Vector3(5.0, 1.35, 8.0), Vector3(0.35, 2.7, 8.3), wall_color)
	_add_solid_box(parent, "RoomB_BottomWall_Left", Vector3(-1.2, 1.35, 4.0), Vector3(7.6, 2.7, 0.35), wall_color)
	_add_solid_box(parent, "RoomB_BottomWall_Right", Vector3(4.7, 1.35, 4.0), Vector3(0.6, 2.7, 0.35), wall_color)

	_register_reveal_node(_add_solid_box(parent, "RoomA_LeftWall", Vector3(-5.0, 1.35, 0.0), Vector3(0.35, 2.7, 7.3), wall_color), "room_a")
	_register_reveal_node(_add_solid_box(parent, "RoomA_RightWall", Vector3(5.0, 1.35, 0.0), Vector3(0.35, 2.7, 7.3), wall_color), "room_a")
	_register_reveal_node(_add_solid_box(parent, "RoomA_TopWall_Left", Vector3(-1.2, 1.35, 3.5), Vector3(7.6, 2.7, 0.35), wall_color), "room_a")
	_register_reveal_node(_add_solid_box(parent, "RoomA_TopWall_Right", Vector3(4.7, 1.35, 3.5), Vector3(0.6, 2.7, 0.35), wall_color), "room_a")
	_register_reveal_node(_add_solid_box(parent, "RoomA_BottomWall_Left", Vector3(-1.2, 1.35, -3.5), Vector3(7.6, 2.7, 0.35), wall_color), "room_a")
	_register_reveal_node(_add_solid_box(parent, "RoomA_BottomWall_Right", Vector3(4.7, 1.35, -3.5), Vector3(0.6, 2.7, 0.35), wall_color), "room_a")


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.set("face_movement", false)
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

	var facing_marker := MeshInstance3D.new()
	facing_marker.name = "FacingMarker"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.16, 0.14, 0.56)
	facing_marker.mesh = marker_mesh
	facing_marker.position = Vector3(0.0, 0.18, -0.52)
	facing_marker.set_surface_override_material(0, _material(Color(1.0, 0.74, 0.22)))
	player.add_child(facing_marker)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "TopDownCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.near = 0.1
	camera.far = 100.0
	camera.position = _get_camera_target_position()
	add_child(camera)
	camera.look_at(player.global_position, Vector3.UP)
	camera.current = true


func _build_aim_helpers() -> void:
	crosshair = MeshInstance3D.new()
	crosshair.name = "MouseCrosshair"
	var cross_mesh := CylinderMesh.new()
	cross_mesh.top_radius = 0.20
	cross_mesh.bottom_radius = 0.20
	cross_mesh.height = 0.035
	cross_mesh.radial_segments = 24
	crosshair.mesh = cross_mesh
	crosshair.set_surface_override_material(0, _material(Color(1.0, 0.86, 0.22)))
	add_child(crosshair)

	aim_line = MeshInstance3D.new()
	aim_line.name = "AimLine"
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.05, 0.04, 1.0)
	aim_line.mesh = line_mesh
	aim_line.set_surface_override_material(0, _material(Color(1.0, 0.86, 0.22, 0.45)))
	add_child(aim_line)


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

	inventory_status_label = Label.new()
	inventory_status_label.name = "InventoryStatus"
	inventory_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_status_label.add_theme_font_size_override("font_size", 18)
	inventory_status_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.84))
	inventory_status_label.anchor_left = 0.0
	inventory_status_label.anchor_right = 1.0
	inventory_status_label.anchor_top = 0.73
	inventory_status_label.anchor_bottom = 0.78
	canvas.add_child(inventory_status_label)

	var inventory_bar := HBoxContainer.new()
	inventory_bar.name = "InventoryBar"
	inventory_bar.anchor_left = 0.5
	inventory_bar.anchor_right = 0.5
	inventory_bar.anchor_top = 1.0
	inventory_bar.anchor_bottom = 1.0
	inventory_bar.offset_left = -190.0
	inventory_bar.offset_right = 190.0
	inventory_bar.offset_top = -122.0
	inventory_bar.offset_bottom = -20.0
	inventory_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	inventory_bar.add_theme_constant_override("separation", 14)
	canvas.add_child(inventory_bar)

	for i in range(inventory_slot_names.size()):
		var slot := PanelContainer.new()
		slot.name = "InventorySlot%d" % i
		slot.custom_minimum_size = Vector2(112, 96)
		inventory_bar.add_child(slot)
		inventory_panels.append(slot)

		var contents := VBoxContainer.new()
		contents.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(contents)

		var slot_label := Label.new()
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 16)
		contents.add_child(slot_label)
		inventory_slot_labels.append(slot_label)

		var item_label := Label.new()
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.add_theme_font_size_override("font_size", 21)
		contents.add_child(item_label)
		inventory_item_labels.append(item_label)

		var detail_label := Label.new()
		detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_label.add_theme_font_size_override("font_size", 15)
		contents.add_child(detail_label)
		inventory_detail_labels.append(detail_label)

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

	_add_label(note, "发黄纸条", Vector3(0.0, 0.55, 0.0))


func _add_cabinet(parent: Node) -> Node3D:
	var cabinet := _add_solid_box(parent, "CabinetA", Vector3(-3.5, 0.5, 0.5), Vector3(1.2, 1.0, 0.8), COLOR_OLD_WOOD)
	cabinet.set_meta("interact_id", "obj_cabinet_a")
	cabinet.add_to_group("interactable")
	_add_label(cabinet, "旧木柜", Vector3(0.0, 0.9, 0.0))
	return cabinet


func _add_exit(parent: Node) -> Node3D:
	var exit := Node3D.new()
	exit.name = "ExitEnd"
	exit.position = Vector3(0.0, 0.02, -8.0)
	parent.add_child(exit)

	var mesh := MeshInstance3D.new()
	mesh.name = "ExitMarker"
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.05, 2.0)
	mesh.mesh = box
	mesh.set_surface_override_material(0, _material(Color(0.62, 0.63, 0.56)))
	exit.add_child(mesh)
	_add_label(exit, "门外黄昏", Vector3(0.0, 0.65, 0.0))
	return exit


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
	return door


func _add_room_b_atmosphere(parent: Node) -> void:
	_add_floor(parent, "OldTableTop", Vector3(-3.6, 0.42, 7.15), Vector3(1.5, 0.12, 0.85), COLOR_DARK_WOOD)
	_add_floor(parent, "OldTableLegA", Vector3(-4.2, 0.18, 6.8), Vector3(0.12, 0.36, 0.12), COLOR_DARK_WOOD)
	_add_floor(parent, "OldTableLegB", Vector3(-3.0, 0.18, 7.5), Vector3(0.12, 0.36, 0.12), COLOR_DARK_WOOD)
	_add_label_marker(parent, "旧木桌", Vector3(-3.6, 0.88, 7.15))

	_add_floor(parent, "DirtyWindow", Vector3(-4.78, 1.25, 10.15), Vector3(0.08, 0.82, 1.45), Color(0.62, 0.66, 0.62))


func _add_room_a_atmosphere(_parent: Node) -> void:
	pass


func _add_outdoor_atmosphere(_parent: Node) -> void:
	pass


func _add_shooting_targets(parent: Node) -> void:
	_register_reveal_node(_add_target(parent, "RoomA_PaperTarget", Vector3(1.5, 0.8, -1.0), "房间纸靶"), "room_a")
	_register_reveal_node(_add_target(parent, "Outdoor_PaperTarget", Vector3(4.8, 0.8, -6.8), "草地纸靶"), "outdoor")


func _add_target(parent: Node, target_name: String, pos: Vector3, label_text: String) -> Node3D:
	var target := StaticBody3D.new()
	target.name = target_name
	target.position = pos
	target.collision_layer = 1
	target.collision_mask = 1
	target.set_meta("hit", false)
	parent.add_child(target)
	targets.append(target)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 1.45
	mesh.radial_segments = 18
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(COLOR_PAPER_YELLOW))
	target.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 1.45
	collision.shape = shape
	target.add_child(collision)

	_add_label(target, label_text, Vector3(0.0, 1.05, 0.0))
	return target


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


func _update_camera(_delta: float) -> void:
	if camera == null:
		return

	camera.global_position = _get_camera_target_position()


func _get_camera_target_position() -> Vector3:
	return player.global_position + camera_offset


func _update_mouse_aim() -> void:
	if camera == null or player == null:
		return

	if message_open or demo_finished:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	if absf(ray_dir.y) < 0.001:
		return

	var t := -ray_origin.y / ray_dir.y
	var hit := ray_origin + ray_dir * t
	aim_point = Vector3(hit.x, 0.03, hit.z)
	throw_landing_point = _resolve_throw_landing_point(aim_point)

	var flat_delta := Vector3(aim_point.x - player.global_position.x, 0.0, aim_point.z - player.global_position.z)
	if flat_delta.length() >= AIM_MIN_DISTANCE:
		aim_direction = flat_delta.normalized()
		player.look_at(player.global_position + aim_direction, Vector3.UP)


func _update_aim_helpers() -> void:
	if crosshair == null or aim_line == null or player == null:
		return

	if message_open or demo_finished:
		crosshair.visible = false
		aim_line.visible = false
		return

	crosshair.visible = true
	crosshair.global_position = throw_landing_point

	var start := player.global_position + Vector3(0.0, 0.05, 0.0)
	var end := Vector3(throw_landing_point.x, 0.08, throw_landing_point.z)
	var delta := end - start
	delta.y = 0.0
	var length := delta.length()
	if length < 0.1:
		aim_line.visible = false
		return

	aim_line.visible = true
	aim_line.global_position = start + delta * 0.5
	var mesh := aim_line.mesh as BoxMesh
	mesh.size = Vector3(0.05, 0.04, length)
	aim_line.rotation = Vector3.ZERO
	aim_line.rotation.y = atan2(delta.x, delta.z)


func _update_cracker_fuse(delta: float) -> void:
	if not cracker_lit:
		return

	cracker_fuse -= delta
	if cracker_fuse <= 0.0:
		_create_explosion(player.global_position, CRACKER_EXPLOSION_RADIUS)
		_clear_hand()
		_show_inventory_hint("擦炮在手边炸了。")


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[i]
		var node := projectile["node"] as Node3D
		if not is_instance_valid(node):
			projectiles.remove_at(i)
			continue

		projectile["age"] = float(projectile["age"]) + delta

		if bool(projectile["moving"]):
			var start_position: Vector3 = projectile["start_position"]
			var landing_position: Vector3 = projectile["landing_position"]
			var flight_time := float(projectile["flight_time"])
			var progress := clampf(float(projectile["age"]) / flight_time, 0.0, 1.0)
			var next_position := start_position.lerp(landing_position, progress)
			next_position.y += sin(progress * PI) * float(projectile["arc_height"])
			node.global_position = next_position
			if progress >= 1.0:
				projectile["moving"] = false
				node.global_position = landing_position

		projectile["fuse"] = float(projectile["fuse"]) - delta
		if float(projectile["fuse"]) <= 0.0:
			_create_explosion(node.global_position, float(projectile["radius"]))
			node.queue_free()
			projectiles.remove_at(i)


func _update_explosions(delta: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var explosion := explosions[i]
		var marker := explosion["node"] as Node3D
		if not is_instance_valid(marker):
			explosions.remove_at(i)
			continue

		explosion["time"] = float(explosion["time"]) - delta
		if float(explosion["time"]) <= 0.0:
			marker.queue_free()
			explosions.remove_at(i)


func _update_inventory_ui() -> void:
	if inventory_panels.size() < 3:
		return

	inventory_panels[0].add_theme_stylebox_override("panel", _slot_style(true))
	inventory_slot_labels[0].text = inventory_slot_names[0]
	inventory_item_labels[0].text = _hand_display_text()
	inventory_detail_labels[0].text = _hand_detail_text()

	for pocket_index in range(pocket_items.size()):
		var slot_index := pocket_index + 1
		var item := String(pocket_items[pocket_index])
		inventory_panels[slot_index].add_theme_stylebox_override("panel", _slot_style(false))
		inventory_slot_labels[slot_index].text = inventory_slot_names[slot_index]
		inventory_item_labels[slot_index].text = _box_display_name(item)
		inventory_detail_labels[slot_index].text = "%d/%d" % [int(pocket_counts[pocket_index]), int(pocket_capacities[pocket_index])]

	if inventory_hint_time > 0.0:
		inventory_status_label.text = inventory_hint_text
	else:
		inventory_status_label.text = "1 取摔炮  2 取擦炮  Shift 放回  左键全扔  右键点火"


func _hand_display_text() -> String:
	if hand_count <= 0:
		return "空手"
	return "%s x%d" % [_item_display_name(hand_item), hand_count]


func _hand_detail_text() -> String:
	if hand_count <= 0:
		return "最多 5 个"
	if hand_item == ITEM_CRACKER and cracker_lit:
		return "倒计时 %.1f" % maxf(cracker_fuse, 0.0)
	if hand_item == ITEM_CRACKER:
		return "右键点火"
	return "左键全扔"


func _box_display_name(item: String) -> String:
	return "%s盒" % _item_display_name(item)


func _take_from_pocket(pocket_index: int) -> void:
	if pocket_index < 0 or pocket_index >= pocket_items.size():
		return

	if cracker_lit:
		_show_inventory_hint("擦炮已经点着了，先扔出去。")
		return

	var item := String(pocket_items[pocket_index])
	if hand_count > 0 and hand_item != item:
		_show_inventory_hint("手上拿着%s，先按 Shift 放回去。" % _item_display_name(hand_item))
		return

	if hand_count >= HAND_CAPACITY:
		_show_inventory_hint("手里最多拿 %d 个。" % HAND_CAPACITY)
		return

	if int(pocket_counts[pocket_index]) <= 0:
		_show_inventory_hint("%s已经空了。" % _box_display_name(item))
		return

	hand_item = item
	hand_count += 1
	pocket_counts[pocket_index] = int(pocket_counts[pocket_index]) - 1
	_show_inventory_hint("拿出 1 个%s，手上现在有 %d 个。" % [_item_display_name(item), hand_count])


func _return_hand_to_pocket() -> void:
	if hand_count <= 0:
		_show_inventory_hint("手上没有东西。")
		return

	if cracker_lit:
		_show_inventory_hint("点着的擦炮不能塞回口袋。")
		return

	var pocket_index := _pocket_index_for_item(hand_item)
	if pocket_index < 0:
		_show_inventory_hint("这个东西没有对应的盒子。")
		return

	var space := int(pocket_capacities[pocket_index]) - int(pocket_counts[pocket_index])
	if space <= 0:
		_show_inventory_hint("%s已经满了。" % _box_display_name(hand_item))
		return

	var returned_count := mini(space, hand_count)
	pocket_counts[pocket_index] = int(pocket_counts[pocket_index]) + returned_count
	hand_count -= returned_count
	_show_inventory_hint("放回 %d 个%s。" % [returned_count, _item_display_name(hand_item)])
	if hand_count <= 0:
		_clear_hand()


func _pocket_index_for_item(item: String) -> int:
	for i in range(pocket_items.size()):
		if String(pocket_items[i]) == item:
			return i
	return -1


func _try_use_selected_item() -> void:
	if throw_cooldown > 0.0:
		return

	if hand_count <= 0 or hand_item == ITEM_NONE:
		_show_inventory_hint("手上没有爆竹。")
		return

	var thrown_count := hand_count
	match hand_item:
		ITEM_SNAP:
			for i in range(thrown_count):
				_throw_projectile(ITEM_SNAP, SNAP_THROW_SPEED, SNAP_THROW_TIME, SNAP_THROW_TIME, SNAP_EXPLOSION_RADIUS, 1.05, Color(0.92, 0.20, 0.16), i, thrown_count)
			_show_inventory_hint("扔出 %d 个摔炮。" % thrown_count)
			_clear_hand()
			throw_cooldown = THROW_COOLDOWN
		ITEM_CRACKER:
			if not cracker_lit:
				_show_inventory_hint("擦炮还没点着。")
				return
			var fuse_left := maxf(cracker_fuse, 0.05)
			for i in range(thrown_count):
				_throw_projectile(ITEM_CRACKER, CRACKER_THROW_SPEED, CRACKER_THROW_TIME, fuse_left, CRACKER_EXPLOSION_RADIUS, 1.25, Color(0.62, 0.62, 0.58), i, thrown_count)
			_show_inventory_hint("扔出 %d 个擦炮。" % thrown_count)
			_clear_hand()
			throw_cooldown = THROW_COOLDOWN
		_:
			_show_inventory_hint("手上没有爆竹。")


func _try_secondary_use_selected_item() -> void:
	if hand_count <= 0 or hand_item == ITEM_NONE:
		_show_inventory_hint("手上没有爆竹。")
		return

	match hand_item:
		ITEM_SNAP:
			_show_inventory_hint("摔炮不用点。")
		ITEM_CRACKER:
			if cracker_lit:
				_show_inventory_hint("擦炮已经点着了。")
				return
			cracker_lit = true
			cracker_fuse = CRACKER_FUSE_TIME
			_show_inventory_hint("点着了。")
		_:
			_show_inventory_hint("手上没有爆竹。")


func _throw_projectile(kind: String, speed: float, _base_flight_time: float, fuse: float, radius: float, arc_height: float, color: Color, spread_index: int = 0, spread_count: int = 1) -> void:
	var landing_position := _get_spread_landing_point(throw_landing_point, spread_index, spread_count)
	if landing_position == Vector3.ZERO:
		landing_position = _resolve_throw_landing_point(aim_point)
	var start_position := _get_projectile_start_position(landing_position)
	var distance := Vector2(landing_position.x - start_position.x, landing_position.z - start_position.z).length()
	var flight_time := maxf(THROW_MIN_FLIGHT_TIME, distance / speed)
	if kind == ITEM_SNAP:
		fuse = flight_time

	var projectile := Node3D.new()
	projectile.name = "Projectile_%s" % kind
	add_child(projectile)
	projectile.global_position = start_position

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.22, 0.22)
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(color))
	projectile.add_child(mesh_instance)

	projectiles.append({
		"node": projectile,
		"start_position": start_position,
		"landing_position": landing_position,
		"age": 0.0,
		"flight_time": flight_time,
		"fuse": fuse,
		"radius": radius,
		"arc_height": arc_height,
		"moving": true,
	})


func _get_spread_landing_point(base_point: Vector3, spread_index: int, spread_count: int) -> Vector3:
	if spread_count <= 1:
		return base_point

	var side := Vector3(-aim_direction.z, 0.0, aim_direction.x)
	if side.length_squared() <= 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()

	var spread_offset := (float(spread_index) - float(spread_count - 1) * 0.5) * 0.18
	var candidate := base_point + side * spread_offset
	return _resolve_throw_landing_point(candidate)


func _get_projectile_start_position(landing_position: Vector3) -> Vector3:
	var player_ground := Vector3(player.global_position.x, THROW_GROUND_Y, player.global_position.z)
	var flat_delta := Vector3(landing_position.x - player_ground.x, 0.0, landing_position.z - player_ground.z)
	if flat_delta.length() <= 0.05:
		return player_ground + Vector3(0.0, 0.36, 0.0)

	var direction := flat_delta.normalized()
	var offset := minf(0.45, flat_delta.length() * 0.35)
	return player_ground + direction * offset + Vector3(0.0, 0.36, 0.0)


func _resolve_throw_landing_point(raw_point: Vector3) -> Vector3:
	if player == null:
		return Vector3(raw_point.x, THROW_GROUND_Y, raw_point.z)

	var player_ground := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var target_ground := Vector3(raw_point.x, 0.0, raw_point.z)
	var flat_delta := target_ground - player_ground
	if flat_delta.length() <= 0.05:
		return Vector3(player_ground.x, THROW_GROUND_Y, player_ground.z)

	var direction := flat_delta.normalized()
	var ray_start := player_ground + Vector3(0.0, THROW_RAY_HEIGHT, 0.0)
	var ray_end := target_ground + Vector3(0.0, THROW_RAY_HEIGHT, 0.0)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3(target_ground.x, THROW_GROUND_Y, target_ground.z)

	var hit_position: Vector3 = hit["position"]
	var safe_position := hit_position - direction * THROW_WALL_PADDING
	return Vector3(safe_position.x, THROW_GROUND_Y, safe_position.z)


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
	mesh_instance.set_surface_override_material(0, _material(Color(1.0, 0.70, 0.18, 0.70)))
	marker.add_child(mesh_instance)

	explosions.append({
		"node": marker,
		"time": 0.32,
	})
	_hit_targets(world_position, radius)


func _hit_targets(world_position: Vector3, radius: float) -> void:
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not target.is_visible_in_tree():
			continue
		if bool(target.get_meta("hit", false)):
			continue

		var distance := Vector2(target.global_position.x - world_position.x, target.global_position.z - world_position.z).length()
		if distance <= radius and _has_clear_blast_path(world_position, target):
			_disable_target(target)
			_show_inventory_hint("命中")


func _has_clear_blast_path(world_position: Vector3, target: Node3D) -> bool:
	var from := Vector3(world_position.x, THROW_RAY_HEIGHT, world_position.z)
	var to := Vector3(target.global_position.x, THROW_RAY_HEIGHT, target.global_position.z)
	if from.distance_to(to) <= 0.05:
		return true

	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var exclude: Array[RID] = []
	if player != null:
		exclude.append(player.get_rid())
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	query.exclude = exclude

	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _disable_target(target: Node3D) -> void:
	target.set_meta("hit", true)
	var mesh := target.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		mesh.set_surface_override_material(0, _material(Color(0.95, 0.18, 0.12)))

	var collision := target.get_node_or_null("Collision") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)

	_add_label(target, "命中", Vector3(0.0, 1.55, 0.0))


func _get_selected_item() -> String:
	return hand_item


func _clear_hand() -> void:
	hand_item = ITEM_NONE
	hand_count = 0
	cracker_lit = false
	cracker_fuse = 0.0


func _item_display_name(item: String) -> String:
	match item:
		ITEM_SNAP:
			return "摔炮"
		ITEM_CRACKER:
			return "擦炮"
		_:
			return "空"


func _show_inventory_hint(text: String, duration: float = 1.6) -> void:
	inventory_hint_text = text
	inventory_hint_time = duration
	if inventory_status_label != null:
		inventory_status_label.text = text


func _slot_style(is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.015, 0.015, 0.72)
	style.border_color = Color(0.95, 0.12, 0.08) if is_selected else Color(0.82, 0.82, 0.78)
	style.set_border_width_all(4 if is_selected else 2)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _update_current_interactable() -> void:
	var nearest: Node3D = null
	var nearest_distance := INTERACT_RANGE

	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D):
			continue
		var interactable := node as Node3D
		if not interactable.is_visible_in_tree():
			continue
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
		_set_room_a_visible(true)
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
		_set_outdoor_visible(true)
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


func _register_reveal_node(node: Node3D, reveal_key: String) -> Node3D:
	if reveal_key == "room_a":
		room_a_reveal_nodes.append(node)
	elif reveal_key == "outdoor":
		outdoor_reveal_nodes.append(node)
	return node


func _set_room_a_visible(should_show: bool) -> void:
	_set_reveal_nodes_visible(room_a_reveal_nodes, should_show)


func _set_outdoor_visible(should_show: bool) -> void:
	_set_reveal_nodes_visible(outdoor_reveal_nodes, should_show)


func _set_reveal_nodes_visible(nodes: Array[Node3D], should_show: bool) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.visible = should_show


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
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return mat
