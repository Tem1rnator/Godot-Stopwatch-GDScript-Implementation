extends Node
class_name Stopwatch
## This node allows the user to keep track of elapsed time and provides utility methods to format that time.
## Stopwatch's time can be scaled by the Engine's time_scale and a custom time scale.


## If true, the stopwatch will start immediately when it enters the scene tree.
@export var autostart := false

## If true, pauses the stopwatch after reset() is called.
@export var pause_on_reset := false

## Determines whether the stopwatch is currently counting time.
var paused := true:
	set = _set_paused

## Total elapsed time in microseconds since the start of the stopwatch (excluding paused periods, scales with the current time scale mode).
var elapsed_usec: float = 0:   # this variable is a float isntead of an int because of possible non-integer time scaling.
	get = get_total_elapsed_microseconds


## Defines the two methods used for tracking time. Both methods can still be scaled by Engine.time_scale and custom_time_scale
enum TimeMode {
	EngineDelta,       # Better for tracking in-game time.
	# Delta-based approach: Tracks time by accumulating delta time every process physics frame or process frame, depending on the process_callback variable.
	# May deviate from real-world time at very low FPS to match game slowdowns (see Node's _process() function documentation about physics spiral of death).
	
	EngineTimestamp    # Better for tracking real-world time.
	# Timestamp-based approach: Tracks time using a "timestamp", i.e. the value of Time.get_ticks_usec() at certain points in time.
	# Will NOT deviate from real-world time, so it may be punishing during game slowdowns at very low FPS.
}

## The current time tracking mode
@export var time_mode := TimeMode.EngineDelta:
	set = set_time_mode


## Utility variable for TimeMode.EngineTimestamp
## The timestamp (i.e. value returned by Time.get_ticks_usec()) that specifies the time this stopwatch was previously up to date with.
## This variable helps accumulate uncounted because the Stopwatch doesn't update the elapsed time every frame.
var _latest_update_timestamp: int = Time.get_ticks_usec()


## Defines two delta time accumulation methods when time_mode == EngineDelta
enum StopwatchProcessCallback {
	ProcessPhysics,  # Update the stopwatch every physics process frame (see Node.NOTIFICATION_INTERNAL_PHYSICS_PROCESS).
	ProcessIdle      # Update the stopwatch every process (rendered) frame (see Node.NOTIFICATION_INTERNAL_PROCESS).
}

## Determines whether the delta time under TimeMode.EngineDelta will be accumulated during every physics process frame or process frame
@export var process_callback := StopwatchProcessCallback.ProcessIdle:
	set = set_process_callback


@export_category('Time Scale')
## If true, the stopwatch will scale with Engine.time_scale (can stack with custom_time_scale)
@export var use_engine_time_scale := false

## If true, the stopwatch will scale with custom_time_scale (can stack with Engine.time_scale)
@export var use_custom_time_scale := false

## Multiplier applied to elapsed time when use_custom_time_scale is true.
@export var custom_time_scale: float = 1.0:
	set = _set_custom_time_scale

## Cached value of Engine.time_scale. This is used to react to changes in Engine.time_scale
var _saved_engine_time_scale: float = 1.0



func _ready() -> void:
	#Engine.time_scale_changed.connect(_on_engine_time_scale_changed)
	# if this Engine signal existed, this is how Stopwatch would react to changes in Engine.time_scale instead of polling it in _process()
	
	if autostart:
		start()
	
	set_process_callback(process_callback)   # enforcing current process callback


#region process methods
func _process(delta: float) -> void:
	_processing(delta)


func _physics_process(delta: float) -> void:
	_processing(delta)


func _processing(delta: float) -> void:
	if time_mode == TimeMode.EngineDelta and not paused:
		accumulate_elapsed_time_with_delta(delta)
	
	# Check for changes to Engine.time_scale and call the _on_engine_time_scale_changed() method accordingly.
	# This is a workaround because Engine currently has no time_scale_changed signal.
	if Engine.time_scale != _saved_engine_time_scale:
		_on_engine_time_scale_changed(Engine.time_scale)
#endregion


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


#region Updating elapsed time
## Updates elapsed_usec to accumulate all the uncounted time since _latest_update_timestamp.
## Will not accumulate time if it was in a pause.
## This method only has an effect if time_mode == TimeMode.EngineTimestamp
func _update_elapsed_time() -> void:
	if time_mode != TimeMode.EngineTimestamp:
		return
	if paused:  # not updating elapsed time since the timestamp if it's a pause timestamp
		return
	if Time.get_ticks_usec() == _latest_update_timestamp:
		return
	
	elapsed_usec += _get_elapsed_time_since_timestamp()


## Returns the amount of time (in microseconds) since _latest_update_timestamp, adjusted by the current time scale mode.
## Also refreshes _latest_update_timestamp to the current time.
func _get_elapsed_time_since_timestamp() -> float:
	var elapsed_time_since_timestamp_unscaled: int = Time.get_ticks_usec() - _latest_update_timestamp
	_latest_update_timestamp = Time.get_ticks_usec()
	
	var elapsed_time_since_timestamp: float = elapsed_time_since_timestamp_unscaled   # float because time_scaled can be a non-integer number
	
	if not use_engine_time_scale:
		elapsed_time_since_timestamp *= Engine.time_scale
	if use_custom_time_scale:
		elapsed_time_since_timestamp *= custom_time_scale
	
	return elapsed_time_since_timestamp


## Method that accumulates elapsed time using delta
## Used only when time_mode == TimeMode.EngineDelta
func accumulate_elapsed_time_with_delta(delta: float) -> void:
	var scaled_delta := delta * 1_000_000  # converting to microseconds
	
	if not use_engine_time_scale:
		scaled_delta *= Engine.time_scale
	if use_custom_time_scale:
		scaled_delta *= custom_time_scale
	
	elapsed_usec += scaled_delta
#endregion


#region Setters
## Setter for paused.
func _set_paused(new_pause_state: bool) -> void:
	if paused == new_pause_state:   # doing nothing when paused doesn't change
		return
	
	if new_pause_state:
		# Pausing: first accumulate any uncounted time since last update
		_update_elapsed_time()
		paused = true
	else:
		# Resuming: reset timestamp so next accumulation starts from now
		_latest_update_timestamp = Time.get_ticks_usec()
		paused = false


## Setter for time_mode
func set_time_mode(new_mode: TimeMode) -> void:
	if time_mode == TimeMode.EngineTimestamp and new_mode == TimeMode.EngineDelta:
		_update_elapsed_time()
	if time_mode == TimeMode.EngineDelta and new_mode == TimeMode.EngineTimestamp:
		_latest_update_timestamp = Time.get_ticks_usec()
	
	time_mode = new_mode


## Setter for process_callback
func set_process_callback(new_process_callback: StopwatchProcessCallback) -> void:
	process_callback = new_process_callback
	
	if process_callback == StopwatchProcessCallback.ProcessPhysics:
		set_physics_process(true)
		set_process(false)
	elif process_callback == StopwatchProcessCallback.ProcessIdle:
		set_physics_process(false)
		set_process(true)
#endregion


#region Time scale
## Called when Engine.time_scale changes (detected manually in _process() as a workaround for now).
func _on_engine_time_scale_changed(new_scale: float) -> void:
	_update_elapsed_time()
	_saved_engine_time_scale = new_scale


## Setter for custom_time_scale.
func _set_custom_time_scale(new_scale: float) -> void:
	_update_elapsed_time()
	custom_time_scale = new_scale
#endregion


#region Total time methods
## Returns the total elapsed time in microseconds.
## Also makes sure the elapsed_usec is up to date before returning. All other get_total_* methods below work the same way.
func get_total_elapsed_microseconds() -> float:
   # only updating elapsed time if Stopwatch isn't paused and the timestamp isn't up to date
	if time_mode == TimeMode.EngineTimestamp and not paused and _latest_update_timestamp != Time.get_ticks_usec():
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
## Breaks down the elapsed time into individual units (hours, minutes, seconds, etc.) and returns them as integer values in a dictionary.
## Values are cyclic (e.g., seconds/hours wrap from 0 to 59, milliseconds/microseconds from 0 to 999)
func get_time_dict() -> Dictionary[String, int]:
	var time_dict: Dictionary[String, int] = {
		"microseconds": int(elapsed_usec) % 1000,
		"milliseconds": int(get_total_elapsed_milliseconds()) % 1000,
		"seconds": int(get_total_elapsed_seconds()) % 60,
		"minutes": int(get_total_elapsed_minutes()) % 60,
		"hours": int(get_total_elapsed_hours()),
	}
	
	return time_dict


## Same as get_time_dict() but with each value as a string.
## Also includes *_padded variants for display (e.g., "07" seconds instead of "7", "003" milliseconds instead of "3").
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


## Returns a formatted elapsed time string in hh:mm:ss or hh:mm:ss:ms format.
## Optionally, a custom delimiter can be passed as a parameter (default is ':').
func get_time_string(display_milliseconds := true, delimiter := ':') -> String:
	var time_dict_strings = get_time_dict_strings()
	
	var result: String = time_dict_strings["hours_padded"] + delimiter
	result += time_dict_strings["minutes_padded"] + delimiter
	result += time_dict_strings["seconds_padded"]
	
	if display_milliseconds:
		result += delimiter + time_dict_strings["milliseconds_padded"]
	
	return result
#endregion
