@tool
extends Control

signal rotation_changed(pitch_degrees: float, yaw_degrees: float, roll_degrees: float)
signal rotation_delta(pitch_delta: float, yaw_delta: float, roll_delta: float)

enum InteractionMode {
	NONE,
	TRACKBALL,
	ROLL_RING
}

@export var drag_sensitivity: float = 0.35
@export var ring_thickness: float = 2.0
@export var sphere_fill: Color = Color(0.16, 0.18, 0.22, 1.0)
@export var x_axis_color: Color = Color(0.92, 0.27, 0.24, 0.92)
@export var y_axis_color: Color = Color(0.23, 0.80, 0.38, 0.92)
@export var z_axis_color: Color = Color(0.25, 0.56, 0.98, 0.92)
@export var ring_highlight: Color = Color(1.0, 1.0, 1.0, 0.902)
@export var ring_samples: int = 256

const ROLL_RING_MARGIN_RATIO: float = 0.03
var pitch_degrees: float = 0.0
var yaw_degrees: float = 0.0
var roll_degrees: float = 0.0
var _interaction_mode: int = InteractionMode.NONE
var _last_drag_position: Vector2 = Vector2.ZERO
var _last_ring_angle: float = 0.0
var _hover_outer_ring: bool = false
var _rotation_basis: Basis = Basis.IDENTITY

# ---------- READY ----------
# Description: Initializes the control with mouse input and sets minimum size.
# Args: none
# Returns: void
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240, 180)
	queue_redraw()

# ---------- SETTERS ----------
# Description: Sets the rotation of the sphere using euler angles in degrees.
# Args: pitch (float) — rotation around X axis, yaw (float) — rotation around Y axis, roll (float) — rotation around Z axis
# Returns: void
func set_sphere_rotation(pitch: float, yaw: float, roll: float = 0.0) -> void:
	pitch_degrees = pitch
	yaw_degrees = yaw
	roll_degrees = roll
	_rotation_basis = _build_rotation_basis()
	queue_redraw()

# Description: Sets the rotation of the sphere using a basis matrix.
# Args: basis (Basis) — orthonormalized rotation basis
# Returns: void
func set_sphere_basis(basis: Basis) -> void:
	_rotation_basis = basis.orthonormalized()
	_sync_rotation_degrees_from_basis()
	queue_redraw()

# ---------- INPUT ----------
# Description: Handles mouse input for trackball rotation and ring (roll) control.
# Args: event (InputEvent) — input event from mouse
# Returns: void
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_interaction_mode = _pick_interaction_mode(event.position)
			# Solo aceptar si está dentro del círculo
			if _interaction_mode == InteractionMode.NONE:
				return
			_last_drag_position = event.position
			_last_ring_angle = _pointer_angle(event.position)
			_hover_outer_ring = _interaction_mode == InteractionMode.ROLL_RING
		else:
			_interaction_mode = InteractionMode.NONE
			_hover_outer_ring = false
		accept_event()
	elif event is InputEventMouseMotion and _interaction_mode != InteractionMode.NONE:
		if _interaction_mode == InteractionMode.TRACKBALL:
			var delta: Vector2 = event.position - _last_drag_position
			_last_drag_position = event.position
			var dp: float = delta.y * drag_sensitivity
			var dy: float = delta.x * drag_sensitivity
			var drag_basis: Basis = Basis(Vector3.UP, deg_to_rad(dy)) * Basis(Vector3.RIGHT, deg_to_rad(dp))
			_rotation_basis = (drag_basis * _rotation_basis).orthonormalized()
			_sync_rotation_degrees_from_basis()
			rotation_delta.emit(dp, dy, 0.0)
		else:
			var current_angle: float = _pointer_angle(event.position)
			var angle_delta: float = rad_to_deg(wrapf(current_angle - _last_ring_angle, -PI, PI))
			_last_ring_angle = current_angle
			# Apply roll as a rotation in screen space so the projected axes follow the ring drag.
			_rotation_basis = (Basis(Vector3.FORWARD, deg_to_rad(-angle_delta)) * _rotation_basis).orthonormalized()
			_sync_rotation_degrees_from_basis()
			rotation_delta.emit(0.0, 0.0, -angle_delta)
		rotation_changed.emit(pitch_degrees, yaw_degrees, roll_degrees)
		_hover_outer_ring = _pick_interaction_mode(event.position) == InteractionMode.ROLL_RING
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		_hover_outer_ring = _pick_interaction_mode(event.position) == InteractionMode.ROLL_RING
		queue_redraw()

# ---------- DRAWING ----------
# Description: Renders the 3D rotation sphere with axis rings and interactive elements.
# Args: none
# Returns: void
func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var padding: float = 10.0
	var sphere_rect: Rect2 = rect.grow_individual(-padding, -padding, -padding, -padding)
	var radius: float = min(sphere_rect.size.x, sphere_rect.size.y) * 0.5
	var center: Vector2 = sphere_rect.get_center()
	var visible_radius: float = radius * 0.98

	draw_circle(center, visible_radius, sphere_fill)
	draw_arc(center, visible_radius, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.16), ring_thickness, true)

	_draw_projected_ring_fast(center, visible_radius, _rotation_basis, Vector3.RIGHT, x_axis_color)
	_draw_projected_ring_fast(center, visible_radius, _rotation_basis, Vector3.UP, y_axis_color)
	_draw_projected_ring_fast(center, visible_radius, _rotation_basis, Vector3.FORWARD, z_axis_color)
	draw_outer_roll_ring(center, visible_radius, Color(0.646, 0.646, 0.646, 0.9))

	var front_vector: Vector3 = _rotation_basis * Vector3.BACK
	var handle_pos: Vector2 = center + Vector2(front_vector.x, -front_vector.y) * visible_radius * 0.65
	var front_depth: float = clamp(0.5 + front_vector.z * 0.5, 0.0, 1.0)
	var handle_color: Color = _shade_ring_color(ring_highlight, front_depth)
	draw_circle(handle_pos, 6.0, handle_color)
	draw_circle(handle_pos, 3.0, Color(0.08, 0.08, 0.08, 0.95))

# ---------- INTERACTION ----------
# Description: Determines the interaction mode (trackball, roll ring, or none) based on mouse position.
# Args: pos (Vector2) — mouse position in screen coordinates
# Returns: int — InteractionMode (NONE, TRACKBALL, or ROLL_RING)
func _pick_interaction_mode(pos: Vector2) -> int:
	var geometry: Dictionary = _get_geometry()
	var center: Vector2 = geometry["center"]
	var visible_radius: float = geometry["radius"]
	var distance: float = pos.distance_to(center)
	
	# Rechazar clicks fuera del círculo (con 5% de tolerancia)
	if distance > visible_radius * 1.05:
		return InteractionMode.NONE
	
	# Detectar si está en el anillo exterior (últimos 5% del radio)
	if distance >= visible_radius * 0.95:
		return InteractionMode.ROLL_RING
	return InteractionMode.TRACKBALL

# Description: Calculates the angle from center to mouse position for roll control.
# Args: pos (Vector2) — mouse position in screen coordinates
# Returns: float — angle in radians from -π to π
func _pointer_angle(pos: Vector2) -> float:
	var geometry: Dictionary = _get_geometry()
	var center: Vector2 = geometry["center"]
	return atan2(center.y - pos.y, pos.x - center.x)

# Description: Calculates the sphere geometry (center and radius) from the control size.
# Args: none
# Returns: Dictionary — with keys "center" (Vector2) and "radius" (float)
func _get_geometry() -> Dictionary:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var padding: float = 10.0
	var sphere_rect: Rect2 = rect.grow_individual(-padding, -padding, -padding, -padding)
	var radius: float = min(sphere_rect.size.x, sphere_rect.size.y) * 0.5
	return {
		"center": sphere_rect.get_center(),
		"radius": radius * 0.98
	}

# ---------- ROTATION GETTERS ----------
# Description: Returns the current rotation basis.
# Args: none
# Returns: Basis — orthonormalized rotation basis
func _get_rotation_basis() -> Basis:
	return _rotation_basis

# ---------- ROTATION BUILDERS ----------
# Description: Builds a rotation basis from euler angles (pitch, yaw, roll in degrees).
# Args: none (uses internal pitch_degrees, yaw_degrees, roll_degrees)
# Returns: Basis — rotation matrix combining all three rotations
func _build_rotation_basis() -> Basis:
	var pitch: float = deg_to_rad(pitch_degrees)
	var yaw: float = deg_to_rad(yaw_degrees)
	var roll: float = deg_to_rad(roll_degrees)
	return Basis.from_euler(Vector3(pitch, yaw, roll))

# Description: Synchronizes euler angle degrees from the current rotation basis.
# Args: none (uses internal _rotation_basis)
# Returns: void
func _sync_rotation_degrees_from_basis() -> void:
	var euler: Vector3 = _rotation_basis.get_euler()
	var primary := Vector3(
		_wrap_degrees(rad_to_deg(euler.x)),
		_wrap_degrees(rad_to_deg(euler.y)),
		_wrap_degrees(rad_to_deg(euler.z))
	)
	var alternate := Vector3(
		_wrap_degrees(180.0 - primary.x),
		_wrap_degrees(primary.y + 180.0),
		_wrap_degrees(primary.z + 180.0)
	)
	var current := Vector3(pitch_degrees, yaw_degrees, roll_degrees)
	var selected: Vector3 = primary
	if _rotation_degrees_distance(alternate, current) < _rotation_degrees_distance(primary, current):
		selected = alternate

	pitch_degrees = selected.x
	yaw_degrees = selected.y
	roll_degrees = selected.z

# Description: Wraps an angle to the -180 to 180 degree range.
# Args: value (float) - angle in degrees
# Returns: float - wrapped angle in degrees
func _wrap_degrees(value: float) -> float:
	return wrapf(value, -180.0, 180.0)

# Description: Calculates the shortest signed delta between two angles.
# Args: from_value (float) - starting angle in degrees, to_value (float) - target angle in degrees
# Returns: float - shortest angular difference in degrees
func _angle_delta_degrees(from_value: float, to_value: float) -> float:
	return wrapf(to_value - from_value, -180.0, 180.0)

# Description: Calculates squared angular distance between two Euler degree vectors.
# Args: a (Vector3) - first rotation in degrees, b (Vector3) - second rotation in degrees
# Returns: float - squared shortest-angle distance
func _rotation_degrees_distance(a: Vector3, b: Vector3) -> float:
	var dx: float = _angle_delta_degrees(a.x, b.x)
	var dy: float = _angle_delta_degrees(a.y, b.y)
	var dz: float = _angle_delta_degrees(a.z, b.z)
	return (dx * dx) + (dy * dy) + (dz * dz)

# ---------- RING DRAWING ----------
# Description: Draws a single axis ring projected into 2D screen space (deprecated, use _draw_projected_ring_fast).
# Args: center (Vector2) — sphere center, visible_radius (float) — sphere radius, rotation_basis (Basis) — rotation to apply, normal (Vector3) — axis to rotate around, color (Color) — ring color
# Returns: void
func _draw_projected_ring(center: Vector2, visible_radius: float, rotation_basis: Basis, normal: Vector3, color: Color) -> void:
	var axis_a: Vector3
	var axis_b: Vector3
	if abs(normal.dot(Vector3.UP)) > 0.99:
		axis_a = Vector3.RIGHT
		axis_b = Vector3.FORWARD
	elif abs(normal.dot(Vector3.RIGHT)) > 0.99:
		axis_a = Vector3.UP
		axis_b = Vector3.FORWARD
	else:
		axis_a = Vector3.RIGHT
		axis_b = Vector3.UP

	var points: Array[Vector2] = []
	var depths: Array[float] = []
	var samples: int = int(clamp(ring_samples, 24, 2048))
	var point_count: int = samples + 1
	for step in range(point_count):
		var angle: float = TAU * float(step) / float(samples)
		var point_3d: Vector3 = (axis_a * cos(angle)) + (axis_b * sin(angle))
		var rotated_point: Vector3 = rotation_basis * point_3d
		points.append(center + Vector2(rotated_point.x, -rotated_point.y) * visible_radius * 0.75)
		depths.append(rotated_point.z)

	var segments: Array = []
	for step in range(1, points.size()):
		# Use the nearer endpoint's z as the segment depth so ordering favors the closest fragment
		var z1: float = depths[step - 1]
		var z2: float = depths[step]
		var seg_depth: float = max(z1, z2)
		segments.append({
			"from": points[step - 1],
			"to": points[step],
			"depth": seg_depth,
			"color": color,
			"width": 1.75
		})
	# draw is handled by global sorter

# Description: Efficiently draws a projected axis ring with depth shading (preferred method).
# Args: center (Vector2) — sphere center, visible_radius (float) — sphere radius, rotation_basis (Basis) — rotation to apply, normal (Vector3) — axis to rotate around, color (Color) — ring color, samples (int) — points to sample (default 48)
# Returns: void
func _draw_projected_ring_fast(center: Vector2, visible_radius: float, rotation_basis: Basis, normal: Vector3, color: Color, samples: int = 48) -> void:
	var axis_a: Vector3
	var axis_b: Vector3
	if abs(normal.dot(Vector3.UP)) > 0.99:
		axis_a = Vector3.RIGHT
		axis_b = Vector3.FORWARD
	elif abs(normal.dot(Vector3.RIGHT)) > 0.99:
		axis_a = Vector3.UP
		axis_b = Vector3.FORWARD
	else:
		axis_a = Vector3.RIGHT
		axis_b = Vector3.UP

	var pts: PackedVector2Array = PackedVector2Array()
	var z_sum: float = 0.0
	var s: int = int(clamp(samples, 12, 256))
	for i in range(s + 1):
		var angle: float = TAU * float(i) / float(s)
		var p3: Vector3 = (axis_a * cos(angle)) + (axis_b * sin(angle))
		var rp: Vector3 = rotation_basis * p3
		pts.append(center + Vector2(rp.x, -rp.y) * visible_radius * 0.75)
		z_sum += rp.z

	var avg_z: float = z_sum / float(pts.size()) if pts.size() > 0 else 0.0
	var depth_norm: float = clamp(0.5 + avg_z * 0.5, 0.0, 1.0)
	var shaded_color: Color = _shade_ring_color(color, depth_norm)
	# Draw as a single polyline for performance; no per-segment sorting
	draw_polyline(pts, shaded_color, ring_thickness, true)

# Description: Builds ring segments for advanced rendering (currently unused).
# Args: center (Vector2) — sphere center, visible_radius (float) — sphere radius, rotation_basis (Basis) — rotation to apply, normal (Vector3) — axis to rotate around, color (Color) — ring color
# Returns: Array — segments with depth and drawing information
func _build_ring_segments(center: Vector2, visible_radius: float, rotation_basis: Basis, normal: Vector3, color: Color) -> Array:
	var axis_a: Vector3
	var axis_b: Vector3
	if abs(normal.dot(Vector3.UP)) > 0.99:
		axis_a = Vector3.RIGHT
		axis_b = Vector3.FORWARD
	elif abs(normal.dot(Vector3.RIGHT)) > 0.99:
		axis_a = Vector3.UP
		axis_b = Vector3.FORWARD
	else:
		axis_a = Vector3.RIGHT
		axis_b = Vector3.UP

	var samples: int = int(clamp(ring_samples, 24, 2048))
	var point_count: int = samples + 1
	var points: Array[Vector2] = []
	var depths_z: Array[float] = []
	for step in range(point_count):
		var angle: float = TAU * float(step) / float(samples)
		var point_3d: Vector3 = (axis_a * cos(angle)) + (axis_b * sin(angle))
		var rotated_point: Vector3 = rotation_basis * point_3d
		points.append(center + Vector2(rotated_point.x, -rotated_point.y) * visible_radius * 0.75)
		depths_z.append(rotated_point.z)

	var segments: Array = []
	for step in range(1, points.size()):
		var z1: float = depths_z[step - 1]
		var z2: float = depths_z[step]
		var seg_depth: float = max(z1, z2)
		segments.append({
			"from": points[step - 1],
			"to": points[step],
			"depth": seg_depth,
			"color": color,
			"width": ring_thickness
		})
	return segments

# Description: Draws the outer roll ring for Z-axis rotation with hover effects.
# Args: center (Vector2) — sphere center, visible_radius (float) — sphere radius, color (Color) — ring color
# Returns: void
func draw_outer_roll_ring(center: Vector2, visible_radius: float, color: Color) -> void:
	var outer_radius: float = visible_radius * 0.98
	var line_width: float = 3.0
	if _hover_outer_ring:
		line_width = 5.0
		draw_arc(center, outer_radius, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.10), line_width + 2.0, true)
	draw_arc(center, outer_radius, 0.0, TAU, 96, color, line_width, true)

# Description: Shades a ring color based on depth to create 3D appearance (darker in back, brighter in front).
# Args: color (Color) — base color, depth_factor (float) — depth normalized from 0.0 (back) to 1.0 (front)
# Returns: Color — shaded color with adjusted brightness
func _shade_ring_color(color: Color, depth_factor: float) -> Color:
	var front_boost: float = 0.28
	var back_darken: float = 0.42
	var brightness: float = lerp(1.0 - back_darken, 1.0 + front_boost, depth_factor)
	return Color(
		clamp(color.r * brightness, 0.0, 1.0),
		clamp(color.g * brightness, 0.0, 1.0),
		clamp(color.b * brightness, 0.0, 1.0),
		color.a
	)
