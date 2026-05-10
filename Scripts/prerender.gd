extends Node3D

# ---------- CONFIGURACIÓN ----------
@export var capture_directory := "./capture"
@export var default_model: PackedScene

# ---------- ENUM FORMATO ----------
enum ImageFormat {
	PNG,
	JPG,
	WEBP,
	XPM,
	XPM_ARGB
}

# ---------- CONSTANTES XPM ----------
const XPM_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,-./:;<=>?@[]^_"
const ATLAS_MAX_PIXELS := 268435456


# ---------- UI ----------
@onready var width_spin: SpinBox = $Control/RenderWidth
@onready var height_spin: SpinBox = $Control/RenderHeigth
@onready var captures_spin: SpinBox = $Control/NViews
@onready var format_option: OptionButton = $Control/ImageFormat
@onready var shader_option: OptionButton = $Control/ShaderOption
@onready var file_prefix_input: LineEdit = $Control/FilePrefixInput
@onready var capture_button: Button = $Control/Button
@onready var scale_spin: SpinBox = $Control/ScaleSpin
@onready var directional_light: DirectionalLight3D = $SubViewport/DirectionalLight3D
@onready var model_rotation_control = $Control/ModelRotationSphere
@onready var light_rotation_control = $Control/LightRotationSphere
@onready var light_intensity_slider: HSlider = $Control/LightIntensitySlider
@onready var import_button: Button = $Control/ImportButton
@onready var file_dialog: FileDialog = $Control/FileDialog
@onready var light_r_slider: HSlider = $Control/LightRSlider
@onready var light_g_slider: HSlider = $Control/LightGSlider
@onready var light_b_slider: HSlider = $Control/LightBSlider
@onready var render_pos_x_spin: SpinBox = $Control.get_node_or_null("RenderPosXSpin")
@onready var render_pos_y_spin: SpinBox = $Control.get_node_or_null("RenderPosYSpin")
@onready var render_pos_z_spin: SpinBox = $Control.get_node_or_null("RenderPosZSpin")
@onready var model_mouse_drag = $ModelMouseDrag
@onready var n_frames_spin: SpinBox = $Control.get_node_or_null("NFrames")
@onready var atlas_mode_check: CheckBox = $Control.get_node_or_null("AtlasModeCheck")
@onready var atlas_error_dialog: AcceptDialog = $Control.get_node_or_null("AtlasErrorDialog")
@onready var language_selector = $Control/LanguageSelector
@onready var rendering_panel: Panel = $Control.get_node_or_null("RenderingPanel")
@onready var rendering_label: Label = $Control.get_node_or_null("RenderingPanel/RenderingLabel")


# ---------- RENDER ----------
@onready var viewport: SubViewport = $SubViewport
@onready var render_scene: Node3D = $SubViewport/RenderScene
@onready var render_camera: Camera3D = $SubViewport/RenderCamera3D

# ---------- VARIABLES ----------
@export var render_width := 512
@export var render_height := 512
@export var capture_count := 36
@export var anim_fps := 30

var image_format: int = ImageFormat.PNG
var current_model: Node = null
var file_prefix := "capture_angle_"
var model_rotation_pitch := 0.0
var model_rotation_yaw := 0.0
var model_rotation_roll := 0.0
var light_rotation_pitch := 0.0
var light_rotation_yaw := 0.0
var light_rotation_roll := 0.0

# Buffers temporales para export web
var _web_capture_buffers := []
var _web_import_callback_ref: JavaScriptObject


# ---------- READY ----------
# Description: Initializes the UI, connects signals and loads the default model.
# Args: none
# Returns: void
func _ready():
	if capture_button.pressed.is_connected(_on_button_pressed):
		capture_button.pressed.disconnect(_on_button_pressed)
	capture_button.pressed.connect(_on_button_pressed)
	if OS.has_feature("web"):
		_web_import_callback_ref = JavaScriptBridge.create_callback(_on_web_model_file_picked)

	# Configurar OptionButton
	format_option.clear()
	format_option.add_item("PNG", int(ImageFormat.PNG))
	format_option.add_item("JPG", int(ImageFormat.JPG))
	format_option.add_item("WEBP", int(ImageFormat.WEBP))
	format_option.add_item("XPM", int(ImageFormat.XPM))
	format_option.add_item("XPM_ARGB", int(ImageFormat.XPM_ARGB))
	format_option.select(int(ImageFormat.PNG))

	if language_selector != null:
		language_selector.set_language(language_selector.get_current_language())

	ensure_capture_folder()
	# Botón import
	import_button.pressed.connect(_on_import_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	# Rescalado
	scale_spin.value_changed.connect(_on_scale_changed)
	# Rotacion de la luz
	if light_rotation_control != null:
		if light_rotation_control.has_signal("rotation_changed"):
			light_rotation_control.rotation_changed.connect(_on_light_rotation_changed)
	# Rotacion del modelo
	if model_rotation_control != null:
		if model_rotation_control.has_signal("rotation_changed"):
			model_rotation_control.rotation_changed.connect(_on_model_rotation_changed)
		elif model_rotation_control.has_signal("rotation_delta"):
			model_rotation_control.rotation_delta.connect(_on_model_rotation_delta)
	
	# Posición del RenderScene
	if render_pos_x_spin:
		render_pos_x_spin.value_changed.connect(_on_render_position_changed)
	if render_pos_y_spin:
		render_pos_y_spin.value_changed.connect(_on_render_position_changed)
	if render_pos_z_spin:
		render_pos_z_spin.value_changed.connect(_on_render_position_changed)
	if model_mouse_drag != null:
		if model_mouse_drag.has_method("set_drag_target"):
			model_mouse_drag.set_drag_target(render_scene)
		if model_mouse_drag.has_signal("drag_target_moved"):
			model_mouse_drag.drag_target_moved.connect(_on_drag_target_moved)
		if model_mouse_drag.has_signal("scale_step_requested"):
			model_mouse_drag.scale_step_requested.connect(_on_scale_step_requested)

	# Intensidad de la luz
	light_intensity_slider.value_changed.connect(_on_light_intensity_changed)
	
	# Cargar modelo por defecto
	if default_model != null:
		var scene: Node3D = default_model.instantiate() as Node3D
		# Limpiar RenderScene antes de agregar
		for child in render_scene.get_children():
			child.queue_free()
		render_scene.add_child(scene)
		scene.owner = render_scene
		current_model = scene
		# Normalizar y aplicar escala inicial
		normalize_model_recursive(scene)
		_set_shader_model(scene)
		_apply_user_scale()
		_apply_model_rotation()
		if model_mouse_drag != null and model_mouse_drag.has_method("set_pick_root"):
			model_mouse_drag.set_pick_root(scene)
		_update_nframes_ui()
	
		# Color RGB de la luz
	light_r_slider.value_changed.connect(_on_light_color_changed)
	light_g_slider.value_changed.connect(_on_light_color_changed)
	light_b_slider.value_changed.connect(_on_light_color_changed)
	# Aplicar color inicial
	_on_light_color_changed(0)

	# Enable _process to keep UI in sync with model (idle animations, external changes)
	set_process(true)



# ---------- BOTÓN ----------
# Description: Handles capture button press and launches 360° capture.
# Args: none
# Returns: void
func _on_button_pressed():
	print("Starting 360° capture...")

	render_width = int(width_spin.value)
	render_height = int(height_spin.value)
	capture_count = int(captures_spin.value)
	image_format = format_option.get_selected_id()
	
	if file_prefix_input and file_prefix_input.text.strip_edges() != "":
		file_prefix = file_prefix_input.text.strip_edges()
	else:
		file_prefix = "capture_angle_"

	if not _validate_atlas_mode_limits():
		return

	viewport.size = Vector2i(render_width, render_height)
	_refresh_shader_render_size()

	_show_rendering_message()
	await capture_360()
	_hide_rendering_message()


# Description: Validates that atlas mode does not exceed pixel limit.
# Args: none
# Returns: bool — true if atlas is valid or disabled, false if disabled due to size.
func _validate_atlas_mode_limits() -> bool:
	if atlas_mode_check == null or not atlas_mode_check.button_pressed:
		return true

	var anim_player := _find_animation_player(current_model) if current_model else null
	var has_anim := anim_player != null and anim_player.get_animation_list().size() > 0
	var total_frames := 1
	if has_anim:
		total_frames = int(n_frames_spin.value) if n_frames_spin else 30
		if total_frames <= 0:
			total_frames = 1

	var atlas_width := render_width * total_frames
	var atlas_height := render_height * capture_count
	var atlas_pixels := atlas_width * atlas_height
	if atlas_pixels <= ATLAS_MAX_PIXELS:
		return true

	atlas_mode_check.button_pressed = false
	var message := _build_atlas_error_message(atlas_width, atlas_height, atlas_pixels)
	_show_atlas_error(message)
	return false


func _build_atlas_error_message(atlas_width: int, atlas_height: int, atlas_pixels: int) -> String:
	var disabled_prefix := "Atlas mode disabled: the resulting image would be too large."
	var calculated_size := "Calculated size"
	var allowed_limit := "Allowed limit"
	var reduce_instruction := "Reduce Render Width, N Views or N Frames, or re-render without Atlas Mode."

	if language_selector != null:
		disabled_prefix = language_selector.get_text("atlas_disabled_prefix")
		calculated_size = language_selector.get_text("atlas_calculated_size")
		allowed_limit = language_selector.get_text("atlas_allowed_limit")
		reduce_instruction = language_selector.get_text("atlas_reduce_instruction")

	var message := "%s\n\n" % disabled_prefix
	message += "%s: %dx%d (%d pixels).\n" % [calculated_size, atlas_width, atlas_height, atlas_pixels]
	message += "%s: %d pixels.\n\n" % [allowed_limit, ATLAS_MAX_PIXELS]
	message += reduce_instruction
	return message


# Description: Displays an error dialog related to atlas mode.
# Args: message (String) — error text to display
# Returns: void
func _show_atlas_error(message: String) -> void:
	if atlas_error_dialog != null:
		atlas_error_dialog.dialog_text = message
		atlas_error_dialog.popup_centered()
	else:
		push_error(message)

# ---------- CARPETA ----------
# Description: Ensures the capture destination folder exists (not on web).
# Args: none
# Returns: void
func ensure_capture_folder():
	if OS.has_feature("web"):
		return

	var base_dir := capture_directory.get_base_dir()
	var folder_name := capture_directory.get_file()

	var dir = DirAccess.open(base_dir)
	if dir == null:
		push_error("Invalid path: " + base_dir)
		return

	if not dir.dir_exists(folder_name):
		dir.make_dir(folder_name)

# Description: Clears all files within the capture folder (not on web).
# Args: none
# Returns: void
func clear_capture_folder():
	if OS.has_feature("web"):
		return

	var dir = DirAccess.open(capture_directory)
	if dir == null:
		return

	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			dir.remove(file)
		file = dir.get_next()
	dir.list_dir_end()

# ---------- FUNCIONES ANIMACION ----------
# Description: Updates frame count UI based on whether animations exist.
# Args: none
# Returns: void
func _update_nframes_ui() -> void:
	if not n_frames_spin:
		return
	
	var anim_player := _find_animation_player(current_model) if current_model else null
	var has_anim := anim_player != null and anim_player.get_animation_list().size() > 0
	
	if has_anim:
		n_frames_spin.max_value = 1000 # Sin límite si hay animación
		n_frames_spin.value = 30
	else:
		n_frames_spin.max_value = 1 # Máximo 1 si no hay animación
		n_frames_spin.value = 1

# Description: Recursively searches for an AnimationPlayer within a node.
# Args: node (Node) — root node to search in
# Returns: AnimationPlayer or null if not found
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null

# ---------- CAPTURA ----------
# Description: Performs 360° capture (optionally in atlas mode or with animation).
# Args: none
# Returns: void
func capture_360() -> void:
	ensure_capture_folder()
	clear_capture_folder()

	render_scene.rotation = Vector3.ZERO
	var step_degrees := 360.0 / capture_count

	var anim_player := _find_animation_player(current_model) if current_model else null
	var has_anim := anim_player != null and anim_player.get_animation_list().size() > 0
	var atlas_mode := atlas_mode_check != null and atlas_mode_check.button_pressed
	var total_frames := 1
	if has_anim:
		total_frames = int(n_frames_spin.value) if n_frames_spin else 30
		if total_frames <= 0:
			total_frames = 1

	var atlas_image: Image = null
	if atlas_mode:
		atlas_image = Image.create(render_width * total_frames, render_height * capture_count, false, Image.FORMAT_RGBA8)

	if has_anim:
		var anim_name: String = anim_player.get_animation_list()[0]
		var anim := anim_player.get_animation(anim_name)

		anim_player.play(anim_name)
		anim_player.speed_scale = 0.0 # Pausar la reproducción automática
		
		for f in range(total_frames):
			var time_sec := 0.0
			if total_frames > 1:
				time_sec = (float(f) / float(total_frames)) * anim.length
				
			anim_player.seek(time_sec, true)
			# anim_player.advance(0) # Ya no es estrictamente necesario si seek actualiza y procesamos frames

			for i in range(capture_count):
				var angle := step_degrees * i
				render_scene.rotation_degrees.y = angle

				# Actualizar vista (ahora la animación no avanzará sola porque speed_scale es 0.0)
				await get_tree().process_frame
				await get_tree().process_frame

				var image: Image = viewport.get_texture().get_image()
				if atlas_mode:
					atlas_image.blit_rect(image, Rect2i(0, 0, render_width, render_height), Vector2i(f * render_width, i * render_height))
				else:
					var image_to_save := _prepare_image_for_format(image)
					var base_path := "%s/%sf%03d_%03d" % [capture_directory, file_prefix, f, int(angle)]
					if OS.has_feature("web"):
						var fname := "%sf%03d_%03d" % [file_prefix, f, int(angle)]
						var buf := save_image_web_buffer(image_to_save, fname)
						_web_capture_buffers.append({"name": fname, "data": buf})
					else:
						save_image(image_to_save, base_path)
	else:
		for i in range(capture_count):
			var angle := step_degrees * i

			render_scene.rotation_degrees.y = angle

			await get_tree().process_frame
			await get_tree().process_frame

			var image: Image = viewport.get_texture().get_image()
			if atlas_mode:
				atlas_image.blit_rect(image, Rect2i(0, 0, render_width, render_height), Vector2i(0, i * render_height))
			else:
				var image_to_save := _prepare_image_for_format(image)
				var base_path := "%s/%s%03d" % [capture_directory, file_prefix, int(angle)]
				if OS.has_feature("web"):
					var fname := "%s%03d" % [file_prefix, int(angle)]
					var buf := save_image_web_buffer(image_to_save, fname)
					_web_capture_buffers.append({"name": fname, "data": buf})
				else:
					save_image(image_to_save, base_path)

	if atlas_mode and atlas_image != null:
		var atlas_to_save := _prepare_image_for_format(atlas_image)
		var atlas_base_path := "%s/%satlas" % [capture_directory, file_prefix]
		save_image(atlas_to_save, atlas_base_path)

	print("360° capture completed.")
	print("Saved to:", ProjectSettings.globalize_path(capture_directory))

	# Si estamos en web, empaquetar y descargar un ZIP con todas las capturas
	if OS.has_feature("web") and not atlas_mode and _web_capture_buffers.size() > 0:
		var zip_name := file_prefix + ".zip"
		var zip_data := build_zip_from_files(_web_capture_buffers)
		JavaScriptBridge.download_buffer(zip_data, zip_name, "application/zip")
		_web_capture_buffers.clear()

# ---------- GUARDAR ----------
# Description: Saves an image to disk or downloads on web based on selected format.
# Args: image (Image) — image to save
#       base_path (String) — path/base for file without extension
# Returns: void
func save_image(image: Image, base_path: String):
	if OS.has_feature("web"):
		var file_name := base_path.get_file()
		match image_format:
			ImageFormat.PNG:
				JavaScriptBridge.download_buffer(image.save_png_to_buffer(), file_name + ".png")
			ImageFormat.JPG:
				JavaScriptBridge.download_buffer(image.save_jpg_to_buffer(0.95), file_name + ".jpg")
			ImageFormat.WEBP:
				JavaScriptBridge.download_buffer(image.save_webp_to_buffer(), file_name + ".webp")
			ImageFormat.XPM:
				JavaScriptBridge.download_buffer(build_xpm_rgba_text(image).to_utf8_buffer(), file_name + ".xpm")
			ImageFormat.XPM_ARGB:
				JavaScriptBridge.download_buffer(build_xpm_argb_text(image).to_utf8_buffer(), file_name + ".xpm")
		return

	match image_format:
		ImageFormat.PNG:
			image.save_png(base_path + ".png")
		ImageFormat.JPG:
			image.save_jpg(base_path + ".jpg", 0.95)
		ImageFormat.WEBP:
			image.save_webp(base_path + ".webp")
		ImageFormat.XPM:
			save_xpm_rgba(image, base_path + ".xpm")
		ImageFormat.XPM_ARGB:
			save_xpm_argb(image, base_path + ".xpm")


# Description: Prepares/converts image according to format (e.g., RGB for JPG).
# Args: source_image (Image) — original image
# Returns: Image — converted image ready for saving
func _prepare_image_for_format(source_image: Image) -> Image:
	var image := source_image.duplicate()
	if image_format == ImageFormat.JPG:
		image.convert(Image.FORMAT_RGB8)
	return image


# Description: Generates a buffer (PackedByteArray) ready for web download by format.
# Args: image (Image) — image to convert
#       _name_without_ext (String) — base name (not directly used here)
# Returns: PackedByteArray — buffer with image file bytes
func save_image_web_buffer(image: Image, _name_without_ext: String) -> PackedByteArray:
	if image_format == ImageFormat.PNG:
		return image.save_png_to_buffer()
	elif image_format == ImageFormat.JPG:
		return image.save_jpg_to_buffer(0.95)
	elif image_format == ImageFormat.WEBP:
		return image.save_webp_to_buffer()
	elif image_format == ImageFormat.XPM:
		return build_xpm_rgba_text(image).to_utf8_buffer()
	elif image_format == ImageFormat.XPM_ARGB:
		return build_xpm_argb_text(image).to_utf8_buffer()
	# Por defecto
	return PackedByteArray()


# Description: Converts an integer to a 16-bit little-endian PackedByteArray.
# Args: val (int) — value to convert
# Returns: PackedByteArray — bytes in little-endian order
func _u16_le(val: int) -> PackedByteArray:
	var a := PackedByteArray()
	var u := val & 0xFFFF
	a.append(u & 0xFF)
	a.append((u >> 8) & 0xFF)
	return a


# Description: Converts an integer to a 32-bit little-endian PackedByteArray.
# Args: val (int) — value to convert
# Returns: PackedByteArray — bytes in little-endian order
func _u32_le(val: int) -> PackedByteArray:
	var a := PackedByteArray()
	var u := val & 0xFFFFFFFF
	a.append(u & 0xFF)
	a.append((u >> 8) & 0xFF)
	a.append((u >> 16) & 0xFF)
	a.append((u >> 24) & 0xFF)
	return a


# Description: Appends bytes from `src` to the end of `dest` (in-place).
# Args: dest (PackedByteArray) — destination to append bytes to
#       src (PackedByteArray) — source bytes to append
# Returns: void
func _append_pba(dest: PackedByteArray, src: PackedByteArray) -> void:
	for b in src:
		dest.append(b)


# Description: Calculates CRC32 of a PackedByteArray.
# Args: data (PackedByteArray) — data to calculate CRC for
# Returns: int — CRC32 value (32 bits)
func crc32(data: PackedByteArray) -> int:
	var table: Array[int] = []
	# generar tabla localmente cada vez (suficiente para este uso)
	for i in range(256):
		var c := i
		for j in range(8):
			if (c & 1) != 0:
				c = (0xEDB88320 ^ (c >> 1)) & 0xFFFFFFFF
			else:
				c = (c >> 1) & 0xFFFFFFFF
		table.append(c)

	var crc := 0xFFFFFFFF
	for byte in data:
		var idx := int((crc ^ byte) & 0xFF)
		crc = ((crc >> 8) ^ table[idx]) & 0xFFFFFFFF
	crc = crc ^ 0xFFFFFFFF
	return crc & 0xFFFFFFFF


# Description: Builds a ZIP in memory from an array of files with {name, data}.
# Args: files (Array) — each element must be {name: String, data: PackedByteArray}
# Returns: PackedByteArray — resulting ZIP bytes
func build_zip_from_files(files: Array) -> PackedByteArray:
	# files: array of {name: String, data: PackedByteArray}
	var out := PackedByteArray()
	var central := PackedByteArray()

	for f in files:
		var filename: String = str(f["name"])
		# agregar extensión según formato
		var ext := ".png"
		if image_format == ImageFormat.PNG:
			ext = ".png"
		elif image_format == ImageFormat.JPG:
			ext = ".jpg"
		elif image_format == ImageFormat.WEBP:
			ext = ".webp"
		elif image_format == ImageFormat.XPM or image_format == ImageFormat.XPM_ARGB:
			ext = ".xpm"
		var name_full: String = filename + ext
		var name_bytes: PackedByteArray = name_full.to_utf8_buffer()
		var data: PackedByteArray = f["data"]
		var crc: int = crc32(data)
		var size: int = data.size()

		# record current offset for this local header
		var local_header_offset: int = out.size()

		# Local file header
		_append_pba(out, _u32_le(0x04034b50))
		_append_pba(out, _u16_le(20))
		_append_pba(out, _u16_le(0))
		_append_pba(out, _u16_le(0))
		_append_pba(out, _u16_le(0))
		_append_pba(out, _u16_le(0))
		_append_pba(out, _u32_le(crc))
		_append_pba(out, _u32_le(size))
		_append_pba(out, _u32_le(size))
		_append_pba(out, _u16_le(name_bytes.size()))
		_append_pba(out, _u16_le(0))
		_append_pba(out, name_bytes)
		_append_pba(out, data)

		# Central directory entry
		_append_pba(central, _u32_le(0x02014b50))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u16_le(20))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u32_le(crc))
		_append_pba(central, _u32_le(size))
		_append_pba(central, _u32_le(size))
		_append_pba(central, _u16_le(name_bytes.size()))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u16_le(0))
		_append_pba(central, _u32_le(0))
		_append_pba(central, _u32_le(local_header_offset))
		_append_pba(central, name_bytes)

	var central_offset := out.size()
	var central_size := central.size()

	# concatenar central al out
	_append_pba(out, central)

	# End of central directory
	_append_pba(out, _u32_le(0x06054b50))
	_append_pba(out, _u16_le(0))
	_append_pba(out, _u16_le(0))
	_append_pba(out, _u16_le(files.size()))
	_append_pba(out, _u16_le(files.size()))
	_append_pba(out, _u32_le(central_size))
	_append_pba(out, _u32_le(central_offset))
	_append_pba(out, _u16_le(0))

	return out


# Description: Generates XPM (RGBA) text from an `Image`.
# Args: image (Image) — input image
# Returns: String — XPM text content
func build_xpm_rgba_text(image: Image) -> String:
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var palette := {}
	var palette_list := []
	var pixels := []

	for y in range(h):
		var row := []
		for x in range(w):
			var c := image.get_pixel(x, y)
			var key: String
			if c.a <= 0.0:
				key = "None"
			else:
				key = "%02X%02X%02X" % [
					int(c.r * 255),
					int(c.g * 255),
					int(c.b * 255)
				]
			if not palette.has(key):
				palette[key] = palette.size()
				palette_list.append(key)
			row.append(key)
		pixels.append(row)

	var base := XPM_CHARS.length()
	var color_count := palette.size()
	var chars_per_pixel := 1
	while pow(base, chars_per_pixel) < color_count:
		chars_per_pixel += 1

	var lines := PackedStringArray()
	lines.append("/* XPM */")
	lines.append("static char * image_xpm[] = {")
	lines.append("\"%d %d %d %d\"," % [w, h, color_count, chars_per_pixel])
	for key in palette_list:
		var code := xpm_code(palette[key], chars_per_pixel)
		if key == "None":
			lines.append("\"%s c None\"," % code)
		else:
			lines.append("\"%s c #%s\"," % [code, key])
	for y in range(h):
		var line := ""
		for x in range(w):
			var idx: int = palette[pixels[y][x]]
			line += xpm_code(idx, chars_per_pixel)
		lines.append("\"%s\"," % line)
	lines.append("};")
	return "\n".join(lines)


# Description: Generates XPM (ARGB) text from an `Image`.
# Args: image (Image) — input image
# Returns: String — XPM text content
func build_xpm_argb_text(image: Image) -> String:
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var palette := {}
	var palette_list := []
	var pixels := []

	for y in range(h):
		var row := []
		for x in range(w):
			var c := image.get_pixel(x, y)
			var key: String
			if c.a <= 0.0:
				key = "None"
			else:
				key = "%02X%02X%02X%02X" % [
					int(c.a * 255),
					int(c.r * 255),
					int(c.g * 255),
					int(c.b * 255)
				]
			if not palette.has(key):
				palette[key] = palette.size()
				palette_list.append(key)
			row.append(key)
		pixels.append(row)

	var base := XPM_CHARS.length()
	var color_count := palette.size()
	var chars_per_pixel := 1
	while pow(base, chars_per_pixel) < color_count:
		chars_per_pixel += 1

	var lines := PackedStringArray()
	lines.append("/* XPM */")
	lines.append("static char * image_xpm[] = {")
	lines.append("\"%d %d %d %d\"," % [w, h, color_count, chars_per_pixel])
	for key in palette_list:
		var code := xpm_code(palette[key], chars_per_pixel)
		if key == "None":
			lines.append("\"%s c None\"," % code)
		else:
			lines.append("\"%s c #%s\"," % [code, key])
	for y in range(h):
		var line := ""
		for x in range(w):
			var idx: int = palette[pixels[y][x]]
			line += xpm_code(idx, chars_per_pixel)
		lines.append("\"%s\"," % line)
	lines.append("};")
	return "\n".join(lines)


# Description: Returns the XPM code for a given index and character length per pixel.
# Args: index (int) — color index in palette
#       chars_per_pixel (int) — number of characters per pixel
# Returns: String — string representing the XPM code for that index
func xpm_code(index: int, chars_per_pixel: int) -> String:
	var base := XPM_CHARS.length()
	var code := ""

	for i in range(chars_per_pixel):
		code = XPM_CHARS[index % base] + code
		index = floori(float(index) / float(base))

	return code

# Description: Saves an `Image` as XPM (RGB) file to disk.
# Args: image (Image) — image to save (will be converted to RGB)
#       path (String) — full destination path
# Returns: void
func save_xpm_rgb(image: Image, path: String):
	image.convert(Image.FORMAT_RGB8)
	var w: int = image.get_width()
	var h: int = image.get_height()
	# 1. Recoger colores
	var palette := {}  # key: color hex, value: int
	var palette_list := []
	var pixels := []

	for y in range(h):
		var row := []
		for x in range(w):
			var c: Color = image.get_pixel(x, y)
			var key: String = "%02X%02X%02X" % [
				int(c.r * 255),
				int(c.g * 255),
				int(c.b * 255)
			]
			if not palette.has(key):
				palette[key] = palette.size()
				palette_list.append(key)
			row.append(key)
		pixels.append(row)
	# 2. Calcular chars_per_pixel
	var base: int = XPM_CHARS.length()
	var color_count: int = palette.size()
	var chars_per_pixel: int = 1
	while pow(base, chars_per_pixel) < color_count:
		chars_per_pixel += 1
	# 3. Escribir archivo
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write XPM to: " + ProjectSettings.globalize_path(path))
		return
	file.store_line("/* XPM */")
	file.store_line("static char * image_xpm[] = {")
	file.store_line("\"%d %d %d %d\"," % [w, h, color_count, chars_per_pixel])
	# Paleta
	for key in palette_list:
		var index: int = palette[key]
		var code: String = xpm_code(index, chars_per_pixel)
		file.store_line("\"%s c #%s\"," % [code, key])
	# Píxeles
	for y in range(h):
		var line: String = ""
		for x in range(w):
			var color_key: String = pixels[y][x]
			var idx: int = palette[color_key]
			line += xpm_code(idx, chars_per_pixel)
		file.store_line("\"%s\"," % line)
	file.store_line("};")
	file.close()

# Description: Saves an `Image` as XPM (RGBA) file to disk.
# Args: image (Image) — image to save (will be converted to RGBA)
#       path (String) — full destination path
# Returns: void
func save_xpm_rgba(image: Image, path: String):
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var palette := {}          # key -> index
	var palette_list := []     # index -> key
	var pixels := []

	for y in range(h):
		var row := []
		for x in range(w):
			var c := image.get_pixel(x, y)

			var key: String
			if c.a <= 0.0:
				key = "None"
			else:
				key = "%02X%02X%02X" % [
					int(c.r * 255),
					int(c.g * 255),
					int(c.b * 255)
				]
			if not palette.has(key):
				palette[key] = palette.size()
				palette_list.append(key)
			row.append(key)
		pixels.append(row)
		
	var base := XPM_CHARS.length()
	var color_count := palette.size()
	var chars_per_pixel := 1
	
	while pow(base, chars_per_pixel) < color_count:
		chars_per_pixel += 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write XPM")
		return
	file.store_line("/* XPM */")
	file.store_line("static char * image_xpm[] = {")
	file.store_line("\"%d %d %d %d\"," % [w, h, color_count, chars_per_pixel])
	# Paleta
	for key in palette_list:
		var code := xpm_code(palette[key], chars_per_pixel)
		if key == "None":
			file.store_line("\"%s c None\"," % code)
		else:
			file.store_line("\"%s c #%s\"," % [code, key])
	# Píxeles
	for y in range(h):
		var line := ""
		for x in range(w):
			var idx: int = palette[pixels[y][x]]
			line += xpm_code(idx, chars_per_pixel)
		file.store_line("\"%s\"," % line)
	file.store_line("};")
	file.close()


# Description: Saves an `Image` as XPM (ARGB) file to disk.
# Args: image (Image) — image to save (will be converted to RGBA/ARGB)
#       path (String) — full destination path
# Returns: void
func save_xpm_argb(image: Image, path: String):
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var palette := {}          # key -> index
	var palette_list := []     # index -> key
	var pixels := []

	for y in range(h):
		var row := []
		for x in range(w):
			var c := image.get_pixel(x, y)

			var key: String
			if c.a <= 0.0:
				key = "None"
			else:
				key = "%02X%02X%02X%02X" % [
					int(c.a * 255),
					int(c.r * 255),
					int(c.g * 255),
					int(c.b * 255)
				]
			if not palette.has(key):
				palette[key] = palette.size()
				palette_list.append(key)
			row.append(key)
		pixels.append(row)
		
	var base := XPM_CHARS.length()
	var color_count := palette.size()
	var chars_per_pixel := 1
	
	while pow(base, chars_per_pixel) < color_count:
		chars_per_pixel += 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write XPM")
		return
	file.store_line("/* XPM */")
	file.store_line("static char * image_xpm[] = {")
	file.store_line("\"%d %d %d %d\"," % [w, h, color_count, chars_per_pixel])
	# Paleta
	for key in palette_list:
		var code := xpm_code(palette[key], chars_per_pixel)
		if key == "None":
			file.store_line("\"%s c #00000000\"," % code)
		else:
			file.store_line("\"%s c #%s\"," % [code, key])
	# Píxeles
	for y in range(h):
		var line := ""
		for x in range(w):
			var idx: int = palette[pixels[y][x]]
			line += xpm_code(idx, chars_per_pixel)
		file.store_line("\"%s\"," % line)
	file.store_line("};")
	file.close()


# Description: Handles import button; opens file selector or web picker.
# Args: none
# Returns: void
func _on_import_button_pressed() -> void:
	if OS.has_feature("web"):
		_open_web_model_picker()
		return
	file_dialog.popup()

# Description: Callback when a file is selected in the FileDialog.
# Args: path (String) — path to selected file
# Returns: void
func _on_file_selected(path: String):
	load_glb_runtime(path)


# Description: Opens browser file picker to select a .glb (web).
# Args: none
# Returns: void
func _open_web_model_picker() -> void:
	if _web_import_callback_ref == null:
		_web_import_callback_ref = JavaScriptBridge.create_callback(_on_web_model_file_picked)

	JavaScriptBridge.eval("""
window.__prerenderPickModel = function(done) {
	const input = document.createElement('input');
	input.type = 'file';
	input.accept = '.glb';
	input.style.display = 'none';
	input.onchange = function() {
		if (!input.files || !input.files.length) {
			done('', '');
			input.remove();
			return;
		}
		const file = input.files[0];
		const reader = new FileReader();
		reader.onload = function() {
			done(reader.result, file.name);
			input.remove();
		};
		reader.onerror = function() {
			done('', file.name);
			input.remove();
		};
		reader.readAsDataURL(file);
	};
	document.body.appendChild(input);
	input.click();
};
""", true)
	var window := JavaScriptBridge.get_interface("window")
	window.__prerenderPickModel(_web_import_callback_ref)


# Description: Callback from JavaScript when user selects a model on web.
# Args: args (Array) — [data_url, filename]
# Returns: void
func _on_web_model_file_picked(args: Array) -> void:
	if args.size() < 2:
		return

	var data_url := str(args[0])
	var file_name := str(args[1])
	if data_url.is_empty():
		return

	var comma_pos := data_url.find(",")
	if comma_pos == -1:
		push_error("Could not read model from browser: invalid data format")
		return

	var raw_data := Marshalls.base64_to_raw(data_url.substr(comma_pos + 1))
	load_glb_runtime_from_bytes(raw_data, file_name)

# Description: Loads a GLB file from disk and processes it for rendering.
# Args: path (String) — path to .glb file
# Returns: void
func load_glb_runtime(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GLB file does not exist: %s" % path)
		return
	var data := file.get_buffer(file.get_length())
	load_glb_runtime_from_bytes(data, path.get_file())


# Description: Loads a GLB from bytes in memory and generates the corresponding scene.
# Args: data (PackedByteArray) — GLB content
#       source_name (String) — source name (optional)
# Returns: void
func load_glb_runtime_from_bytes(data: PackedByteArray, source_name: String = "") -> void:
	# Limpia modelos previos
	_set_shader_model(null)
	for child in render_scene.get_children():
		child.queue_free()
	if model_mouse_drag != null and model_mouse_drag.has_method("set_pick_root"):
		model_mouse_drag.set_pick_root(null)

	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()

	var err: int = gltf.append_from_buffer(data, source_name, state)
	if err != OK:
		push_error("Error loading GLB: %s" % str(err))
		return

	var scene: Node = gltf.generate_scene(state)
	if scene == null:
		push_error("Could not generate scene from GLB")
		return

	# Se añade diferido para evitar crashes en SubViewport
	call_deferred("_add_to_render_scene", scene)



# Description: Adds a node to `render_scene`, normalizes and applies scale.
# Args: scene (Node) — scene generated from GLB
# Returns: void
func _add_to_render_scene(scene: Node) -> void:
	if not scene:
		return

	# Limpia cualquier modelo previo (ya lo haces en load_glb_runtime)
	render_scene.add_child(scene)
	scene.owner = render_scene

	# Guardar referencia para escalar luego
	current_model = scene
	if model_mouse_drag != null and model_mouse_drag.has_method("set_pick_root") and scene is Node3D:
		model_mouse_drag.set_pick_root(scene as Node3D)

	# Normalizar todos los meshes
	normalize_model_recursive(scene)
	_set_shader_model(scene)

	# Aplicar la escala inicial del usuario
	_apply_user_scale()
	_apply_model_rotation()
	_update_nframes_ui()

# Description: Applies user-defined scale to `current_model`.
# Args: none
# Returns: void
func _apply_user_scale() -> void:
	if current_model == null:
		return

	var user_scale: float = float(scale_spin.value)
	current_model.scale = Vector3.ONE * user_scale

# Description: Callback when scale slider changes; reapplies user scale.
# Args: _value (float) — new slider value (not directly used)
# Returns: void
func _on_scale_changed(_value: float) -> void:
	_apply_user_scale()


# Description: Normalizes position and scale of meshes within node recursively.
# Args: node (Node) — root node to normalize
# Returns: void
func normalize_model_recursive(node: Node) -> void:
	var user_scale: float = float(scale_spin.value)

	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var aabb: AABB = mesh_node.get_aabb()
		if aabb.size != Vector3.ZERO:
			# Centrar
			mesh_node.position = -aabb.position - aabb.size * 0.5
			# Escalar uniformemente y aplicar user_scale
			var max_dim: float = max(aabb.size.x, aabb.size.y, aabb.size.z)
			if max_dim > 0:
				mesh_node.scale = Vector3.ONE * (1.0 / max_dim) * user_scale

	for child in node.get_children():
		normalize_model_recursive(child)

# Description: Updates directional light rotation based on sliders.
# Args: value (float) — slider value (not directly used)
# Returns: void
func _on_light_rotation_changed(pitch_degrees: float, yaw_degrees: float, roll_degrees: float) -> void:
	light_rotation_pitch = pitch_degrees
	light_rotation_yaw = wrapf(yaw_degrees, -180.0, 180.0)
	light_rotation_roll = wrapf(roll_degrees, -180.0, 180.0)
	_apply_light_rotation()

# Description: Applies model rotation based on the sphere control.
# Args: pitch_degrees (float), yaw_degrees (float)
# Returns: void
func _on_model_rotation_changed(pitch_degrees: float, yaw_degrees: float, roll_degrees: float) -> void:
	# backward-compatible absolute setter
	model_rotation_pitch = pitch_degrees
	model_rotation_yaw = wrapf(yaw_degrees, -180.0, 180.0)
	model_rotation_roll = wrapf(roll_degrees, -180.0, 180.0)
	_apply_model_rotation()


func _on_model_rotation_delta(pitch_delta: float, yaw_delta: float, roll_delta: float) -> void:
	if current_model == null:
		return
	# Prefer rotating around camera axes so drag feels relative to view
	if render_camera != null:
		var cam_basis: Basis = render_camera.global_transform.basis
		var right: Vector3 = cam_basis.x.normalized()
		var up: Vector3 = cam_basis.y.normalized()
		var forward: Vector3 = -cam_basis.z.normalized()

		var b_pitch: Basis = Basis(right, deg_to_rad(pitch_delta))
		var b_yaw: Basis = Basis(up, deg_to_rad(yaw_delta))
		var b_roll: Basis = Basis(forward, deg_to_rad(roll_delta))

		var b: Basis = b_yaw * b_pitch * b_roll

		var gt: Transform3D = current_model.global_transform
		gt.basis = (b * gt.basis).orthonormalized()
		current_model.global_transform = gt
	else:
		# Fallback: rotate in local axes
		if pitch_delta != 0.0:
			current_model.rotate_x(deg_to_rad(pitch_delta))
		if yaw_delta != 0.0:
			current_model.rotate_y(deg_to_rad(yaw_delta))
		if roll_delta != 0.0:
			current_model.rotate_z(deg_to_rad(roll_delta))

	# Sync stored Euler values with actual model rotation (for UI/state)
	var r_deg: Vector3 = current_model.rotation_degrees
	model_rotation_pitch = r_deg.x
	model_rotation_yaw = r_deg.y
	model_rotation_roll = r_deg.z


# Description: Applies the current model rotation to the active model.
# Args: none
# Returns: void
func _apply_model_rotation() -> void:
	if current_model == null:
		return
	current_model.rotation_degrees = Vector3(model_rotation_pitch, model_rotation_yaw, model_rotation_roll)

func _apply_light_rotation() -> void:
	directional_light.rotation_degrees = Vector3(light_rotation_pitch, light_rotation_yaw, light_rotation_roll)


# This ensures any animations or external transforms are reflected in the sphere control.
func _process(_delta: float) -> void:
	if current_model == null or model_rotation_control == null:
		return

	var model_basis: Basis = current_model.global_transform.basis.orthonormalized()

	# Update stored state for compatibility with existing code paths.
	var r_deg: Vector3 = model_basis.get_euler()
	model_rotation_pitch = rad_to_deg(r_deg.x)
	model_rotation_yaw = rad_to_deg(r_deg.y)
	model_rotation_roll = rad_to_deg(r_deg.z)

	# Push the actual basis so the sphere does not snap through Euler singularities.
	if model_rotation_control.has_method("set_sphere_basis"):
		model_rotation_control.set_sphere_basis(model_basis)
	elif model_rotation_control.has_method("set_sphere_rotation"):
		model_rotation_control.set_sphere_rotation(model_rotation_pitch, model_rotation_yaw, model_rotation_roll)

# Description: Updates `render_scene` position based on spinners.
# Args: _value (float) — new value (not directly used)
# Returns: void
func _on_render_position_changed(_value: float) -> void:
	if render_scene == null:
		return
	var pos_x = float(render_pos_x_spin.value) if render_pos_x_spin else render_scene.position.x
	var pos_y = float(render_pos_y_spin.value) if render_pos_y_spin else render_scene.position.y
	var pos_z = float(render_pos_z_spin.value) if render_pos_z_spin else render_scene.position.z
	render_scene.position = Vector3(pos_x, pos_y, pos_z)


func _on_drag_target_moved(new_position: Vector3) -> void:
	if render_pos_x_spin:
		render_pos_x_spin.set_value_no_signal(new_position.x)
	if render_pos_y_spin:
		render_pos_y_spin.set_value_no_signal(new_position.y)
	if render_pos_z_spin:
		render_pos_z_spin.set_value_no_signal(new_position.z)


func _on_scale_step_requested(step_delta: float) -> void:
	var target_scale: float = float(scale_spin.value) + step_delta
	target_scale = clampf(target_scale, float(scale_spin.min_value), float(scale_spin.max_value))
	scale_spin.value = target_scale

# Description: Adjusts directional light intensity.
# Args: value (float) — new intensity
# Returns: void
func _on_light_intensity_changed(value: float) -> void:
	directional_light.light_energy = value

# Description: Updates directional light color based on RGB sliders.
# Args: value (float) — slider value (not directly used)
# Returns: void
func _on_light_color_changed(value: float) -> void:
	var r: float = float(light_r_slider.value) / 255.0
	var g: float = float(light_g_slider.value) / 255.0
	var b: float = float(light_b_slider.value) / 255.0
	directional_light.light_color = Color(r, g, b, 1.0)


func _set_shader_model(model: Node) -> void:
	if shader_option != null and shader_option.has_method("set_model"):
		shader_option.set_model(model)


func _refresh_shader_render_size() -> void:
	if shader_option == null:
		return
	if shader_option.has_method("refresh_render_size"):
		shader_option.refresh_render_size()
	if shader_option.has_method("apply_selected_shader"):
		shader_option.apply_selected_shader()

# Description: Shows the rendering message panel with the current language text.
# Args: none
# Returns: void
func _show_rendering_message() -> void:
	if rendering_panel == null or rendering_label == null:
		return
	
	if language_selector != null:
		rendering_label.text = language_selector.get_text("rendering_message")
	else:
		rendering_label.text = "Rendering..."
	
	rendering_panel.visible = true

# Description: Hides the rendering message panel.
# Args: none
# Returns: void
func _hide_rendering_message() -> void:
	if rendering_panel == null:
		return
	
	rendering_panel.visible = false
