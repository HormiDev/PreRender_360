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


# ---------- UI ----------
@onready var width_spin: SpinBox = $Control/RenderWidth
@onready var height_spin: SpinBox = $Control/RenderHeigth
@onready var captures_spin: SpinBox = $Control/NCaptures
@onready var format_option: OptionButton = $Control/ImageFormat
@onready var file_prefix_input: LineEdit = $Control/FilePrefixInput
@onready var capture_button: Button = $Control/Button
@onready var scale_spin: SpinBox = $Control/ScaleSpin
@onready var light_pitch_slider: HSlider = $Control/LightPitchSlider
@onready var light_yaw_slider: HSlider = $Control/LightYawSlider
@onready var directional_light: DirectionalLight3D = $SubViewport/DirectionalLight3D
@onready var model_rot_x_slider: HSlider = $Control/ModelRotXSlider
@onready var model_rot_z_slider: HSlider = $Control/ModelRotZSlider
@onready var light_intensity_slider: HSlider = $Control/LightIntensitySlider
@onready var import_button: Button = $Control/ImportButton
@onready var file_dialog: FileDialog = $Control/FileDialog
@onready var light_r_slider: HSlider = $Control/LightRSlider
@onready var light_g_slider: HSlider = $Control/LightGSlider
@onready var light_b_slider: HSlider = $Control/LightBSlider
@onready var render_pos_x_spin: SpinBox = $Control.get_node_or_null("RenderPosXSpin")
@onready var render_pos_y_spin: SpinBox = $Control.get_node_or_null("RenderPosYSpin")
@onready var render_pos_z_spin: SpinBox = $Control.get_node_or_null("RenderPosZSpin")
@onready var n_frames_spin: SpinBox = $Control.get_node_or_null("NFrames")


# ---------- RENDER ----------
@onready var viewport: SubViewport = $SubViewport
@onready var render_scene: Node3D = $SubViewport/RenderScene

# ---------- VARIABLES ----------
@export var render_width := 512
@export var render_height := 512
@export var capture_count := 36
@export var anim_fps := 30

var image_format: int = ImageFormat.PNG
var current_model: Node = null
var file_prefix := "capture_angle_"

# Buffers temporales para export web
var _web_capture_buffers := []
var _web_import_callback_ref: JavaScriptObject


# ---------- READY ----------
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
	ensure_capture_folder()
	# Botón import
	import_button.pressed.connect(_on_import_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	# Rescalado
	scale_spin.value_changed.connect(_on_scale_changed)
	# Rotacion de la luz
	light_pitch_slider.value_changed.connect(_on_light_rotation_changed)
	light_yaw_slider.value_changed.connect(_on_light_rotation_changed)
	# Rotacion del modelo
	model_rot_x_slider.value_changed.connect(_on_model_rotation_changed)
	model_rot_z_slider.value_changed.connect(_on_model_rotation_changed)
	
	# Posición del RenderScene
	if render_pos_x_spin:
		render_pos_x_spin.value_changed.connect(_on_render_position_changed)
	if render_pos_y_spin:
		render_pos_y_spin.value_changed.connect(_on_render_position_changed)
	if render_pos_z_spin:
		render_pos_z_spin.value_changed.connect(_on_render_position_changed)

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
		_apply_user_scale()
		_update_nframes_ui()
	
		# Color RGB de la luz
	light_r_slider.value_changed.connect(_on_light_color_changed)
	light_g_slider.value_changed.connect(_on_light_color_changed)
	light_b_slider.value_changed.connect(_on_light_color_changed)
	# Aplicar color inicial
	_on_light_color_changed(0)



# ---------- BOTÓN ----------
func _on_button_pressed():
	print("Iniciando captura 360°...")

	render_width = int(width_spin.value)
	render_height = int(height_spin.value)
	capture_count = int(captures_spin.value)
	image_format = format_option.get_selected_id()
	
	if file_prefix_input and file_prefix_input.text.strip_edges() != "":
		file_prefix = file_prefix_input.text.strip_edges()
	else:
		file_prefix = "capture_angle_"

	viewport.size = Vector2i(render_width, render_height)

	await capture_360()

# ---------- CARPETA ----------
func ensure_capture_folder():
	if OS.has_feature("web"):
		return

	var base_dir := capture_directory.get_base_dir()
	var folder_name := capture_directory.get_file()

	var dir = DirAccess.open(base_dir)
	if dir == null:
		push_error("Ruta inválida: " + base_dir)
		return

	if not dir.dir_exists(folder_name):
		dir.make_dir(folder_name)

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

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null

# ---------- CAPTURA ----------
func capture_360() -> void:
	ensure_capture_folder()
	clear_capture_folder()

	render_scene.rotation = Vector3.ZERO
	var step_degrees := 360.0 / capture_count

	var anim_player := _find_animation_player(current_model) if current_model else null
	var has_anim := anim_player != null and anim_player.get_animation_list().size() > 0

	if has_anim:
		var anim_name: String = anim_player.get_animation_list()[0]
		var anim := anim_player.get_animation(anim_name)
		var total_frames := int(n_frames_spin.value) if n_frames_spin else 30
		if total_frames <= 0:
			total_frames = 1

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

				if image_format == ImageFormat.JPG:
					image.convert(Image.FORMAT_RGB8)

				var base_path := "%s/%sf%03d_%03d" % [capture_directory, file_prefix, f, int(angle)]
				if OS.has_feature("web"):
					var fname := "%sf%03d_%03d" % [file_prefix, f, int(angle)]
					var buf := save_image_web_buffer(image, fname)
					_web_capture_buffers.append({"name": fname, "data": buf})
				else:
					save_image(image, base_path)
	else:
		for i in range(capture_count):
			var angle := step_degrees * i

			render_scene.rotation_degrees.y = angle

			await get_tree().process_frame
			await get_tree().process_frame

			var image: Image = viewport.get_texture().get_image()

			if image_format == ImageFormat.JPG:
				image.convert(Image.FORMAT_RGB8)

			var base_path := "%s/%s%03d" % [capture_directory, file_prefix, int(angle)]
			if OS.has_feature("web"):
				var fname := "%s%03d" % [file_prefix, int(angle)]
				var buf := save_image_web_buffer(image, fname)
				_web_capture_buffers.append({"name": fname, "data": buf})
			else:
				save_image(image, base_path)

	print("Captura 360° completada.")
	print("Guardado en:", ProjectSettings.globalize_path(capture_directory))

	# Si estamos en web, empaquetar y descargar un ZIP con todas las capturas
	if OS.has_feature("web") and _web_capture_buffers.size() > 0:
		var zip_name := file_prefix + ".zip"
		var zip_data := build_zip_from_files(_web_capture_buffers)
		JavaScriptBridge.download_buffer(zip_data, zip_name, "application/zip")
		_web_capture_buffers.clear()

# ---------- GUARDAR ----------
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


func _u16_le(val: int) -> PackedByteArray:
	var a := PackedByteArray()
	var u := val & 0xFFFF
	a.append(u & 0xFF)
	a.append((u >> 8) & 0xFF)
	return a


func _u32_le(val: int) -> PackedByteArray:
	var a := PackedByteArray()
	var u := val & 0xFFFFFFFF
	a.append(u & 0xFF)
	a.append((u >> 8) & 0xFF)
	a.append((u >> 16) & 0xFF)
	a.append((u >> 24) & 0xFF)
	return a


func _append_pba(dest: PackedByteArray, src: PackedByteArray) -> void:
	for b in src:
		dest.append(b)


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


func xpm_code(index: int, chars_per_pixel: int) -> String:
	var base := XPM_CHARS.length()
	var code := ""

	for i in range(chars_per_pixel):
		code = XPM_CHARS[index % base] + code
		index = floori(float(index) / float(base))

	return code

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
		push_error("No se pudo escribir XPM en: " + ProjectSettings.globalize_path(path))
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
		push_error("No se pudo escribir XPM")
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
		push_error("No se pudo escribir XPM")
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


func _on_import_button_pressed() -> void:
	if OS.has_feature("web"):
		_open_web_model_picker()
		return
	file_dialog.popup()

func _on_file_selected(path: String):
	load_glb_runtime(path)


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


func _on_web_model_file_picked(args: Array) -> void:
	if args.size() < 2:
		return

	var data_url := str(args[0])
	var file_name := str(args[1])
	if data_url.is_empty():
		return

	var comma_pos := data_url.find(",")
	if comma_pos == -1:
		push_error("No se pudo leer el modelo del navegador: formato de datos inválido")
		return

	var raw_data := Marshalls.base64_to_raw(data_url.substr(comma_pos + 1))
	load_glb_runtime_from_bytes(raw_data, file_name)

func load_glb_runtime(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Archivo GLB no existe: %s" % path)
		return
	var data := file.get_buffer(file.get_length())
	load_glb_runtime_from_bytes(data, path.get_file())


func load_glb_runtime_from_bytes(data: PackedByteArray, source_name: String = "") -> void:
	# Limpia modelos previos
	for child in render_scene.get_children():
		child.queue_free()

	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()

	var err: int = gltf.append_from_buffer(data, source_name, state)
	if err != OK:
		push_error("Error cargando GLB: %s" % str(err))
		return

	var scene: Node = gltf.generate_scene(state)
	if scene == null:
		push_error("No se pudo generar la escena desde GLB")
		return

	# Se añade diferido para evitar crashes en SubViewport
	call_deferred("_add_to_render_scene", scene)



func _add_to_render_scene(scene: Node) -> void:
	if not scene:
		return

	# Limpia cualquier modelo previo (ya lo haces en load_glb_runtime)
	render_scene.add_child(scene)
	scene.owner = render_scene

	# Guardar referencia para escalar luego
	current_model = scene

	# Normalizar todos los meshes
	normalize_model_recursive(scene)

	# Aplicar la escala inicial del usuario
	_apply_user_scale()
	_update_nframes_ui()

func _apply_user_scale() -> void:
	if current_model == null:
		return

	var user_scale: float = float(scale_spin.value)
	current_model.scale = Vector3.ONE * user_scale

func _on_scale_changed(_value: float) -> void:
	_apply_user_scale()


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

func _on_light_rotation_changed(value: float) -> void:
	# Leer valores de los sliders
	var pitch: float = float(light_pitch_slider.value)  # rotación X
	var yaw: float = float(light_yaw_slider.value)      # rotación Y

	# Aplicar rotación a la luz en grados
	directional_light.rotation_degrees = Vector3(pitch, yaw, 0)

func _on_model_rotation_changed(value: float) -> void:
	if current_model == null:
		return
	# Leer sliders
	var rot_x = float(model_rot_x_slider.value)  # arriba-abajo
	var rot_z = float(model_rot_z_slider.value)  # eje Z
	# Aplicar rotación (Y se mantiene en 0)
	current_model.rotation_degrees = Vector3(rot_x, 0, rot_z)

func _on_render_position_changed(_value: float) -> void:
	if render_scene == null:
		return
	var pos_x = float(render_pos_x_spin.value) if render_pos_x_spin else render_scene.position.x
	var pos_y = float(render_pos_y_spin.value) if render_pos_y_spin else render_scene.position.y
	var pos_z = float(render_pos_z_spin.value) if render_pos_z_spin else render_scene.position.z
	render_scene.position = Vector3(pos_x, pos_y, pos_z)

func _on_light_intensity_changed(value: float) -> void:
	directional_light.light_energy = value

func _on_light_color_changed(value: float) -> void:
	var r: float = float(light_r_slider.value) / 255.0
	var g: float = float(light_g_slider.value) / 255.0
	var b: float = float(light_b_slider.value) / 255.0
	directional_light.light_color = Color(r, g, b, 1.0)
