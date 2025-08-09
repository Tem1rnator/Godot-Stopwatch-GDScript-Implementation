extends Node
class_name Stopwatch
## This node allows the user to keep track of elapsed time and provides utility methods to format that time.
## Stopwatch's time can be scaled by the Engine's time_scale, a custom time scale, or follow real-world time.


## If true, the stopwatch will start immediately when it enters the scene tree.
@export var autostart := false

## If true, pauses the stopwatch after reset() is called.
@export var pause_on_reset := true

## Determines whether the stopwatch is currently counting time.
var paused := true:
	set = _set_paused

## Total elapsed time in microseconds since the start (excluding paused periods, scales with the current time scale mode).
var elapsed_usec: float = 0:   # this variable is a float isntead of an int because of possible non-integer time scaling.
	get = get_elapsed_usec

## The timestamp (i.e. value returned by Time.get_ticks_usec()) of the last time elapsed_usec variable was updated.
var _latest_update_timestamp: int = Time.get_ticks_usec()


#region Time scaling
## Specifies how elapsed time should be scaled.
enum TimeScaleMode {
	EngineTimeScale,  # Scaled by Engine.time_scale
	CustomTimeScale,  # Scaled by custom_time_scale
	RealTimeScale     # Scaled by 1.0 (real-world time)
}

@export_category('Time Scale')
## Specifies which time scaling mode this stopwatch is currently using.
@export var time_scale_mode := TimeScaleMode.EngineTimeScale

## Multiplier applied to elapsed time when in CustomTimeScale mode.
@export var custom_time_scale: float = 1.0:
	set = _set_custom_time_scale

## Cached copy of Engine.time_scale value (since Godot has no Engine.time_scale_changed signal)
var _saved_engine_time_scale: float = 1.0
#endregion



func _ready() -> void:
	#Engine.time_scale_changed.connect(_on_engine_time_scale_changed)
	# if this Engine signal existed, this is how Stopwatch would react to changes in Engine.time_scale instead of polling it in _process()
	
	if autostart:
		start()


## Poll for changes to Engine.time_scale and update state accordingly.
## This is a workaround because Engine currently has no time_scale_changed signal.
func _process(delta: float) -> void:
	if Engine.time_scale != _saved_engine_time_scale:
		_on_engine_time_scale_changed(Engine.time_scale)


## Starts the stopwatch or resumes it if it was paused.
func start() -> void:
	paused = false


## Pauses the stopwatch.
func pause() -> void:
	paused = true


## Resets stopwatch to 0 and pauses it if pause_on_reset is true.
func reset() -> void:
	elapsed_usec = 0
	_latest_update_timestamp = Time.get_ticks_usec()
	
	if pause_on_reset:
		paused = true


## Setter for paused.
func _set_paused(new_pause_state: bool) -> void:
	if paused == new_pause_state:   # doing nothing when paused is set to the same state
		return
	
	if new_pause_state:
		# Pausing: first accumulate any uncounted time since last update
		_update_elapsed_time()
		paused = true
	else:
		# Resuming: reset timestamp so next accumulation starts from now
		_latest_update_timestamp = Time.get_ticks_usec()
		paused = false


#region Updating elapsed time
## TODO comment
func _update_elapsed_time() -> void:
	if paused:   # not updating elapsed time since the timestamp if it's a pause timestamp
		return
	
	elapsed_usec += _get_elapsed_time_since_timestamp()


## TODO comment
func _get_elapsed_time_since_timestamp() -> float:
	var elapsed_time_since_timestamp_unscaled: int = Time.get_ticks_usec() - _latest_update_timestamp
	_latest_update_timestamp = Time.get_ticks_usec()
	
	var elapsed_time_since_timestamp: float   # float because time_scaled can be a non-integer number
	
	match time_scale_mode:
		TimeScaleMode.EngineTimeScale:
			elapsed_time_since_timestamp = _saved_engine_time_scale * elapsed_time_since_timestamp_unscaled
		TimeScaleMode.CustomTimeScale:
			elapsed_time_since_timestamp = custom_time_scale * elapsed_time_since_timestamp_unscaled
		TimeScaleMode.RealTimeScale:
			elapsed_time_since_timestamp = 1 * elapsed_time_since_timestamp_unscaled
	
	return elapsed_time_since_timestamp
#endregion


#region Time scale
func _on_engine_time_scale_changed(new_scale: float) -> void:
	_update_elapsed_time()
	_saved_engine_time_scale = new_scale


func _set_custom_time_scale(new_scale: float) -> void:
	_update_elapsed_time()
	custom_time_scale = new_scale
#endregion


#region Total time methods
## Returns the total elapsed time since the start of the stopwatch in microseconds.
func get_elapsed_usec() -> float:
	if not paused and _latest_update_timestamp != Time.get_ticks_usec():   # only updating elapsed time if Stopwatch isn't paused and the timestamp isn't up to date
		elapsed_usec += _get_elapsed_time_since_timestamp()
	
	return elapsed_usec

func get_total_elapsed_milliseconds() -> float:
	return elapsed_usec / (1000)

func get_total_elapsed_seconds() -> float:
	return elapsed_usec / (1000 * 1000)

func get_total_elapsed_minutes() -> float:
	return elapsed_usec / (1000 * 1000 * 60)

func get_total_elapsed_hours() -> float:
	return elapsed_usec / (1000 * 1000 * 60 * 60)

func get_total_elapsed_days() -> float:   # maybe don't need this
	return elapsed_usec / (1000 * 1000 * 60 * 60 * 24)
#endregion


#region Formatted time methods
## Returns a dictionary with the elapsed time that is converted into larger time values.
func get_time_dict() -> Dictionary[String, int]:
	var time_dict: Dictionary[String, int] = {
		"microseconds": int(elapsed_usec) % 1000,
		"milliseconds": int(get_total_elapsed_milliseconds()) % 1000,
		"seconds": int(get_total_elapsed_seconds()) % 60,
		"minutes": int(get_total_elapsed_minutes()) % 60,
		"hours": int(get_total_elapsed_hours()),
	}
	
	return time_dict


## Returns the absolute value of the result of get_time_dict() but converted into strings
## There are also *_padded time values
func get_time_dict_strings() -> Dictionary[String, String]:
	var time_dict := get_time_dict()
	var time_dict_strings: Dictionary[String, String] = {
		"microseconds": str(abs(time_dict["microseconds"])),
		"milliseconds": str(abs(time_dict["milliseconds"])),
		"seconds": str(abs(time_dict["seconds"])),
		"minutes": str(abs(time_dict["minutes"])),
		"hours": str(abs(time_dict["hours"])),
	}
	
	time_dict_strings["hours_padded"] = time_dict_strings["hours"].lpad(2, "0")
	time_dict_strings["minutes_padded"] = time_dict_strings["minutes"].lpad(2, "0")
	time_dict_strings["seconds_padded"] = time_dict_strings["seconds"].lpad(2, "0")
	time_dict_strings["milliseconds_padded"] = time_dict_strings["milliseconds"].lpad(3, "0")
	
	return time_dict_strings


## Returns a string of the elapsed time as an hh:mm:ss or hh:mm:ss:ms string, optionally with a custom delimiter
func get_time_string(display_milliseconds := false, delimiter := ':') -> String:
	var time_dict_strings = get_time_dict_strings()
	
	var result: String = time_dict_strings["hours_padded"] + delimiter
	result += time_dict_strings["minutes_padded"] + delimiter
	result += time_dict_strings["seconds_padded"]
	
	if display_milliseconds:
		result += delimiter + time_dict_strings["milliseconds_padded"]
	
	return result
#endregion
