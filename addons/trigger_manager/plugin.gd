@tool
extends EditorPlugin


var icon = preload("res://addons/trigger_manager/icons/icon.svg")
var icon_resource = preload("res://addons/trigger_manager/icons/icon_trigger_res.svg")

var script_main = preload("res://addons/trigger_manager/trigger_manager.gd")
var script_resource = preload("res://addons/trigger_manager/trigger_config.gd")


func _enable_plugin() -> void:
	add_custom_type("TriggerManager", "Node", script_main, icon)
	add_custom_type("TriggerData", "Resource", script_resource, icon_resource)


func _disable_plugin() -> void:
	remove_custom_type("TriggerManager")
	remove_custom_type("TriggerData")
