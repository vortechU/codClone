extends Node

# Data
@export var data = {}
const save_path = "user://data"

# Capabilities
@export var autoload = false
@export var autosave = false
@export var interval = 60

# Developer Options
var encryption = true ## Never change if the project was executed before!

func _ready() -> void:
	if autoload:
		load_data()
	if autosave:
		$Timer.wait_time = interval
		$Timer.start()

func save_data() -> void:
	var file
	if encryption:
		file = FileAccess.open_encrypted_with_pass(save_path, FileAccess.WRITE, "thunderwasherein2025")
	else:
		file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(data)
	file.close()

func load_data() -> void:
	if FileAccess.file_exists(save_path):
		var file
		if encryption:
			file = FileAccess.open_encrypted_with_pass(save_path, FileAccess.READ, "thunderwasherein2025")
		else:
			file = FileAccess.open(save_path, FileAccess.READ)
		data = file.get_var()
		file.close()

func _on_timer_timeout() -> void:
	save_data()
