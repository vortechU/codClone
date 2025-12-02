@tool
@icon("res://addons/trigger_manager/icons/icon_trigger_res.svg")

## Resource used by TriggerManager to create triggers.
class_name TriggerConfig extends Resource


#region EXPORTS ****************************************
## The name of the trigger.
@export_placeholder("Trigger name") var name: String: get = get_name, set = set_name

## The time of the trigger.
## When this value is changed, the time becomes that new value and starts counting again, if it is running.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var time: float = 0.0: get = get_time, set = set_time

## If true, the trigger will be emitted repeatedly.
@export var repeat: bool = false: get = get_repeat, set = set_repeat

## If param process_always is false, the timer will be paused when setting SceneTree.paused to true.
@export var process_always: bool = true: get = get_process_always, set = set_process_always

## If param process_in_physics is true, the timer will update at the end of the physics frame, instead of the process frame.
@export var process_in_physics: bool = false: get = get_process_in_physics, set = set_process_in_physics

## If param ignore_time_scale is true, the timer will ignore Engine.time_scale and update with the real, elapsed time.
@export var ignore_time_scale: bool = false: get = get_ignore_time_scale, set = set_ignore_time_scale
#endregion *********************************************


#region PRIVATE PROPERTIES *****************************
var _owner: TriggerManager
var _timer: SceneTreeTimer
#endregion *********************************************


#region PUBLIC PROPERTIES ******************************
## Returns whether the timer is busy or idle.
var is_busy: bool = false


## The time remaining (in seconds).
var time_left: float = 0.0:
	get():
		if not is_instance_valid(_timer): return 0.0
		return _timer.time_left
	set(value):
		push_warning("time_left is readonly.")
#endregion *********************************************


#region ENGINE METHODS *********************************
func _init(p_owner: TriggerManager = null, p_name: String = "", p_time: float = 0.0, p_repeat: bool = false) -> void:
	name = p_name
	time = p_time
	repeat = p_repeat
#endregion *********************************************


#region PRIVATE METHODS ********************************
func _init_owner(p_owner: TriggerManager, _name: String, _time: float, _repeat: bool, _process_always: bool, _process_in_physics: bool, _ignore_time_scale: bool) -> void:
	_owner = p_owner
	name = _name
	time = _time
	repeat = _repeat
	process_always = _process_always
	process_in_physics = _process_in_physics
	ignore_time_scale = _ignore_time_scale
	

func _on_timeout() -> void:
	if Engine.is_editor_hint(): return
	if is_instance_valid(_owner):
		if not _owner.disable_triggers: _owner.trigger_fired.emit(name)
		if repeat:
			_timer = _owner.get_tree().create_timer(time, process_always, process_in_physics, ignore_time_scale)
			if not _timer.timeout.is_connected(_on_timeout):
				_timer.timeout.connect(_on_timeout)
		else:
			is_busy = false
#endregion *********************************************


#region PUBLIC METHODS *********************************
func start(p_owner: TriggerManager) -> SceneTreeTimer:
	_owner = p_owner
	if is_instance_valid(_owner):
		is_busy = true
		_timer = _owner.get_tree().create_timer(time, process_always, process_in_physics, ignore_time_scale)
		if not _timer.timeout.is_connected(_on_timeout):
			_timer.timeout.connect(_on_timeout)
		return _timer
	return null
	
	
func destroy() -> void:
	if is_instance_valid(_timer):
		if _timer.timeout.is_connected(_on_timeout):
			_timer.timeout.disconnect(_on_timeout)
		is_busy = false
		_timer.time_left = 0
#endregion *********************************************


#region GETTERS ****************************************
func get_name() -> String:
	return name
	
	
func get_time() -> float:
	return time
	
	
func get_repeat() -> bool:
	return repeat


func get_process_always() -> bool:
	return process_always
		
		
func get_process_in_physics() -> bool:
	return process_in_physics
		

func get_ignore_time_scale() -> bool:
	return ignore_time_scale

#endregion *********************************************


#region SETTERS ****************************************
## Change the timer's name. Remember: the name must be unique.
func set_name(value: String) -> void:
	name = value
	if is_instance_valid(_owner):
		_owner.update_configuration_warnings()
	
	
## Change the team's value. When this value is changed, the team becomes that new value and starts counting again.
func set_time(value: float) -> void:
	time = value
	if is_instance_valid(_owner):
		if is_instance_valid(_timer):
			_timer = _owner.get_tree().create_timer(time, process_always, process_in_physics, ignore_time_scale)
		_owner.update_configuration_warnings()


## If true, the timer will repeat indefinitely.
func set_repeat(value: bool) -> void:
	repeat = value
	if is_instance_valid(_owner):
		_owner.update_configuration_warnings()
		

## If false, the timer will be paused when setting SceneTree.paused to true.
func set_process_always(value: bool) -> void:
	process_always = value
	if is_instance_valid(_timer):
		_timer = _owner.get_tree().create_timer(_timer.get_time_left(), process_always, process_in_physics, ignore_time_scale)
		
		
## If true, the timer will update at the end of the physics frame, instead of the process frame.
func set_process_in_physics(value: bool) -> void:
	process_in_physics = value
	if is_instance_valid(_timer):
		_timer = _owner.get_tree().create_timer(_timer.get_time_left(), process_always, process_in_physics, ignore_time_scale)
		

## If true, the timer will ignore Engine.time_scale and update with the real, elapsed time.
func set_ignore_time_scale(value: bool) -> void:
	ignore_time_scale = value
	if is_instance_valid(_timer):
		_timer = _owner.get_tree().create_timer(_timer.get_time_left(), process_always, process_in_physics, ignore_time_scale)
#endregion *********************************************
