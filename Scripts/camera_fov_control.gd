extends Control

@export var camera_paths: Array[NodePath] = []
@export var min_fov := 1.0
@export var max_fov := 179.0
@export var default_fov := 45.0

@onready var _slider: HSlider = $CameraFovSlider
@onready var _spinbox: SpinBox = $CameraFovSpinBox


func _ready() -> void:
	_slider.min_value = min_fov
	_slider.max_value = max_fov
	_spinbox.min_value = min_fov
	_spinbox.max_value = max_fov

	var initial_fov := _get_first_camera_fov(default_fov)
	_slider.set_value_no_signal(clampf(initial_fov, min_fov, max_fov))
	_spinbox.set_value_no_signal(_slider.value)
	_apply_fov(_slider.value)

	if not _slider.value_changed.is_connected(_on_fov_changed):
		_slider.value_changed.connect(_on_fov_changed)
	if not _spinbox.value_changed.is_connected(_on_fov_changed):
		_spinbox.value_changed.connect(_on_fov_changed)


func _draw() -> void:
	if _slider == null:
		return

	var preview_rect := Rect2(Vector2(0.0, 0.0), Vector2(94.0, 66.0))
	var lens_origin := Vector2(preview_rect.position.x + 44.0, preview_rect.position.y + preview_rect.size.y * 0.5)
	var half_angle := deg_to_rad(float(_slider.value) * 0.5)
	var upper_ray := _get_ray_end(lens_origin, -half_angle, preview_rect)
	var lower_ray := _get_ray_end(lens_origin, half_angle, preview_rect)

	var cone_points := PackedVector2Array([
		lens_origin,
		upper_ray,
		lower_ray
	])
	draw_colored_polygon(cone_points, Color(0.38, 0.78, 1.0, 0.18))
	draw_polyline(PackedVector2Array([lens_origin, upper_ray]), Color(0.38, 0.78, 1.0, 0.9), 1.5)
	draw_polyline(PackedVector2Array([lens_origin, lower_ray]), Color(0.38, 0.78, 1.0, 0.9), 1.5)
	_draw_fov_arc(lens_origin, half_angle)


func _get_ray_end(origin: Vector2, angle: float, bounds: Rect2) -> Vector2:
	var direction := Vector2(cos(angle), sin(angle))
	var max_distance := INF

	if direction.x > 0.001:
		max_distance = minf(max_distance, (bounds.end.x - origin.x) / direction.x)
	if direction.y > 0.001:
		max_distance = minf(max_distance, (bounds.end.y - origin.y) / direction.y)
	elif direction.y < -0.001:
		max_distance = minf(max_distance, (bounds.position.y - origin.y) / direction.y)

	return origin + direction * max_distance


func _draw_fov_arc(origin: Vector2, half_angle: float) -> void:
	var points := PackedVector2Array()
	var radius := 18.0
	var segments := 24
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := lerpf(-half_angle, half_angle, t)
		points.append(origin + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, Color(0.38, 0.78, 1.0, 0.65), 1.25)


func _get_first_camera_fov(fallback: float) -> float:
	for camera_path in camera_paths:
		var camera := get_node_or_null(camera_path) as Camera3D
		if camera != null:
			return camera.fov

	return fallback


func _on_fov_changed(value: float) -> void:
	var fov := clampf(value, min_fov, max_fov)
	_slider.set_value_no_signal(fov)
	_spinbox.set_value_no_signal(fov)
	_apply_fov(fov)
	queue_redraw()


func _apply_fov(value: float) -> void:
	var fov := clampf(value, min_fov, max_fov)
	for camera_path in camera_paths:
		var camera := get_node_or_null(camera_path) as Camera3D
		if camera != null:
			camera.fov = fov
