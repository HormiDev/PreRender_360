extends LinkButton

@onready var icon: TextureRect = $TextureRect


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if icon == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "self_modulate", Color(1.25, 1.25, 1.25, 1.0), 0.15)


func _on_mouse_exited() -> void:
	if icon == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
