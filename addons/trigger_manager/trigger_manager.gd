@tool
@icon("res://addons/trigger_manager/icons/icon.svg")

## Trigger Manager is a plugin for Godot that allows you to create and manage a list of timed triggers directly from the Inspector. 
## Each trigger uses SceneTreeTimer to fire events at the configured time, and when activated, 
## the plugin emits a signal containing the corresponding trigger name. Ideal for sequences, cutscenes, gameplay logic, and any situation 
## where it's necessary to schedule actions in a simple, organized, and centralized way.
class_name TriggerManager extends Node


#region EXPORTS ****************************************
## Disables the emission of the trigger_fired signal.
@export var disable_triggers: bool = false: get = get_disable_triggers, set = set_disable_triggers

## The list of configurable triggers.
@export var triggers: Array[TriggerConfig]: get = get_triggers, set = set_triggers
#endregion *********************************************


#region SIGNALS ****************************************
## A signal is emitted whenever a trigger finishes its timeout.
signal trigger_fired(trigger_name: String)
#endregion *********************************************


#region PRIVATE PROPERTIES *****************************
#endregion *********************************************


#region PUBLIC PROPERTIES ******************************
#endregion *********************************************


#region ENGINE METHODS *********************************
func _ready() -> void:
	for trigger in triggers:
		if trigger:
			trigger._init_owner(self, trigger.name, trigger.time, trigger.repeat, trigger.process_always, trigger.process_in_physics, trigger.ignore_time_scale)
			trigger.start(self)
			
	
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var count_names: int = 0
	
	for trigger in triggers:
		if trigger:
			if trigger.name.strip_edges() == "":
				warnings.append("There are triggers without defined names. Consider assigning a unique name to each trigger in the Godot inspector.")
				
			for trigger2 in triggers:
				if trigger2:
					if not trigger == trigger2 and trigger.name == trigger2.name:
						count_names += 1
		else:
			warnings.append("A trigger has been added but not configured. Consider configuring this trigger or deleting it if you will not be using it.")
	
	if count_names > 0:
		warnings.append("There are triggers with the same names. Consider giving each trigger a unique name.")
	return warnings
#endregion *********************************************


#region PRIVATE METHODS ********************************
func _has_trigger_with_name(trigger_name: String) -> bool:
	for trigger in triggers:
		if trigger:
			if trigger.name == trigger_name:
				return true
	return false
#endregion *********************************************


#region PUBLIC METHODS *********************************
## Add a new trigger.
func add_trigger(trigger_name: String, time: float, repeat: bool) -> void:
	if not _has_trigger_with_name(trigger_name):
		var new_trigger: TriggerConfig = TriggerConfig.new(self, trigger_name, time, repeat)
		triggers.append(new_trigger)
		new_trigger.start(self)
		return
	push_warning("The trigger named %s was not added because one with the same name already exists. Consider adding triggers with unique names." %trigger_name)
	
	
## Remove a new trigger.
func remove_trigger(trigger_name: String) -> void:
	var find_index: int = triggers.find_custom(func(trigger: TriggerConfig): return trigger.name == trigger_name)
	if find_index >= 0:
		triggers[find_index].destroy()
		triggers.remove_at(find_index)
		return
	push_warning("The trigger named %s was not found to be removed. Please verify the trigger name is correct."%trigger_name)
#endregion *********************************************


#region GETTERS ****************************************
func get_disable_triggers() -> bool:
	return disable_triggers
	
	
func get_triggers() -> Array[TriggerConfig]:
	return triggers
#endregion *********************************************


#region SETTERS ****************************************
func set_disable_triggers(value: bool) -> void:
	disable_triggers = value
	
	
func set_triggers(value: Array[TriggerConfig]) -> void:
	triggers = value
	for trigger in triggers:
		if trigger:
			trigger._init_owner(self, trigger.name, trigger.time, trigger.repeat, trigger.process_always, trigger.process_in_physics, trigger.ignore_time_scale)
	
	update_configuration_warnings()
#endregion *********************************************
