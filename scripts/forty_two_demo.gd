extends Node3D

const MOVE_SPEED := 5.0
const INTERACT_RANGE := 2.0
const AIM_MIN_DISTANCE := 0.75
const THROW_COOLDOWN := 0.55
const SNAP_THROW_TIME := 0.46
const SNAP_THROW_SPEED := 14.0
const SNAP_EXPLOSION_RADIUS := 1.8
const CRACKER_THROW_TIME := 0.72
const CRACKER_THROW_SPEED := 10.0
const CRACKER_FUSE_TIME := 5.0
const CRACKER_EXPLOSION_RADIUS := 2.8
const CAMERA_OFFSET := Vector3(-13.0, 15.0, -13.0)
const SCHOOL_ALLEY_X := -13.0

const WEAPON_NONE := ""
const WEAPON_SNAP := "snap"
const WEAPON_CRACKER := "cracker"

const COLOR_CEMENT := Color(0.48, 0.49, 0.46)
const COLOR_DARK_CEMENT := Color(0.30, 0.31, 0.30)
const COLOR_WALL := Color(0.68, 0.67, 0.60)
const COLOR_WALL_DARK := Color(0.42, 0.43, 0.40)
const COLOR_SHOP := Color(0.58, 0.50, 0.40)
const COLOR_SCHOOL := Color(0.54, 0.61, 0.58)
const COLOR_WOOD := Color(0.35, 0.22, 0.12)
const COLOR_PAPER := Color(0.88, 0.82, 0.62)
const COLOR_PAPER_MAN := Color(0.90, 0.86, 0.72)
const COLOR_ROOF := Color(0.38, 0.38, 0.35)
const COLOR_DUSK := Color(1.0, 0.72, 0.34)
const COLOR_COOL := Color(0.24, 0.38, 0.36)

var player: CharacterBody3D
var camera: Camera3D
var crosshair: MeshInstance3D
var aim_line: MeshInstance3D
var prompt_label: Label
var weapon_label: Label
var status_label: Label
var hint_label: Label
var message_panel: PanelContainer
var message_label: Label
var end_overlay: ColorRect

var current_interactable: Node3D
var message_open := false
var demo_finished := false
var can_move := true

var has_read_note := false
var has_snap := false
var has_cracker := false
var paper_a_cleared := false
var paper_b_cleared := false
var roof_route_open := false
var got_roster := false

var current_weapon := WEAPON_NONE
var aim_direction := Vector3.BACK
var aim_point := Vector3.ZERO
var cracker_lit := false
var cracker_fuse := 0.0
var throw_cooldown := 0.0

var roof_entry: Node3D
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
	_show_hint("看看学校门口。")


func _process(delta: float) -> void:
	_update_camera()
	_update_mouse_aim()
	_update_aim_helpers()
	_update_cracker_fuse(delta)
	_update_projectiles(delta)
	_update_explosions(delta)
	_update_ui()

	if throw_cooldown > 0.0:
		throw_cooldown = maxf(0.0, throw_cooldown - delta)

	if demo_finished or message_open:
		prompt_label.visible = false
		return

	_update_current_interactable()


func _physics_process(_delta: float) -> void:
	if not can_move:
		player.velocity = Vector3.ZERO
		player.move_and_slide()
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

	player.velocity = _get_screen_relative_direction(input_vector) * MOVE_SPEED
	player.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
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
			_try_select_weapon(WEAPON_SNAP)
		elif key_event.keycode == KEY_2:
			_try_select_weapon(WEAPON_CRACKER)

	if event is InputEventMouseButton and not message_open and not demo_finished:
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
	env.background_color = Color(0.24, 0.25, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.75, 0.68)
	env.ambient_light_energy = 1.08
	env.tonemap_exposure = 1.05
	env.tonemap_white = 1.22
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.98
	environment.environment = env
	add_child(environment)

	var dusk_light := DirectionalLight3D.new()
	dusk_light.name = "DuskLight"
	dusk_light.light_color = Color(1.0, 0.84, 0.62)
	dusk_light.light_energy = 2.0
	dusk_light.rotation_degrees = Vector3(-48.0, 42.0, 0.0)
	add_child(dusk_light)

	var liminal_fill := OmniLight3D.new()
	liminal_fill.name = "LiminalGreenFill"
	liminal_fill.light_color = Color(0.60, 0.72, 0.64)
	liminal_fill.light_energy = 0.42
	liminal_fill.omni_range = 55.0
	liminal_fill.position = Vector3(10.0, 5.0, -55.0)
	add_child(liminal_fill)


func _build_level() -> void:
	var world := Node3D.new()
	world.name = "FortyTwoWhitebox"
	add_child(world)

	_build_school_gate(world)
	_build_liminal_alley(world)
	_build_forty_two_building(world)


func _build_school_gate(parent: Node) -> void:
	_add_floor(parent, "SchoolStreetFloor", Vector3(1.0, -0.06, 20.0), Vector3(34.0, 0.12, 18.0), Color(0.52, 0.53, 0.49))
	_add_floor(parent, "CampusYard", Vector3(7.8, -0.06, 33.0), Vector3(8.4, 0.12, 7.2), Color(0.46, 0.54, 0.49))
	_add_solid_box(parent, "SchoolNorthWallLeft", Vector3(-5.8, 1.0, 29.2), Vector3(21.6, 2.0, 0.35), COLOR_SCHOOL)
	_add_solid_box(parent, "SchoolNorthWallRight", Vector3(13.6, 1.0, 29.2), Vector3(5.8, 2.0, 0.35), COLOR_SCHOOL)
	_add_solid_box(parent, "CampusBackBoundary", Vector3(7.8, 1.0, 36.6), Vector3(8.4, 2.0, 0.35), COLOR_SCHOOL)
	_add_solid_box(parent, "CampusLeftBoundary", Vector3(3.6, 1.0, 33.0), Vector3(0.35, 2.0, 7.2), COLOR_SCHOOL)
	_add_solid_box(parent, "CampusRightBoundary", Vector3(12.0, 1.0, 33.0), Vector3(0.35, 2.0, 7.2), COLOR_SCHOOL)
	_add_solid_box(parent, "SchoolWestBoundary", Vector3(-17.8, 1.0, 20.0), Vector3(0.35, 2.0, 18.4), COLOR_WALL_DARK)
	_add_solid_box(parent, "SchoolEastStreetGuide", Vector3(16.2, 1.0, 20.0), Vector3(0.35, 2.0, 18.4), COLOR_WALL_DARK)

	_add_solid_box(parent, "SecurityBooth", Vector3(11.3, 0.75, 28.0), Vector3(1.4, 1.5, 2.0), Color(0.42, 0.50, 0.48))
	_add_label_marker(parent, "保安亭", Vector3(11.3, 1.8, 28.0))

	_add_solid_box(parent, "SchoolGateLeft", Vector3(5.7, 1.2, 28.7), Vector3(0.35, 2.4, 1.1), Color(0.72, 0.76, 0.70))
	_add_solid_box(parent, "SchoolGateRight", Vector3(9.9, 1.2, 28.7), Vector3(0.35, 2.4, 1.1), Color(0.72, 0.76, 0.70))
	_add_label_marker(parent, "学校大门", Vector3(7.8, 2.2, 28.1))

	_add_solid_box(parent, "TeachingBuilding", Vector3(-6.2, 1.25, 27.0), Vector3(13.0, 2.5, 3.3), Color(0.48, 0.58, 0.55))
	_add_label_marker(parent, "教学楼 / 学校围墙", Vector3(-6.2, 2.8, 27.0))

	_add_shop(parent, "儿童托管", Vector3(10.6, 0.8, 9.7), Color(0.64, 0.52, 0.38))
	_add_shop(parent, "普通店铺", Vector3(5.4, 0.8, 9.7), Color(0.54, 0.48, 0.40))
	_add_solid_box(parent, "TeaShopBuilding", Vector3(-17.1, 0.8, 10.1), Vector3(3.9, 1.6, 5.0), Color(0.68, 0.48, 0.48))
	_add_label_marker(parent, "奶茶店", Vector3(-17.1, 2.05, 10.1))
	_add_solid_box(parent, "MengShopBuilding", Vector3(-8.9, 0.8, 10.1), Vector3(3.5, 1.6, 5.0), Color(0.46, 0.34, 0.22))
	_add_label_marker(parent, "老孟小卖部", Vector3(-8.9, 2.05, 10.1))

	var note := _add_interactable(parent, "WallNote", "note", "调查纸条", Vector3(-12.2, 0.08, 27.1))
	_add_floor(note, "PaperMesh", Vector3.ZERO, Vector3(0.9, 0.05, 0.6), COLOR_PAPER)
	_add_label(note, "学校墙下纸条", Vector3(0.0, 0.62, 0.0))

	_add_floor(parent, "TIntersectionMark", Vector3(SCHOOL_ALLEY_X, 0.01, 16.0), Vector3(5.0, 0.04, 6.0), Color(0.43, 0.44, 0.41))
	_add_floor(parent, "AlleyMouthFloor", Vector3(SCHOOL_ALLEY_X, 0.01, 10.2), Vector3(4.2, 0.05, 6.8), COLOR_COOL)
	_add_label_marker(parent, "小巷子入口", Vector3(SCHOOL_ALLEY_X, 0.75, 8.8))


func _build_liminal_alley(parent: Node) -> void:
	_add_floor(parent, "AlleyFloor", Vector3(SCHOOL_ALLEY_X, -0.06, -21.5), Vector3(4.2, 0.12, 59.0), Color(0.44, 0.45, 0.42))
	_add_solid_box(parent, "AlleyLeftWall", Vector3(SCHOOL_ALLEY_X - 2.35, 1.15, -21.5), Vector3(0.35, 2.3, 59.0), COLOR_WALL)
	_add_solid_box(parent, "AlleyRightWall", Vector3(SCHOOL_ALLEY_X + 2.35, 1.15, -21.5), Vector3(0.35, 2.3, 59.0), COLOR_WALL)

	for i in range(5):
		var z := -10.0 - float(i) * 7.4
		_add_floor(parent, "RepeatedWallSeam_%d" % i, Vector3(SCHOOL_ALLEY_X - 2.16, 0.76, z), Vector3(0.06, 0.9, 1.6), COLOR_COOL)
		_add_floor(parent, "RepeatedPipe_%d" % i, Vector3(SCHOOL_ALLEY_X + 2.16, 0.86, z - 1.6), Vector3(0.06, 1.2, 0.08), Color(0.26, 0.27, 0.25))
		_add_label_marker(parent, "门牌 %02d" % (42 + i), Vector3(SCHOOL_ALLEY_X - 2.05, 1.75, z + 1.4))

	var alley_end := _add_interactable(parent, "AlleyEnd", "alley_end", "继续往前走", Vector3(SCHOOL_ALLEY_X, 0.08, -50.5))
	_add_floor(alley_end, "AlleyEndMarker", Vector3.ZERO, Vector3(2.7, 0.05, 1.0), COLOR_DUSK)
	_add_label(alley_end, "巷子尽头", Vector3(0.0, 0.7, 0.0))


func _build_forty_two_building(parent: Node) -> void:
	_add_floor(parent, "BuildingExteriorFloor", Vector3(0.0, -0.06, -82.0), Vector3(24.0, 0.12, 18.0), Color(0.43, 0.44, 0.41))
	_add_solid_box(parent, "FortyTwoFacade", Vector3(0.0, 1.6, -88.8), Vector3(14.0, 3.2, 0.45), COLOR_WALL)
	_add_solid_box(parent, "FortyTwoLeftWall", Vector3(-7.2, 1.3, -84.2), Vector3(0.45, 2.6, 9.5), COLOR_WALL_DARK)
	_add_solid_box(parent, "FortyTwoRightWall", Vector3(7.2, 1.3, -84.2), Vector3(0.45, 2.6, 9.5), COLOR_WALL_DARK)
	_add_label_marker(parent, "42号楼", Vector3(0.0, 3.4, -88.5))

	var front_door := _add_interactable(parent, "FrontDoor", "front_door", "调查一层正门", Vector3(0.0, 0.08, -86.4))
	_add_floor(front_door, "DoorPlate", Vector3.ZERO, Vector3(1.6, 0.06, 0.8), COLOR_WOOD)
	_add_label(front_door, "一层正门", Vector3(0.0, 0.75, 0.0))

	var stair := _add_interactable(parent, "ExteriorStair", "stair", "上外侧楼梯", Vector3(-8.8, 0.08, -82.2))
	_add_floor(stair, "StairMarker", Vector3.ZERO, Vector3(2.3, 0.06, 1.4), Color(0.55, 0.56, 0.52))
	_add_label(stair, "外侧楼梯", Vector3(0.0, 0.75, 0.0))

	_build_second_floor(parent)
	_build_roof_and_gap(parent)


func _build_second_floor(parent: Node) -> void:
	_add_floor(parent, "SecondFloorCorridor", Vector3(39.0, -0.04, -80.0), Vector3(30.0, 0.12, 4.0), Color(0.47, 0.48, 0.45))
	_add_solid_box(parent, "CorridorRail", Vector3(39.0, 0.55, -77.8), Vector3(28.0, 1.1, 0.28), Color(0.38, 0.39, 0.37))
	_add_label_marker(parent, "二层露天走廊", Vector3(25.0, 1.35, -79.8))

	_add_room(parent, "房间 A", Vector2(29.0, -88.0), "RoomA")
	_add_room(parent, "房间 B", Vector2(38.0, -88.0), "RoomB")
	_add_room(parent, "房间 C", Vector2(47.0, -88.0), "RoomC")

	var snap_cabinet := _add_interactable(parent, "SnapCabinet", "snap_cabinet", "调查旧柜子", Vector3(28.0, 0.08, -89.1))
	_add_solid_box(snap_cabinet, "CabinetBody", Vector3.ZERO, Vector3(1.1, 1.0, 0.8), COLOR_WOOD)
	_add_label(snap_cabinet, "旧柜子 / 摔炮", Vector3(0.0, 1.0, 0.0))

	_add_paper_target(parent, "PaperManA", "paper_a", WEAPON_SNAP, Vector3(39.5, 0.85, -79.9), Vector3(1.1, 1.7, 0.45), "纸人 A")

	var cracker_box := _add_interactable(parent, "CrackerBox", "cracker_box", "拾取擦炮", Vector3(47.0, 0.08, -88.8))
	_add_floor(cracker_box, "CrackerBoxMesh", Vector3.ZERO, Vector3(0.8, 0.08, 0.5), Color(0.62, 0.62, 0.57))
	_add_label(cracker_box, "一盒擦炮", Vector3(0.0, 0.65, 0.0))

	_add_paper_target(parent, "PaperManB", "paper_b", WEAPON_CRACKER, Vector3(51.0, 0.85, -79.9), Vector3(1.1, 1.7, 0.45), "纸人 B")

	roof_entry = _add_interactable(parent, "RoofEntry", "roof_entry", "翻到旁边房顶", Vector3(53.8, 0.08, -80.0))
	roof_entry.set_meta("disabled", true)
	_add_floor(roof_entry, "RoofEntryMarker", Vector3.ZERO, Vector3(1.8, 0.06, 1.2), Color(0.35, 0.36, 0.34))
	_add_label(roof_entry, "走廊尽头", Vector3(0.0, 0.72, 0.0))


func _build_roof_and_gap(parent: Node) -> void:
	_add_floor(parent, "NeighborRoof", Vector3(64.0, -0.04, -80.0), Vector3(14.0, 0.12, 4.0), COLOR_ROOF)
	_add_solid_box(parent, "RoofUpperLip", Vector3(64.0, 0.45, -82.2), Vector3(14.0, 0.9, 0.25), Color(0.28, 0.28, 0.26))
	_add_solid_box(parent, "RoofLowerLip", Vector3(64.0, 0.45, -77.8), Vector3(14.0, 0.9, 0.25), Color(0.28, 0.28, 0.26))
	_add_label_marker(parent, "旁边房顶", Vector3(62.0, 1.2, -80.0))

	var drop := _add_interactable(parent, "RoofDrop", "roof_drop", "跳下夹缝", Vector3(70.2, 0.08, -80.0))
	_add_floor(drop, "DropMarker", Vector3.ZERO, Vector3(1.5, 0.06, 1.2), COLOR_DUSK)
	_add_label(drop, "跳下点", Vector3(0.0, 0.72, 0.0))

	_add_floor(parent, "GapFloor", Vector3(81.0, -0.06, -80.0), Vector3(10.0, 0.12, 3.2), Color(0.39, 0.40, 0.38))
	_add_solid_box(parent, "GapWallTop", Vector3(81.0, 1.2, -82.0), Vector3(10.0, 2.4, 0.35), COLOR_WALL_DARK)
	_add_solid_box(parent, "GapWallBottom", Vector3(81.0, 1.2, -78.0), Vector3(10.0, 2.4, 0.35), COLOR_WALL)
	_add_solid_box(parent, "GapDebris", Vector3(79.2, 0.28, -80.7), Vector3(1.4, 0.55, 0.8), Color(0.30, 0.28, 0.22))
	_add_label_marker(parent, "夹缝区域", Vector3(78.0, 1.3, -80.0))

	var roster := _add_interactable(parent, "RosterPage", "roster", "调查名册碎页", Vector3(83.5, 0.08, -80.1))
	_add_floor(roster, "RosterPaperMesh", Vector3.ZERO, Vector3(0.9, 0.05, 0.62), COLOR_PAPER)
	_add_label(roster, "调查团名册碎页", Vector3(0.0, 0.7, 0.0))


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(7.8, 0.72, 20.5)
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

	var marker := MeshInstance3D.new()
	marker.name = "FacingMarker"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.18, 0.16, 0.62)
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 0.2, -0.55)
	marker.set_surface_override_material(0, _material(Color(1.0, 0.78, 0.22)))
	player.add_child(marker)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FortyTwoCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.5
	camera.near = 0.1
	camera.far = 180.0
	add_child(camera)
	_update_camera()
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
	end_overlay.color = Color(0.04, 0.04, 0.035, 0.48)
	end_overlay.anchor_right = 1.0
	end_overlay.anchor_bottom = 1.0
	end_overlay.visible = false
	canvas.add_child(end_overlay)

	weapon_label = Label.new()
	weapon_label.position = Vector2(24, 18)
	weapon_label.add_theme_font_size_override("font_size", 23)
	weapon_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	canvas.add_child(weapon_label)

	status_label = Label.new()
	status_label.position = Vector2(24, 52)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.80, 1.0, 0.84))
	canvas.add_child(status_label)

	hint_label = Label.new()
	hint_label.position = Vector2(24, 82)
	hint_label.add_theme_font_size_override("font_size", 19)
	hint_label.add_theme_color_override("font_color", Color(0.90, 0.91, 0.84))
	canvas.add_child(hint_label)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 25)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	prompt_label.anchor_right = 1.0
	prompt_label.anchor_top = 0.82
	prompt_label.anchor_bottom = 0.90
	prompt_label.visible = false
	canvas.add_child(prompt_label)

	message_panel = PanelContainer.new()
	message_panel.anchor_left = 0.18
	message_panel.anchor_right = 0.82
	message_panel.anchor_top = 0.68
	message_panel.anchor_bottom = 0.95
	message_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.05, 0.90)
	panel_style.border_color = Color(0.78, 0.75, 0.58)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	message_panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(message_panel)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.86))
	message_panel.add_child(message_label)


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
	if camera == null or player == null:
		return

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
	if crosshair == null or aim_line == null or player == null:
		return

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
	mesh.size = Vector3(0.05, 0.04, length)
	aim_line.rotation = Vector3.ZERO
	aim_line.rotation.y = atan2(delta.x, delta.z)


func _update_current_interactable() -> void:
	var nearest: Node3D = null
	var nearest_distance := INTERACT_RANGE

	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D):
			continue
		var interactable := node as Node3D
		if bool(interactable.get_meta("disabled", false)):
			continue
		var distance := player.global_position.distance_to(interactable.global_position)
		if distance <= nearest_distance:
			nearest = interactable
			nearest_distance = distance

	current_interactable = nearest
	if current_interactable == null:
		prompt_label.visible = false
	else:
		prompt_label.text = "按 E %s" % String(current_interactable.get_meta("prompt", "互动"))
		prompt_label.visible = true


func _interact_with(interactable: Node3D) -> void:
	var interact_id := String(interactable.get_meta("interact_id", ""))
	match interact_id:
		"note":
			has_read_note = true
			interactable.set_meta("disabled", true)
			_show_message("纸条上写着：\n去小巷子。\n别让他们看见。")
			_show_hint("沿丁字口下方的小巷一直往前走。")
		"alley_end":
			_teleport_player(Vector3(0.0, 0.72, -76.0))
			_show_message("巷子尽头出现了一栋二层楼。\n它不该在这里。")
			_show_hint("调查 42号楼的一层正门。")
		"front_door":
			_show_message("门从里面锁住了。\n门缝里没有光。")
			_show_hint("找找别的入口。")
		"stair":
			_teleport_player(Vector3(24.5, 0.72, -79.6))
			_show_message("外侧楼梯踩上去有点空。\n你到了二层露天走廊。")
			_show_hint("进入房间 A，找找能用的东西。")
		"snap_cabinet":
			if has_snap:
				_show_message("柜子里只剩一点纸屑。")
			else:
				has_snap = true
				current_weapon = WEAPON_SNAP
				_show_message("柜子里有一盒摔炮。")
				_show_hint("左键投掷摔炮，炸开纸人 A。")
		"cracker_box":
			if not paper_a_cleared:
				_show_message("纸人挡着路。\n先处理它。")
			elif has_cracker:
				_show_message("桌上只剩擦过的火柴痕。")
			else:
				has_cracker = true
				current_weapon = WEAPON_CRACKER
				_show_message("这盒擦炮还没受潮。\n点着以后，别拿太久。")
				_show_hint("右键点火，左键投掷擦炮，炸开纸人 B。")
		"roof_entry":
			if not roof_route_open:
				_show_message("走廊尽头还被纸人挡着。")
			else:
				_teleport_player(Vector3(58.5, 0.72, -80.0))
				_show_message("你从断开的护栏翻了过去。\n旁边房顶比走廊更安静。")
				_show_hint("沿房顶往右走，找到跳下点。")
		"roof_drop":
			_teleport_player(Vector3(77.0, 0.72, -80.0))
			_show_message("你跳进两栋楼之间的夹缝。\n这里风进不来，声音也出不去。")
			_show_hint("调查夹缝里的名册碎页。")
		"roster":
			if got_roster:
				return
			got_roster = true
			demo_finished = true
			end_overlay.visible = true
			_show_message("这是一张从旧本子上撕下来的纸。\n上面有几个名字。\n最后一行空着。\n\n你站在两栋楼之间。\n学校的声音已经完全听不见了。\n\n书包里多了一张纸。\n纸背面写着：\n\n鬼屋是真的，别乱说。\n\nDemo 结束\n你已经被“鬼屋调查团”注意到了。")


func _teleport_player(target_position: Vector3) -> void:
	player.global_position = target_position
	player.velocity = Vector3.ZERO
	_update_camera()


func _try_select_weapon(weapon: String) -> void:
	if weapon == WEAPON_SNAP:
		if not has_snap:
			_show_hint("还没有摔炮。")
			return
		current_weapon = WEAPON_SNAP
		_show_hint("当前武器：摔炮")
	elif weapon == WEAPON_CRACKER:
		if not has_cracker:
			_show_hint("还没有擦炮。")
			return
		current_weapon = WEAPON_CRACKER
		cracker_lit = false
		cracker_fuse = 0.0
		_show_hint("当前武器：擦炮")


func _try_light_current_weapon() -> void:
	if current_weapon == WEAPON_NONE:
		_show_hint("还没有能点着的东西。")
		return
	if current_weapon == WEAPON_SNAP:
		_show_hint("摔炮不用点。")
		return
	if cracker_lit:
		_show_hint("擦炮已经点着了。")
		return

	cracker_lit = true
	cracker_fuse = CRACKER_FUSE_TIME
	_show_hint("点着了。别拿太久。")


func _try_throw_current_weapon() -> void:
	if throw_cooldown > 0.0:
		return

	if current_weapon == WEAPON_NONE:
		_show_hint("还没有能丢的东西。")
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
		"kind": kind,
		"velocity": aim_direction * speed,
		"age": 0.0,
		"flight_time": flight_time,
		"fuse": fuse,
		"radius": radius,
		"arc_height": arc_height,
		"moving": true,
	})


func _update_cracker_fuse(delta: float) -> void:
	if not cracker_lit:
		return

	cracker_fuse -= delta
	if cracker_fuse <= 0.0:
		cracker_lit = false
		_create_explosion(player.global_position, CRACKER_EXPLOSION_RADIUS, WEAPON_CRACKER)
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
			_create_explosion(node.global_position, float(projectile["radius"]), String(projectile["kind"]))
			node.queue_free()
			projectiles.remove_at(i)


func _create_explosion(world_position: Vector3, radius: float, kind: String) -> void:
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
	mesh_instance.set_surface_override_material(0, _material(Color(1.0, 0.70, 0.18, 0.72)))
	marker.add_child(mesh_instance)

	explosions.append({
		"node": marker,
		"time": 0.32,
	})
	_hit_targets(world_position, radius, kind)


func _hit_targets(world_position: Vector3, radius: float, kind: String) -> void:
	for target in targets:
		if bool(target.get_meta("hit", false)):
			continue
		var required_weapon := String(target.get_meta("required_weapon", WEAPON_NONE))
		if required_weapon != WEAPON_NONE and required_weapon != kind:
			continue
		var distance := Vector2(target.global_position.x - world_position.x, target.global_position.z - world_position.z).length()
		if distance > radius:
			continue

		target.set_meta("hit", true)
		_disable_target(target)
		var target_id := String(target.get_meta("target_id", ""))
		if target_id == "paper_a":
			paper_a_cleared = true
			_show_message("纸人散了一地。\n走廊那边有风吹出来。")
			_show_hint("进入房间 C，找到擦炮。")
		elif target_id == "paper_b":
			paper_b_cleared = true
			roof_route_open = true
			if roof_entry != null:
				roof_entry.set_meta("disabled", false)
			_show_message("爆炸声在楼道里绕了一圈。\n走廊尽头有什么东西松开了。")
			_show_hint("从走廊尽头翻到旁边房顶。")


func _disable_target(target: Node3D) -> void:
	for child in target.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
		elif child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	_add_label(target, "散了一地", Vector3(0.0, 0.1, 0.0))


func _update_explosions(delta: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var explosion := explosions[i]
		explosion["time"] = float(explosion["time"]) - delta
		var marker := explosion["node"] as Node3D
		if float(explosion["time"]) <= 0.0:
			marker.queue_free()
			explosions.remove_at(i)


func _update_ui() -> void:
	var weapon_text := "无"
	if current_weapon == WEAPON_SNAP:
		weapon_text = "摔炮"
	elif current_weapon == WEAPON_CRACKER:
		weapon_text = "擦炮"
	weapon_label.text = "当前武器：%s    1 摔炮  2 擦炮" % weapon_text

	if current_weapon == WEAPON_CRACKER:
		if cracker_lit:
			status_label.text = "点火状态：已点燃  倒计时：%.1f" % maxf(cracker_fuse, 0.0)
		else:
			status_label.text = "点火状态：未点火"
	elif current_weapon == WEAPON_SNAP:
		status_label.text = "点火状态：摔炮不用点火"
	else:
		status_label.text = "WASD 移动  鼠标瞄准  左键投掷  右键点火  E 互动"


func _show_hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


func _show_message(text: String) -> void:
	message_open = true
	can_move = false
	prompt_label.visible = false
	message_label.text = text
	message_panel.visible = true


func _hide_message() -> void:
	message_open = false
	message_panel.visible = false
	can_move = not demo_finished


func _add_shop(parent: Node, label_text: String, pos: Vector3, color: Color) -> void:
	_add_solid_box(parent, "%s_Building" % label_text, Vector3(pos.x, pos.y, pos.z), Vector3(4.6, 1.6, 2.2), color)
	_add_label_marker(parent, label_text, Vector3(pos.x, pos.y + 1.25, pos.z))


func _add_room(parent: Node, room_label: String, center_xz: Vector2, node_prefix: String) -> void:
	var x := center_xz.x
	var z := center_xz.y
	_add_floor(parent, "%s_Floor" % node_prefix, Vector3(x, -0.05, z), Vector3(7.0, 0.12, 6.5), Color(0.44, 0.45, 0.42))
	_add_solid_box(parent, "%s_BackWall" % node_prefix, Vector3(x, 1.1, z - 3.25), Vector3(7.2, 2.2, 0.35), COLOR_WALL)
	_add_solid_box(parent, "%s_LeftWall" % node_prefix, Vector3(x - 3.5, 1.1, z), Vector3(0.35, 2.2, 6.5), COLOR_WALL_DARK)
	_add_solid_box(parent, "%s_RightWall" % node_prefix, Vector3(x + 3.5, 1.1, z), Vector3(0.35, 2.2, 6.5), COLOR_WALL_DARK)
	_add_solid_box(parent, "%s_FrontWallLeft" % node_prefix, Vector3(x - 2.0, 1.1, z + 3.25), Vector3(3.0, 2.2, 0.35), COLOR_WALL)
	_add_solid_box(parent, "%s_FrontWallRight" % node_prefix, Vector3(x + 2.0, 1.1, z + 3.25), Vector3(3.0, 2.2, 0.35), COLOR_WALL)
	_add_label_marker(parent, room_label, Vector3(x, 1.25, z + 2.5))


func _add_paper_target(parent: Node, node_name: String, target_id: String, required_weapon: String, pos: Vector3, size: Vector3, label_text: String) -> StaticBody3D:
	var target := StaticBody3D.new()
	target.name = node_name
	target.position = pos
	target.collision_layer = 1
	target.collision_mask = 1
	target.set_meta("target_id", target_id)
	target.set_meta("required_weapon", required_weapon)
	target.set_meta("hit", false)
	parent.add_child(target)
	targets.append(target)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _material(COLOR_PAPER_MAN))
	target.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	target.add_child(collision)

	_add_label(target, label_text, Vector3(0.0, 1.25, 0.0))
	return target


func _add_interactable(parent: Node, node_name: String, interact_id: String, prompt: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.set_meta("interact_id", interact_id)
	node.set_meta("prompt", prompt)
	node.add_to_group("interactable")
	parent.add_child(node)
	return node


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
	label.font_size = 30
	label.modulate = Color(1.0, 1.0, 1.0)
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
