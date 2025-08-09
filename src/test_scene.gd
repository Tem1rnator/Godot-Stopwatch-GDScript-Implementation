extends Control


@export var stopwatch: Stopwatch
@export var time_label: Label


func _process(delta: float) -> void:
	time_label.text = stopwatch.get_time_string(true, '.')


#region Buttons
func _on_start_button_pressed() -> void:
	stopwatch.start()

func _on_pause_button_pressed() -> void:
	stopwatch.pause()

func _on_reset_button_pressed() -> void:
	stopwatch.reset()
#endregion


#region Time Scale
func _on_time_scale_option_button_item_selected(index: int) -> void:
	stopwatch.time_scale_mode = index as Stopwatch.TimeScaleMode


func _on_engine_time_scale_line_edit_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		Engine.time_scale = new_text.to_float()


func _on_custom_time_scale_line_edit_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		stopwatch.custom_time_scale = new_text.to_float()
#endregion

