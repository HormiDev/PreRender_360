extends Node

signal drag_target_moved(new_position: Vector3)
signal scale_step_requested(step_delta: float)

@export var drag_target_path: NodePath
@export var ui_root_path: NodePath
@export var interaction_camera_path: NodePath
@export var max_pick_distance: float = 1000.0
@export var scroll_scale_step: float = 0.01

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


func _ready() -> void:
	if drag_target_path != NodePath():
		_drag_target = get_node_or_null(drag_target_path) as Node3D
	if ui_root_path != NodePath():
		_ui_root = get_node_or_null(ui_root_path) as Control
	if interaction_camera_path != NodePath():
		_interaction_camera = get_node_or_null(interaction_camera_path) as Camera3D


func set_drag_target(target: Node3D) -> void:
	_drag_target = target


func set_pick_root(root: Node3D) -> void:
	_pick_root = root
	_rebuild_pick_colliders()


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
			_try_scroll_scale(event.position, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_try_scroll_scale(event.position, -1.0)
	elif event is InputEventMouseMotion and _is_dragging:
		_update_drag(event.position)


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


func _end_drag() -> void:
	_is_dragging = false


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


func _is_over_blocking_ui() -> bool:
	if _ui_root == null:
		return false

	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if hovered == _ui_root:
		return false
	return _ui_root.is_ancestor_of(hovered)


func _get_interaction_camera() -> Camera3D:
	if _interaction_camera != null:
		return _interaction_camera
	return get_viewport().get_camera_3d()


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


func _clear_generated_pick_colliders() -> void:
	for body in _generated_pick_bodies:
		if body != null and is_instance_valid(body):
			body.queue_free()
	_generated_pick_bodies.clear()
