extends Control


@export var stopwatch: Stopwatch
@export var time_label: Label


var is_lag_on := false


enum UpdateLabelMode {
	EveryFrame,
	Intermittently
}
var update_label_mode := UpdateLabelMode.EveryFrame


func _process(delta: float) -> void:
	if update_label_mode == UpdateLabelMode.EveryFrame:
		time_label.text = stopwatch.get_time_string()
	
	if is_lag_on:
		OS.delay_msec(200)


#region Buttons
func _on_start_button_pressed() -> void:
	stopwatch.start()

func _on_pause_button_pressed() -> void:
	stopwatch.pause()

func _on_reset_button_pressed() -> void:
	stopwatch.reset()
#endregion


#region Time Scale
func _on_engine_time_scale_check_box_toggled(toggled_on: bool) -> void:
	stopwatch.use_engine_time_scale = toggled_on


func _on_custom_time_scale_check_box_toggled(toggled_on: bool) -> void:
	stopwatch.use_custom_time_scale = toggled_on


func _on_engine_time_scale_line_edit_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		Engine.time_scale = new_text.to_float()


func _on_custom_time_scale_line_edit_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		stopwatch.custom_time_scale = new_text.to_float()
#endregion


func _on_time_mode_option_button_item_selected(index: int) -> void:
	stopwatch.time_mode = index as Stopwatch.TimeMode


func _on_process_callback_option_button_item_selected(index: int) -> void:
	stopwatch.process_callback = index as Stopwatch.StopwatchProcessCallback


func _on_simulate_lag_check_button_toggled(toggled_on: bool) -> void:
	is_lag_on = toggled_on



func _on_timer_timeout() -> void:
	if update_label_mode == UpdateLabelMode.Intermittently:
		time_label.text = stopwatch.get_time_string()


func _on_option_button_item_selected(index: int) -> void:
	update_label_mode = index as UpdateLabelMode
