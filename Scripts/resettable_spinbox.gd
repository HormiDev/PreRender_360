extends SpinBox

@export var reset_button_text := "↺"
@export var reset_button_tooltip := "Reset to original value"
@export var reset_button_tooltip_key := "reset_button_tooltip"
@export var reset_button_gap := 4.0
@export var reset_button_width := 22.0
@export var reset_button_tolerance: float = 0.05

var _original_value: float = 0.0
var _last_observed_value: float = 0.0
var _last_language_code := ""
var _reset_button: Button
var _language_selector: Node = null


func _ready() -> void:
	_original_value = value
	_last_observed_value = value
	_language_selector = _find_language_selector()
	_update_reset_button_tooltip()
	value_changed.connect(_on_value_changed)
	resized.connect(_update_reset_button_layout)
	set_process(true)
	call_deferred("_create_reset_button")
	_update_reset_button_visibility()


func _create_reset_button() -> void:
	if _reset_button != null:
		return

	var parent := get_parent()
	if parent == null:
		return

	_reset_button = Button.new()
	_reset_button.text = reset_button_text
	_update_reset_button_tooltip()
	_reset_button.visible = true
	_reset_button.focus_mode = Control.FOCUS_NONE
	_reset_button.custom_minimum_size = Vector2(reset_button_width, 0.0)
	_reset_button.pressed.connect(_on_reset_button_pressed)

	call_deferred("_attach_reset_button")


func _attach_reset_button() -> void:
	if _reset_button == null:
		return

	var parent := get_parent()
	if parent == null:
		return

	if _reset_button.get_parent() == null:
		parent.add_child(_reset_button)
	if _reset_button.get_parent() == parent:
		parent.move_child(_reset_button, get_index() + 1)

	_update_reset_button_layout()
	_update_reset_button_visibility()


func _update_reset_button_layout() -> void:
	if _reset_button == null:
		return

	var parent := get_parent()
	if parent == null:
		return

	if parent is Container:
		return

	_reset_button.position = Vector2(position.x + size.x + reset_button_gap, position.y)
	_reset_button.size = Vector2(reset_button_width, size.y)


func _update_reset_button_visibility() -> void:
	if _reset_button == null:
		return

	var should_show: bool = abs(value - _original_value) > reset_button_tolerance
	_reset_button.visible = true
	_reset_button.disabled = not should_show
	_reset_button.mouse_filter = Control.MOUSE_FILTER_STOP if should_show else Control.MOUSE_FILTER_IGNORE
	_reset_button.modulate.a = 1.0 if should_show else 0.0


func _update_reset_button_tooltip() -> void:
	if _reset_button == null:
		return

	if _language_selector != null and _language_selector.has_method("get_text"):
		_reset_button.tooltip_text = str(_language_selector.call("get_text", reset_button_tooltip_key))
	else:
		_reset_button.tooltip_text = reset_button_tooltip


func _find_language_selector() -> Node:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return null
	return scene.find_child("LanguageSelector", true, false)


func _process(_delta: float) -> void:
	if is_equal_approx(value, _last_observed_value):
		pass
	else:
		_last_observed_value = value
		_update_reset_button_visibility()

	var language_code := ""
	if _language_selector != null and _language_selector.has_method("get_current_language"):
		language_code = str(_language_selector.call("get_current_language"))
	if language_code != _last_language_code:
		_last_language_code = language_code
		_update_reset_button_tooltip()


func _on_value_changed(_new_value: float) -> void:
	_last_observed_value = value
	_update_reset_button_visibility()
	_update_reset_button_tooltip()


func _on_reset_button_pressed() -> void:
	value = _original_value
	_last_observed_value = value
	_update_reset_button_visibility()
