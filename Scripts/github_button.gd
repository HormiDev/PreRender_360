extends LinkButton

@onready var icon: TextureRect = $TextureRect


# Description: Connects hover signals for the GitHub button icon animation.
# Args: none
# Returns: void
func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# Description: Brightens the icon when the mouse enters the button area.
# Args: none
# Returns: void
func _on_mouse_entered() -> void:
	if icon == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "self_modulate", Color(1.25, 1.25, 1.25, 1.0), 0.15)


# Description: Restores icon color when the mouse exits the button area.
# Args: none
# Returns: void
func _on_mouse_exited() -> void:
	if icon == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
