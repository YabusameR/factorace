extends Control

signal start_requested


func _ready() -> void:
	%StartButton.pressed.connect(func() -> void: start_requested.emit())
	%StartButton.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
		start_requested.emit()
		get_viewport().set_input_as_handled()
