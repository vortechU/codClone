extends Node3D

signal map_transition_requested(event_id: String, destination_scene: String)

@onready var monitor_mesh: MeshInstance3D = $Monitor
@onready var interaction_area: Area3D = $Area3D
@onready var sub_viewport: SubViewport = $SubViewport
@onready var event_list: VBoxContainer = get_node_or_null("SubViewport/Control/CenterPanel/EventList")
@onready var cancel_button: Button = get_node_or_null("SubViewport/Control/CenterPanel/EventList/CancelButton")

const EVENT_SCENES := {
	"deploy_level_test": "res://Scenes/level_test.tscn"
}
const FADE_DURATION_SECONDS := 0.35
const MATRIX_TRANSITION_SHADER := preload("res://Scenes/Shaders/matrix_transition.gdshader")

var active_operator: Node = null
var _last_viewport_position: Vector2 = Vector2.ZERO
var _has_last_viewport_position := false
var _transition_in_progress := false
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null

func _ready() -> void:
	if interaction_area:
		interaction_area.add_to_group("computer_monitor_area")
	_wire_buttons()


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


func _wire_buttons() -> void:
	if event_list == null:
		push_warning("[Computer] Missing EventList in monitor UI")
		return

	for child in event_list.get_children():
		if child == null or not (child is Button):
			continue

		var event_button := child as Button
		if event_button == cancel_button:
			continue

		event_button.pressed.connect(_on_event_button_pressed.bind(event_button))

	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)


func _on_event_button_pressed(event_button: Button) -> void:
	if event_button == null or not is_instance_valid(event_button):
		return

	if not event_button.has_meta("event_id"):
		push_warning("[Computer] Button %s is missing event_id metadata" % event_button.name)
		return

	var event_id: String = str(event_button.get_meta("event_id"))
	if event_id.is_empty():
		push_warning("[Computer] Button %s has empty event_id metadata" % event_button.name)
		return

	_request_event_transition(event_id)


func _on_cancel_pressed() -> void:
	_release_operator_control()


func _request_event_transition(event_id: String) -> void:
	if _transition_in_progress:
		return

	if not EVENT_SCENES.has(event_id):
		push_warning("[Computer] Unknown event id: %s" % event_id)
		return

	var destination_scene: String = EVENT_SCENES[event_id]
	if not ResourceLoader.exists(destination_scene, "PackedScene"):
		push_error("[Computer] Destination scene not found: %s" % destination_scene)
		return

	emit_signal("map_transition_requested", event_id, destination_scene)
	_transition_in_progress = true
	_release_operator_control()
	await _fade_to_black(FADE_DURATION_SECONDS)

	var scene_change_result := get_tree().change_scene_to_file(destination_scene)
	if scene_change_result != OK:
		push_error("[Computer] Failed to change scene to %s (error %d)" % [destination_scene, scene_change_result])
		_transition_in_progress = false
		_reset_fade_overlay()


func _release_operator_control() -> void:
	if active_operator == null or not is_instance_valid(active_operator):
		end_interaction()
		return

	if active_operator.has_method("_exit_monitor_mode"):
		active_operator.call("_exit_monitor_mode")
		return

	end_interaction()


func _fade_to_black(duration_seconds: float) -> void:
	_ensure_fade_overlay()
	if _fade_rect == null:
		return

	_fade_rect.visible = true
	_set_transition_progress(0.0)

	var tween := create_tween()
	tween.tween_method(_set_transition_progress, 0.0, 1.0, duration_seconds)
	await tween.finished


func _ensure_fade_overlay() -> void:
	if _fade_layer != null and is_instance_valid(_fade_layer):
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = self

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	_fade_layer.name = "SceneTransitionFade"

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_attach_transition_shader()

	_fade_layer.add_child(_fade_rect)
	scene_root.add_child(_fade_layer)


func _reset_fade_overlay() -> void:
	if _fade_rect != null and is_instance_valid(_fade_rect):
		_set_transition_progress(0.0)
		_fade_rect.visible = false


func _attach_transition_shader() -> void:
	if _fade_rect == null:
		return

	if MATRIX_TRANSITION_SHADER == null:
		push_warning("[Computer] Missing Matrix transition shader")
		return

	var shader_material := ShaderMaterial.new()
	shader_material.shader = MATRIX_TRANSITION_SHADER
	shader_material.set_shader_parameter("progress", 0.0)
	_fade_rect.material = shader_material


func _set_transition_progress(value: float) -> void:
	if _fade_rect == null:
		return

	var clamped_value := clampf(value, 0.0, 1.0)

	if _fade_rect.material is ShaderMaterial:
		(_fade_rect.material as ShaderMaterial).set_shader_parameter("progress", clamped_value)

	# Keep alpha fallback so scene changes still fade if shader fails.
	_fade_rect.color.a = clamped_value


func forward_mouse_button(world_position: Vector3, button_index: int, pressed: bool, button_mask: int = 0, double_click: bool = false) -> void:
	if active_operator == null or not is_instance_valid(active_operator):
		return

	var viewport_position = _world_to_viewport_position(world_position)
	if viewport_position == null:
		return

	var mouse_button_event := InputEventMouseButton.new()
	mouse_button_event.position = viewport_position
	mouse_button_event.global_position = viewport_position
	mouse_button_event.button_index = button_index as MouseButton
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
