extends Node

signal drag_target_moved(new_position: Vector3)
signal scale_step_requested(step_delta: float)

@export var drag_target_path: NodePath
@export var ui_root_path: NodePath
@export var interaction_camera_path: NodePath
@export var max_pick_distance: float = 1000.0
@export var scroll_scale_step: float = 0.01
@export var scroll_z_step: float = 0.01

const _PICK_COLLISION_LAYER_VALUE: int = 1 << 19

var _drag_target: Node3D = null
var _pick_root: Node3D = null
var _ui_root: Control = null
var _interaction_camera: Camera3D = null
var _generated_pick_bodies: Array[StaticBody3D] = []

var _is_dragging: bool = false
var _drag_start_target_position: Vector3 = Vector3.ZERO
var _drag_start_hit_point: Vector3 = Vector3.ZERO
var _drag_plane: Plane = Plane(Vector3.FORWARD, 0.0)

# ---------- READY ----------
# Description: Initializes camera, UI and drag target references from exported NodePaths.
# Args: none
# Returns: void
func _ready() -> void:
	if drag_target_path != NodePath():
		_drag_target = get_node_or_null(drag_target_path) as Node3D
	if ui_root_path != NodePath():
		_ui_root = get_node_or_null(ui_root_path) as Control
	if interaction_camera_path != NodePath():
		_interaction_camera = get_node_or_null(interaction_camera_path) as Camera3D


# ---------- SETTERS ----------
# Description: Sets the node that will move while dragging.
# Args: target (Node3D) — node that will be repositioned
# Returns: void
func set_drag_target(target: Node3D) -> void:
	_drag_target = target


# Description: Sets the model root used for picking and rebuilds the temporary colliders.
# Args: root (Node3D) — root node containing the meshes to pick
# Returns: void
func set_pick_root(root: Node3D) -> void:
	_pick_root = root
	_rebuild_pick_colliders()


# ---------- INPUT ----------
# Description: Handles mouse input for drag, scroll-scale and release events.
# Args: event (InputEvent) — input event received from the viewport
# Returns: void
func _input(event: InputEvent) -> void:
	if _pick_root == null or _drag_target == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_begin_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _is_dragging:
				_scroll_z(1.0)
			else:
				_try_scroll_scale(event.position, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _is_dragging:
				_scroll_z(-1.0)
			else:
				_try_scroll_scale(event.position, -1.0)
	elif event is InputEventMouseMotion and _is_dragging:
		_update_drag(event.position)


# ---------- DRAG ----------
# Description: Starts a drag operation if the cursor hits the model through raycast picking.
# Args: mouse_position (Vector2) — screen-space mouse position
# Returns: void
func _try_begin_drag(mouse_position: Vector2) -> void:
	if _is_over_blocking_ui():
		return

	var camera: Camera3D = _get_interaction_camera()
	if camera == null:
		return

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position).normalized()
	var hit: Dictionary = _raycast_pick_root(ray_origin, ray_direction)
	if hit.is_empty():
		return

	var hit_position: Vector3 = hit["position"] as Vector3
	var camera_forward: Vector3 = -camera.global_transform.basis.z.normalized()

	_is_dragging = true
	_drag_start_target_position = _drag_target.global_position
	_drag_start_hit_point = hit_position
	_drag_plane = Plane(camera_forward, camera_forward.dot(hit_position))


# Description: Updates the dragged object by projecting the mouse ray onto the drag plane.
# Args: mouse_position (Vector2) — current screen-space mouse position
# Returns: void
func _update_drag(mouse_position: Vector2) -> void:
	var camera: Camera3D = _get_interaction_camera()
	if camera == null:
		return

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position).normalized()
	var plane_hit: Variant = _drag_plane.intersects_ray(ray_origin, ray_direction)
	if plane_hit == null:
		return

	var hit_point: Vector3 = plane_hit as Vector3
	var delta: Vector3 = hit_point - _drag_start_hit_point
	_drag_target.global_position = _drag_start_target_position + delta
	drag_target_moved.emit(_drag_target.global_position)


# Description: Stops the active drag operation.
# Args: none
# Returns: void
func _end_drag() -> void:
	_is_dragging = false


# ---------- SCALE ----------
# Description: Moves the dragged object along the Z axis based on scroll_z_step when scrolling while holding the left mouse button.
# Args: direction (float) — step multiplier, positive or negative (+1.0 or -1.0)
# Returns: void
func _scroll_z(direction: float) -> void:
	if _drag_target == null:
		return
	
	var step_amount = scroll_z_step * direction
	_drag_target.global_position.z += step_amount
	_drag_start_target_position.z += step_amount
	drag_target_moved.emit(_drag_target.global_position)


# Description: Emits a scale request when the mouse wheel is used over the model.
# Args: mouse_position (Vector2) — screen-space mouse position
#       direction (float) — scale step multiplier, positive or negative
# Returns: void
func _try_scroll_scale(mouse_position: Vector2, direction: float) -> void:
	if _is_over_blocking_ui():
		return

	var camera: Camera3D = _get_interaction_camera()
	if camera == null:
		return

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position).normalized()
	var hit: Dictionary = _raycast_pick_root(ray_origin, ray_direction)
	if hit.is_empty():
		return

	scale_step_requested.emit(direction * scroll_scale_step)


# ---------- HELPERS ----------
# Description: Detects whether the pointer is over UI that should block model interaction.
# Args: none
# Returns: bool — true if hovering over a blocking control
func _is_over_blocking_ui() -> bool:
	if _ui_root == null:
		return false

	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if hovered == _ui_root:
		return false
	return _ui_root.is_ancestor_of(hovered)


# Description: Returns the camera used to build rays for interaction.
# Args: none
# Returns: Camera3D — configured camera or viewport camera fallback
func _get_interaction_camera() -> Camera3D:
	if _interaction_camera != null:
		return _interaction_camera
	return get_viewport().get_camera_3d()


# Description: Performs a physics raycast against the generated trimesh colliders.
# Args: ray_origin (Vector3) — world-space ray start point
#       ray_direction (Vector3) — normalized world-space ray direction
# Returns: Dictionary — hit data containing position when a collision is found, or an empty dictionary
func _raycast_pick_root(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	var world_3d: World3D = get_viewport().world_3d
	if world_3d == null:
		return {}

	var ray_end: Vector3 = ray_origin + ray_direction * max_pick_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = _PICK_COLLISION_LAYER_VALUE

	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {"position": hit["position"] as Vector3}


# Description: Builds temporary trimesh colliders for every MeshInstance3D inside the pick root.
# Args: none
# Returns: void
func _rebuild_pick_colliders() -> void:
	_clear_generated_pick_colliders()
	if _pick_root == null:
		return

	var stack: Array[Node] = [_pick_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back() as Node
		for child in node.get_children():
			stack.push_back(child)

		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var shape: ConcavePolygonShape3D = mesh_instance.mesh.create_trimesh_shape()
			if shape == null:
				continue

			var body := StaticBody3D.new()
			body.name = "__mouse_pick_body"
			body.collision_layer = _PICK_COLLISION_LAYER_VALUE
			body.collision_mask = 0

			var collision_shape := CollisionShape3D.new()
			collision_shape.shape = shape

			body.add_child(collision_shape)
			mesh_instance.add_child(body)
			_generated_pick_bodies.append(body)


# Description: Removes all previously generated pick colliders from the scene.
# Args: none
# Returns: void
func _clear_generated_pick_colliders() -> void:
	for body in _generated_pick_bodies:
		if body != null and is_instance_valid(body):
			body.queue_free()
	_generated_pick_bodies.clear()
