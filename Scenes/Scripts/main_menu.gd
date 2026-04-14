extends Control
@onready var scoreLabel: Label = $Score
@onready var loadedScene: PackedScene = preload("res://Scenes/office.tscn")
func _ready() -> void:
	var highScore = SaveManager.load_score()
	scoreLabel.text = "Best Score: " + str(highScore)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_packed(loadedScene)


func _input(_event):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	
