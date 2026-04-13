extends Node3D

@onready var monitor_mesh: MeshInstance3D = $Monitor
@onready var interaction_area: Area3D = $Area3D
@onready var sub_viewport: SubViewport = $SubViewport

var active_operator: Node = null
var _last_viewport_position: Vector2 = Vector2.ZERO
var _has_last_viewport_position := false

func _ready() -> void:
	if interaction_area:
		interaction_area.add_to_group("computer_monitor_area")


func begin_interaction(operator: Node) -> bool:
	if operator == null or not is_instance_valid(operator):
		return false
	if active_operator != null and is_instance_valid(active_operator) and active_operator != operator:
		return false
	active_operator = operator
	_has_last_viewport_position = false
	return true


func end_interaction() -> void:
	active_operator = null
	_has_last_viewport_position = false


func forward_mouse_button(world_position: Vector3, button_index: int, pressed: bool, button_mask: int = 0, double_click: bool = false) -> void:
	if active_operator == null or not is_instance_valid(active_operator):
		return

	var viewport_position = _world_to_viewport_position(world_position)
	if viewport_position == null:
		return

	var mouse_button_event := InputEventMouseButton.new()
	mouse_button_event.position = viewport_position
	mouse_button_event.global_position = viewport_position
	mouse_button_event.button_index = button_index
	mouse_button_event.pressed = pressed
	mouse_button_event.button_mask = button_mask
	mouse_button_event.double_click = double_click
	sub_viewport.push_input(mouse_button_event)

	_last_viewport_position = viewport_position
	_has_last_viewport_position = true


func forward_mouse_motion(world_position: Vector3) -> void:
	if active_operator == null or not is_instance_valid(active_operator):
		return

	var viewport_position = _world_to_viewport_position(world_position)
	if viewport_position == null:
		return

	var mouse_motion_event := InputEventMouseMotion.new()
	mouse_motion_event.position = viewport_position
	mouse_motion_event.global_position = viewport_position
	if _has_last_viewport_position:
		mouse_motion_event.relative = viewport_position - _last_viewport_position
	else:
		mouse_motion_event.relative = Vector2.ZERO
	mouse_motion_event.button_mask = Input.get_mouse_button_mask()
	sub_viewport.push_input(mouse_motion_event)

	_last_viewport_position = viewport_position
	_has_last_viewport_position = true


func _world_to_viewport_position(world_position: Vector3):
	if monitor_mesh == null or sub_viewport == null:
		return null

	var quad_mesh := monitor_mesh.mesh as QuadMesh
	if quad_mesh == null:
		return null

	var quad_size := quad_mesh.size
	if is_zero_approx(quad_size.x) or is_zero_approx(quad_size.y):
		return null

	var local_hit := monitor_mesh.to_local(world_position)
	var u := (local_hit.x / quad_size.x) + 0.5
	var v := 0.5 - (local_hit.y / quad_size.y)

	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return null

	var viewport_size := sub_viewport.size
	return Vector2(u * float(viewport_size.x), v * float(viewport_size.y))
