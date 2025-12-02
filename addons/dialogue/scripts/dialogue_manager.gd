extends Node

# Signals
signal showed_message(message: String, character_number: int)
signal made_choice(choice: String, message: String)

# Exported Variables
@export_enum("Subtitle", "Text Box") var style: int = 0

@export_group("Settings")
@export var show_name: bool = true
@export var typing_animation: bool = true
@export var auto_skip: bool = false
@export_subgroup("Text Box")
@export var show_avatar_: bool = true
@export var swap_speaker: bool = true

@export_group("Characters")
@export_subgroup("First Character")
@export var name_: String = "Steve"
@export_color_no_alpha var name_color_: Color = Color.CYAN
@export var avatar_: Texture2D
@export_subgroup("Second Character")
@export var name__: String = "Alex"
@export_color_no_alpha var name_color__: Color = Color.HOT_PINK
@export var avatar__: Texture2D

# Reference Variables
@onready var message_timer = $message_timer
@onready var click_detector = $click_detector
@onready var choice_timer = $choice_timer

@onready var subtitles = $Subtitle/HBoxContainer
@onready var subtitles_name = $Subtitle/HBoxContainer/Label
@onready var subtitles_message = $Subtitle/HBoxContainer/Label2
@onready var subtitles_bar = $Subtitle/ProgressBar
@onready var choices_grid = $Subtitle/GridContainer

@onready var text_boxes = $TextBox/HBoxContainer
@onready var text_boxes_content = $TextBox/HBoxContainer/VBoxContainer
@onready var text_boxes_name = $TextBox/HBoxContainer/VBoxContainer/Label
@onready var text_boxes_message = $TextBox/HBoxContainer/VBoxContainer/Label2
@onready var text_boxes_avatar = $TextBox/HBoxContainer/TextureRect

# Functional Variables
var separator = ";"
var messages: PackedStringArray = []
var message_position = -1
var message_timeouts = []

var selecting_choice = {
	"condition": false,
	"dialogue": {}
}

var tween

# Processing
func _ready() -> void:
	refresh()

func start(chosen_dialogue: String):
	set_physics_process(true)

	if style == 0:
		$Subtitle.show()
	else:
		$TextBox.show()

	if not get_node_or_null(chosen_dialogue):
		push_error("Error: Invalid dialogue provided.")
		return

	messages = get_node(chosen_dialogue).messages

	for dialogue in messages:
		var parts = dialogue.split(separator)
		message_timeouts.append(int(parts[2]))

	if style == 0:
		if not show_name:
			subtitles_name.hide()
	else:
		if not show_name:
			text_boxes_name.hide()
		if not show_avatar_:
			text_boxes_avatar.hide()

	if auto_skip:
		auto_advance_message()
	else:
		advance_message()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if style == 0 and not auto_skip and not selecting_choice.condition:
			advance_message()
		elif style == 1 and not auto_skip:
			advance_message()

func advance_message():
	message_position += 1

	if message_position >= messages.size():
		queue_free()
		return

	var dialogue = messages[message_position].split(separator)
	var speaker = dialogue[0]
	var text = dialogue[1]
	var time = int(dialogue[2])

	if speaker == "1":
		_show_character_dialogue(name_, name_color_, avatar_, text, 1)
	elif speaker == "2":
		_show_character_dialogue(name__, name_color__, avatar__, text, 2)

	if typing_animation:
		type_message(time)

	if dialogue.size() >= 4 and style == 0:
		selecting_choice.condition = true
		click_detector.hide()
		selecting_choice.dialogue = dialogue

		if not auto_skip:
			if typing_animation:
				message_timer.wait_time = time * 0.6
				message_timer.start()
			else:
				add_choices(dialogue)
	else:
		choice_timer.wait_time = time
		choice_timer.start()

	emit_signal("showed_message", text, int(speaker))

func _show_character_dialogue(name_text: String, color: Color, avatar: Texture2D, message: String, speaker_id: int):
	var localized_name = name_text
	var localized_message = message
	var lm = get_node_or_null("localization_manager")

	if lm:
		localized_name = lm.translated(name_text)
		localized_message = lm.translated(message)

	if style == 0:
		subtitles_name.modulate = color
		subtitles_name.text = localized_name + ":"
		subtitles_message.text = localized_message
		if typing_animation:
			subtitles_message.visible_ratio = 0
	else:
		text_boxes_name.modulate = color
		text_boxes_name.text = localized_name
		text_boxes_message.text = localized_message
		text_boxes_avatar.texture = avatar
		if typing_animation:
			text_boxes_message.visible_ratio = 0
		if swap_speaker:
			_adjust_textbox_layout(speaker_id)

func _adjust_textbox_layout(speaker_id: int):
	if speaker_id == 1:
		text_boxes_content.move_to_front()
		text_boxes_name.set_h_size_flags(Control.SIZE_SHRINK_BEGIN)
		text_boxes_message.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_LEFT)
	else:
		text_boxes_avatar.move_to_front()
		text_boxes_name.set_h_size_flags(Control.SIZE_SHRINK_END)
		text_boxes_message.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_RIGHT)

func auto_advance_message():
	advance_message()
	if message_position < messages.size():
		message_timer.wait_time = message_timeouts[message_position]
		message_timer.start()

func continue_to(chosen_dialogue: String):
	refresh()
	start(chosen_dialogue)

func refresh():
	selecting_choice.dialogue.clear()
	tween_out_subtitles_bar()
	remove_choices()
	messages = []
	message_position = -1
	message_timeouts = []
	selecting_choice = { "condition": false, "dialogue": {} }
	tween = null
	set_physics_process(false)
	$Subtitle.hide()
	$TextBox.hide()

func _on_click_detector_pressed() -> void:
	if style == 0 and not auto_skip and not selecting_choice.condition:
		advance_message()
	elif style == 1 and not auto_skip:
		advance_message()
	click_detector.hide()

func _on_choice_timer_timeout() -> void:
	click_detector.show()

func _on_message_timer_timeout() -> void:
	if auto_skip:
		if style == 0:
			if selecting_choice.condition:
				selecting_choice.condition = false
				click_detector.hide()
				message_timer.wait_time = int(selecting_choice.dialogue[3])
				tween_in_subtitles_bar()
				add_choices(selecting_choice.dialogue)
				message_timer.start()
			else:
				if not selecting_choice.dialogue.is_empty():
					var temp = selecting_choice.dialogue[1]
					refresh()
					emit_signal("made_choice", "", temp)
				else:
					auto_advance_message()
		elif style == 1:
			auto_advance_message()
	else:
		if style == 0:
			add_choices(selecting_choice.dialogue)

func selected_choice(choice: String) -> void:
	var temp = selecting_choice.dialogue[1]
	refresh()
	emit_signal("made_choice", choice, temp)

func add_choices(dialogue: Array):
	var choices_amount = 0
	for pos in dialogue.size():
		if pos >= 4:
			choices_amount += 1
			var button = load("res://addons/dialogue/scenes/button.tscn").instantiate()
			var lm = get_node_or_null("localization_manager")
			if lm:
				button.text = lm.translated(dialogue[pos])
			else:
				button.text = dialogue[pos]
			button.choice = dialogue[pos]
			button.selected_choice.connect(selected_choice)
			choices_grid.add_child(button)
	choices_grid.columns = choices_amount

func remove_choices():
	for child in choices_grid.get_children():
		child.queue_free()

func tween_in_subtitles_bar():
	subtitles_bar.value = 100
	subtitles_bar.show()
	tween = create_tween()
	tween.tween_property(subtitles_bar, "value", 0, int(selecting_choice.dialogue[3]) * 0.9).set_trans(Tween.TRANS_SINE)

func tween_out_subtitles_bar():
	subtitles_bar.hide()

func type_message(show_time: int):
	if tween != null:
		tween.kill()
	tween = create_tween()
	if style == 0:
		tween.tween_property(subtitles_message, "visible_ratio", 1, show_time * 0.6)
	else:
		tween.tween_property(text_boxes_message, "visible_ratio", 1, show_time * 0.6)
