extends Button

signal selected_choice(choice: String)

var choice: String

func _on_pressed() -> void:
	emit_signal("selected_choice", choice)
