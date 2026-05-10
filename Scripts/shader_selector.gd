extends OptionButton

enum PostProcessShader {
	NONE,
	BLACK_AND_WHITE,
	ANIMATION,
	COMIC,
	TRADITIONAL_ANIMATION,
	PENCIL_SKETCH,
	COLORED_PENCIL
}

const GRAYSCALE_POST_PROCESS_SHADER := preload("res://Shaders/grayscale_post_process.gdshader")
const ANIMATION_POST_PROCESS_SHADER := preload("res://Shaders/animation_post_process.gdshader")
const COMIC_POST_PROCESS_SHADER := preload("res://Shaders/comic_post_process.gdshader")
const TRADITIONAL_ANIMATION_POST_PROCESS_SHADER := preload("res://Shaders/traditional_animation_post_process.gdshader")
const PENCIL_SKETCH_POST_PROCESS_SHADER := preload("res://Shaders/pencil_sketch_post_process.gdshader")
const COLORED_PENCIL_POST_PROCESS_SHADER := preload("res://Shaders/colored_pencil_post_process.gdshader")
const ANIMATION_OUTLINE_SHADER := preload("res://Shaders/animation_outline.gdshader")
const ANIMATION_OUTLINE_NODE_NAME := "__animation_outline"

@export var render_viewport_path: NodePath
@export var render_post_process_overlay_path: NodePath
@export var preview_post_process_overlay_path: NodePath

var _render_viewport: SubViewport = null
var _render_post_process_overlay: ColorRect = null
var _preview_post_process_overlay: ColorRect = null
var _current_model: Node = null
var _post_process_materials: Dictionary = {}
var _outline_material: ShaderMaterial = null
var _outline_nodes: Array[MeshInstance3D] = []


func _ready() -> void:
	_resolve_nodes()
	_create_post_process_materials()
	_populate_shader_options()

	if not item_selected.is_connected(_on_shader_selected):
		item_selected.connect(_on_shader_selected)

	apply_selected_shader()


# Description: Sets the model that should receive generated outline meshes.
# Args: model (Node) - current render model or null
# Returns: void
func set_model(model: Node) -> void:
	_current_model = model
	_rebuild_outlines()


# Description: Updates overlay size after the render viewport size changes.
# Args: none
# Returns: void
func refresh_render_size() -> void:
	_update_render_overlay_size()


# Description: Reapplies the currently selected shader to preview and capture overlays.
# Args: none
# Returns: void
func apply_selected_shader() -> void:
	var selected_shader := get_selected_id()
	var material: Material = _post_process_materials.get(selected_shader, null)
	var use_post_process := material != null
	var use_outline := _shader_uses_outline(selected_shader)

	_set_outlines_enabled(use_outline)

	if _render_post_process_overlay != null:
		_update_render_overlay_size()
		_render_post_process_overlay.material = material
		_render_post_process_overlay.visible = use_post_process

	if _preview_post_process_overlay != null:
		_preview_post_process_overlay.material = material
		_preview_post_process_overlay.visible = use_post_process


func _resolve_nodes() -> void:
	if render_viewport_path != NodePath():
		_render_viewport = get_node_or_null(render_viewport_path) as SubViewport
	if render_post_process_overlay_path != NodePath():
		_render_post_process_overlay = get_node_or_null(render_post_process_overlay_path) as ColorRect
	if preview_post_process_overlay_path != NodePath():
		_preview_post_process_overlay = get_node_or_null(preview_post_process_overlay_path) as ColorRect


func _populate_shader_options() -> void:
	clear()
	add_item("None", int(PostProcessShader.NONE))
	add_item("Black & White", int(PostProcessShader.BLACK_AND_WHITE))
	add_item("Animation Style", int(PostProcessShader.ANIMATION))
	add_item("Comic Style", int(PostProcessShader.COMIC))
	add_item("Traditional Animation", int(PostProcessShader.TRADITIONAL_ANIMATION))
	add_item("Pencil Sketch", int(PostProcessShader.PENCIL_SKETCH))
	add_item("Colored Pencil", int(PostProcessShader.COLORED_PENCIL))
	select(int(PostProcessShader.NONE))


func _on_shader_selected(_index: int) -> void:
	apply_selected_shader()


func _create_post_process_materials() -> void:
	_create_outline_material()

	var grayscale_material := ShaderMaterial.new()
	grayscale_material.shader = GRAYSCALE_POST_PROCESS_SHADER
	_post_process_materials[int(PostProcessShader.BLACK_AND_WHITE)] = grayscale_material

	var animation_material := ShaderMaterial.new()
	animation_material.shader = ANIMATION_POST_PROCESS_SHADER
	_post_process_materials[int(PostProcessShader.ANIMATION)] = animation_material

	var comic_material := ShaderMaterial.new()
	comic_material.shader = COMIC_POST_PROCESS_SHADER
	_post_process_materials[int(PostProcessShader.COMIC)] = comic_material

	var traditional_animation_material := ShaderMaterial.new()
	traditional_animation_material.shader = TRADITIONAL_ANIMATION_POST_PROCESS_SHADER
	_post_process_materials[int(PostProcessShader.TRADITIONAL_ANIMATION)] = traditional_animation_material

	var pencil_sketch_material := ShaderMaterial.new()
	pencil_sketch_material.shader = PENCIL_SKETCH_POST_PROCESS_SHADER
	_post_process_materials[int(PostProcessShader.PENCIL_SKETCH)] = pencil_sketch_material

	var colored_pencil_material := ShaderMaterial.new()
	colored_pencil_material.shader = COLORED_PENCIL_POST_PROCESS_SHADER
	_post_process_materials[int(PostProcessShader.COLORED_PENCIL)] = colored_pencil_material


func _create_outline_material() -> void:
	if _outline_material != null:
		return

	_outline_material = ShaderMaterial.new()
	_outline_material.shader = ANIMATION_OUTLINE_SHADER


func _rebuild_outlines() -> void:
	_clear_outlines()
	_create_outline_material()
	if _current_model == null:
		return

	_add_outlines_recursive(_current_model)
	_set_outlines_enabled(_shader_uses_outline(get_selected_id()))


func _add_outlines_recursive(node: Node) -> void:
	if node.name == ANIMATION_OUTLINE_NODE_NAME:
		return

	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			var outline := MeshInstance3D.new()
			outline.name = ANIMATION_OUTLINE_NODE_NAME
			outline.mesh = mesh_node.mesh
			outline.visible = false
			outline.material_override = _outline_material
			outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			outline.extra_cull_margin = 0.05
			mesh_node.add_child(outline)
			_outline_nodes.append(outline)

	for child in node.get_children():
		_add_outlines_recursive(child)


func _clear_outlines() -> void:
	for outline in _outline_nodes:
		if outline != null and is_instance_valid(outline):
			outline.queue_free()
	_outline_nodes.clear()


func _set_outlines_enabled(enabled: bool) -> void:
	for outline in _outline_nodes:
		if outline != null and is_instance_valid(outline):
			outline.visible = enabled


func _shader_uses_outline(shader_id: int) -> bool:
	return (
		shader_id == int(PostProcessShader.ANIMATION)
		or shader_id == int(PostProcessShader.COMIC)
	)


func _update_render_overlay_size() -> void:
	if _render_post_process_overlay == null or _render_viewport == null:
		return

	_render_post_process_overlay.position = Vector2.ZERO
	_render_post_process_overlay.size = Vector2(
		float(_render_viewport.size.x),
		float(_render_viewport.size.y)
	)
