extends CharacterBody3D

const LOOK_SENSITIVITY := 0.1
const MAX_PITCH := 89.0
const INTERACT_DISTANCE := 25.0
const EDGE_PAN_MARGIN := 120.0
const EDGE_PAN_YAW_DEGREES := 40.0
const EDGE_PAN_PITCH_DEGREES := 28.0

@onready var camera: Camera3D = $Camera3D

var monitor_mode := false
var active_computer: Node = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if not monitor_mode:
		return

	_apply_monitor_edge_panning(delta)
	_forward_hover_to_monitor()


func _input(event: InputEvent) -> void:
	if monitor_mode:
		_handle_monitor_mode_input(event)
		return

	if event is InputEventMouseMotion:
		_apply_camera_look(event.relative)
		return

	if event.is_action_pressed("interact"):
		_try_enter_monitor_mode()


func _handle_monitor_mode_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_exit_monitor_mode()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_forward_mouse_button_to_monitor(event)
			return

	if event is InputEventMouseMotion:
		_forward_hover_to_monitor()


func _try_enter_monitor_mode() -> void:
	var hit = _raycast_from_camera(_get_ray_screen_position())
	var computer = _get_computer_from_hit(hit)
	if computer == null:
		return

	if not computer.begin_interaction(self):
		return

	active_computer = computer
	monitor_mode = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _exit_monitor_mode() -> void:
	if _has_active_computer():
		active_computer.end_interaction()

	active_computer = null
	monitor_mode = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var center = get_viewport().get_visible_rect().size * 0.5
	get_viewport().warp_mouse(center)


func _forward_mouse_button_to_monitor(event: InputEventMouseButton) -> void:
	if not _has_active_computer():
		return

	var hit = _raycast_from_camera(get_viewport().get_mouse_position())
	var computer = _get_computer_from_hit(hit)
	if computer == null or computer != active_computer:
		return

	active_computer.forward_mouse_button(
		hit.position,
		event.button_index,
		event.pressed,
		event.button_mask,
		event.double_click
	)


func _forward_hover_to_monitor() -> void:
	if not _has_active_computer():
		return

	var hit = _raycast_from_camera(get_viewport().get_mouse_position())
	var computer = _get_computer_from_hit(hit)
	if computer == null or computer != active_computer:
		return

	active_computer.forward_mouse_motion(hit.position)


func _raycast_from_camera(screen_position: Vector2) -> Dictionary:
	if camera == null:
		return {}

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var ray_end := ray_origin + ray_direction * INTERACT_DISTANCE

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self]

	return get_world_3d().direct_space_state.intersect_ray(query)


func _get_computer_from_hit(hit: Dictionary) -> Node:
	if hit.is_empty():
		return null

	var collider = hit.get("collider")
	if collider == null or not (collider is Node):
		return null

	var current: Node = collider
	while current:
		if current.has_method("begin_interaction") and current.has_method("forward_mouse_button"):
			return current
		current = current.get_parent()

	return null


func _get_ray_screen_position() -> Vector2:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return get_viewport().get_visible_rect().size * 0.5
	return get_viewport().get_mouse_position()


func _has_active_computer() -> bool:
	return active_computer != null and is_instance_valid(active_computer)


func _apply_camera_look(mouse_delta: Vector2) -> void:
	if camera == null:
		return

	rotate_y(deg_to_rad(-mouse_delta.x * LOOK_SENSITIVITY))
	var camera_rotation = camera.rotation_degrees
	camera_rotation.x = clamp(camera_rotation.x - mouse_delta.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
	camera.rotation_degrees = camera_rotation


func _apply_monitor_edge_panning(delta: float) -> void:
	if camera == null:
		return

	var viewport_rect := get_viewport().get_visible_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return

	var mouse_position := get_viewport().get_mouse_position()
	var yaw_input := 0.0
	if mouse_position.x < EDGE_PAN_MARGIN:
		yaw_input = 1.0 - (mouse_position.x / EDGE_PAN_MARGIN)
	elif mouse_position.x > viewport_rect.size.x - EDGE_PAN_MARGIN:
		yaw_input = -((mouse_position.x - (viewport_rect.size.x - EDGE_PAN_MARGIN)) / EDGE_PAN_MARGIN)

	if not is_zero_approx(yaw_input):
		rotate_y(deg_to_rad(yaw_input * EDGE_PAN_YAW_DEGREES * delta))

	var pitch_input := 0.0
	if mouse_position.y < EDGE_PAN_MARGIN:
		pitch_input = -(1.0 - (mouse_position.y / EDGE_PAN_MARGIN))
	elif mouse_position.y > viewport_rect.size.y - EDGE_PAN_MARGIN:
		pitch_input = (mouse_position.y - (viewport_rect.size.y - EDGE_PAN_MARGIN)) / EDGE_PAN_MARGIN

	if is_zero_approx(pitch_input):
		return

	var camera_rotation = camera.rotation_degrees
	camera_rotation.x = clamp(camera_rotation.x + (pitch_input * EDGE_PAN_PITCH_DEGREES * delta), -MAX_PITCH, MAX_PITCH)
	camera.rotation_degrees = camera_rotation

