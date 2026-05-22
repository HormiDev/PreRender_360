extends RefCounted

# GIF export support inspired by GDGIFExporter:
# https://github.com/jegor377/godot-gdgifexporter

const TRANSPARENT_INDEX := 0
const COLOR_TABLE_SIZE := 256
const LZW_MIN_CODE_SIZE := 8
const LZW_CLEAR_CODE := 256
const LZW_END_CODE := 257
const LZW_CODE_SIZE := 9
const LZW_LITERAL_CHUNK_SIZE := 252

var _width := 0
var _height := 0
var _data := PackedByteArray()
var _has_frames := false

var _lzw_stream := PackedByteArray()
var _lzw_bit_buffer := 0
var _lzw_bit_count := 0


func _init(width: int, height: int) -> void:
	_width = width
	_height = height
	_add_header()
	_add_logical_screen_descriptor()
	_add_loop_extension()


func add_frame(source_image: Image, frame_delay: float) -> int:
	if source_image == null or source_image.is_empty():
		return ERR_INVALID_DATA

	var image := source_image.duplicate()
	if image.get_width() != _width or image.get_height() != _height:
		image.resize(_width, _height, Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_RGBA8)

	var quantized := _quantize_image(image)
	var indexes: PackedByteArray = quantized["indexes"]
	var has_transparency: bool = quantized["has_transparency"]

	_add_graphic_control_extension(frame_delay, has_transparency)
	_add_image_descriptor()
	var local_color_table: PackedByteArray = quantized["palette"]
	_data.append_array(local_color_table)
	_add_image_data(indexes)
	_has_frames = true
	return OK


func export_file_data() -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(_data)
	if _has_frames:
		result.append(0x3b)
	return result


func _add_header() -> void:
	_data.append_array("GIF89a".to_ascii_buffer())


func _add_logical_screen_descriptor() -> void:
	_append_u16(_width)
	_append_u16(_height)
	_data.append(0x70)
	_data.append(TRANSPARENT_INDEX)
	_data.append(0)


func _add_loop_extension() -> void:
	_append_bytes([0x21, 0xff, 0x0b])
	_data.append_array("NETSCAPE2.0".to_ascii_buffer())
	_append_bytes([0x03, 0x01])
	_append_u16(0)
	_data.append(0)


func _add_graphic_control_extension(frame_delay: float, has_transparency: bool) -> void:
	var delay_cs: int = maxi(1, roundi(frame_delay * 100.0))
	var packed_fields := 0x08
	if has_transparency:
		packed_fields = 0x09

	_append_bytes([0x21, 0xf9, 0x04, packed_fields])
	_append_u16(delay_cs)
	_data.append(TRANSPARENT_INDEX if has_transparency else 0)
	_data.append(0)


func _add_image_descriptor() -> void:
	_data.append(0x2c)
	_append_u16(0)
	_append_u16(0)
	_append_u16(_width)
	_append_u16(_height)
	_data.append(0x80 | 0x07)


func _add_image_data(indexes: PackedByteArray) -> void:
	_data.append(LZW_MIN_CODE_SIZE)

	var encoded := _lzw_encode_literal_stream(indexes)
	var offset := 0
	while offset < encoded.size():
		var block_size: int = mini(255, encoded.size() - offset)
		_data.append(block_size)
		for i in range(block_size):
			_data.append(encoded[offset + i])
		offset += block_size

	_data.append(0)


func _quantize_image(image: Image) -> Dictionary:
	var pixels: PackedByteArray = image.get_data()
	var indexes := PackedByteArray()
	indexes.resize(_width * _height)

	var entries: Array = _build_color_entries(pixels)
	var palette_colors: Array = _build_adaptive_palette(entries, COLOR_TABLE_SIZE - 1)
	var palette_bytes := _build_color_table_bytes(palette_colors)
	var color_cache := {}

	var write_index := 0
	var has_transparency := false
	for i in range(0, pixels.size(), 4):
		var red := int(pixels[i])
		var green := int(pixels[i + 1])
		var blue := int(pixels[i + 2])
		var alpha := int(pixels[i + 3])
		if alpha < 128:
			indexes[write_index] = TRANSPARENT_INDEX
			has_transparency = true
		else:
			var bucket_key := _rgb_bucket_key(red, green, blue)
			var palette_index: int
			if color_cache.has(bucket_key):
				palette_index = int(color_cache[bucket_key])
			else:
				palette_index = _find_nearest_palette_index(red, green, blue, palette_colors)
				color_cache[bucket_key] = palette_index
			indexes[write_index] = palette_index
		write_index += 1

	return {
		"indexes": indexes,
		"has_transparency": has_transparency,
		"palette": palette_bytes,
	}


func _build_color_entries(pixels: PackedByteArray) -> Array:
	var buckets := {}
	for i in range(0, pixels.size(), 4):
		var alpha := int(pixels[i + 3])
		if alpha < 128:
			continue

		var red := int(pixels[i])
		var green := int(pixels[i + 1])
		var blue := int(pixels[i + 2])
		var bucket_key := _rgb_bucket_key(red, green, blue)
		var bucket: Dictionary
		if buckets.has(bucket_key):
			bucket = buckets[bucket_key]
		else:
			bucket = {
				"r_sum": 0,
				"g_sum": 0,
				"b_sum": 0,
				"count": 0,
			}
			buckets[bucket_key] = bucket

		bucket["r_sum"] = int(bucket["r_sum"]) + red
		bucket["g_sum"] = int(bucket["g_sum"]) + green
		bucket["b_sum"] = int(bucket["b_sum"]) + blue
		bucket["count"] = int(bucket["count"]) + 1

	var entries: Array = []
	for bucket_key in buckets.keys():
		var bucket: Dictionary = buckets[bucket_key]
		var count: int = int(bucket["count"])
		if count <= 0:
			continue

		entries.append({
			"r": roundi(float(bucket["r_sum"]) / float(count)),
			"g": roundi(float(bucket["g_sum"]) / float(count)),
			"b": roundi(float(bucket["b_sum"]) / float(count)),
			"count": count,
		})

	return entries


func _build_adaptive_palette(entries: Array, max_colors: int) -> Array:
	if entries.size() <= max_colors:
		return _entries_to_palette_colors(entries)

	var boxes: Array = [entries]
	while boxes.size() < max_colors:
		var box_index := _find_box_to_split(boxes)
		if box_index < 0:
			break

		var box: Array = boxes[box_index]
		var axis := _largest_range_axis(box)
		match axis:
			"r":
				box.sort_custom(_sort_entries_by_red)
			"g":
				box.sort_custom(_sort_entries_by_green)
			_:
				box.sort_custom(_sort_entries_by_blue)

		var split_at := _weighted_split_index(box)
		if split_at <= 0 or split_at >= box.size():
			break

		boxes.remove_at(box_index)
		boxes.append(box.slice(0, split_at))
		boxes.append(box.slice(split_at))

	return _boxes_to_palette_colors(boxes)


func _entries_to_palette_colors(entries: Array) -> Array:
	var colors: Array = []
	for entry in entries:
		colors.append(_pack_rgb(int(entry["r"]), int(entry["g"]), int(entry["b"])))
	return colors


func _boxes_to_palette_colors(boxes: Array) -> Array:
	var colors: Array = []
	for box in boxes:
		var box_array: Array = box
		if box_array.is_empty():
			continue
		colors.append(_average_box_color(box_array))
	return colors


func _find_box_to_split(boxes: Array) -> int:
	var best_index := -1
	var best_score := -1
	for i in range(boxes.size()):
		var box: Array = boxes[i]
		if box.size() <= 1:
			continue

		var score := _box_range_score(box)
		if score > best_score:
			best_score = score
			best_index = i

	return best_index


func _box_range_score(box: Array) -> int:
	var first: Dictionary = box[0]
	var min_r := int(first["r"])
	var max_r := min_r
	var min_g := int(first["g"])
	var max_g := min_g
	var min_b := int(first["b"])
	var max_b := min_b
	var total_count := 0

	for entry in box:
		var red := int(entry["r"])
		var green := int(entry["g"])
		var blue := int(entry["b"])
		min_r = mini(min_r, red)
		max_r = maxi(max_r, red)
		min_g = mini(min_g, green)
		max_g = maxi(max_g, green)
		min_b = mini(min_b, blue)
		max_b = maxi(max_b, blue)
		total_count += int(entry["count"])

	var range_size := maxi(max_r - min_r, maxi(max_g - min_g, max_b - min_b))
	return range_size * total_count


func _largest_range_axis(box: Array) -> String:
	var first: Dictionary = box[0]
	var min_r := int(first["r"])
	var max_r := min_r
	var min_g := int(first["g"])
	var max_g := min_g
	var min_b := int(first["b"])
	var max_b := min_b

	for entry in box:
		var red := int(entry["r"])
		var green := int(entry["g"])
		var blue := int(entry["b"])
		min_r = mini(min_r, red)
		max_r = maxi(max_r, red)
		min_g = mini(min_g, green)
		max_g = maxi(max_g, green)
		min_b = mini(min_b, blue)
		max_b = maxi(max_b, blue)

	var r_range := max_r - min_r
	var g_range := max_g - min_g
	var b_range := max_b - min_b
	if r_range >= g_range and r_range >= b_range:
		return "r"
	if g_range >= r_range and g_range >= b_range:
		return "g"
	return "b"


func _weighted_split_index(box: Array) -> int:
	var total_count := 0
	for entry in box:
		total_count += int(entry["count"])

	var half_count := total_count / 2
	var current_count := 0
	for i in range(box.size() - 1):
		var entry: Dictionary = box[i]
		current_count += int(entry["count"])
		if current_count >= half_count:
			return i + 1

	return max(1, box.size() / 2)


func _average_box_color(box: Array) -> int:
	var r_sum := 0
	var g_sum := 0
	var b_sum := 0
	var total_count := 0

	for entry in box:
		var count := int(entry["count"])
		r_sum += int(entry["r"]) * count
		g_sum += int(entry["g"]) * count
		b_sum += int(entry["b"]) * count
		total_count += count

	if total_count <= 0:
		return 0

	return _pack_rgb(
		roundi(float(r_sum) / float(total_count)),
		roundi(float(g_sum) / float(total_count)),
		roundi(float(b_sum) / float(total_count))
	)


func _build_color_table_bytes(palette_colors: Array) -> PackedByteArray:
	var color_table := PackedByteArray()
	color_table.append(0)
	color_table.append(0)
	color_table.append(0)

	var colors_written := 1
	for color in palette_colors:
		if colors_written >= COLOR_TABLE_SIZE:
			break
		var packed_color := int(color)
		color_table.append(_packed_red(packed_color))
		color_table.append(_packed_green(packed_color))
		color_table.append(_packed_blue(packed_color))
		colors_written += 1

	while colors_written < COLOR_TABLE_SIZE:
		color_table.append(0)
		color_table.append(0)
		color_table.append(0)
		colors_written += 1

	return color_table


func _find_nearest_palette_index(red: int, green: int, blue: int, palette_colors: Array) -> int:
	if palette_colors.is_empty():
		return TRANSPARENT_INDEX

	var best_index := 1
	var best_distance := 2147483647
	for i in range(palette_colors.size()):
		var color := int(palette_colors[i])
		var red_delta := red - _packed_red(color)
		var green_delta := green - _packed_green(color)
		var blue_delta := blue - _packed_blue(color)
		var distance := (red_delta * red_delta) + (green_delta * green_delta) + (blue_delta * blue_delta)
		if distance < best_distance:
			best_distance = distance
			best_index = i + 1

	return best_index


func _sort_entries_by_red(a, b) -> bool:
	return int(a["r"]) < int(b["r"])


func _sort_entries_by_green(a, b) -> bool:
	return int(a["g"]) < int(b["g"])


func _sort_entries_by_blue(a, b) -> bool:
	return int(a["b"]) < int(b["b"])


func _rgb_bucket_key(red: int, green: int, blue: int) -> int:
	return ((red >> 3) << 10) | ((green >> 3) << 5) | (blue >> 3)


func _pack_rgb(red: int, green: int, blue: int) -> int:
	return (clampi(red, 0, 255) << 16) | (clampi(green, 0, 255) << 8) | clampi(blue, 0, 255)


func _packed_red(color: int) -> int:
	return (color >> 16) & 0xff


func _packed_green(color: int) -> int:
	return (color >> 8) & 0xff


func _packed_blue(color: int) -> int:
	return color & 0xff


func _lzw_encode_literal_stream(indexes: PackedByteArray) -> PackedByteArray:
	_lzw_stream = PackedByteArray()
	_lzw_bit_buffer = 0
	_lzw_bit_count = 0

	_lzw_write_code(LZW_CLEAR_CODE)
	var literals_since_clear := 0

	for color_index in indexes:
		if literals_since_clear >= LZW_LITERAL_CHUNK_SIZE:
			_lzw_write_code(LZW_CLEAR_CODE)
			literals_since_clear = 0

		_lzw_write_code(int(color_index))
		literals_since_clear += 1

	_lzw_write_code(LZW_END_CODE)
	if _lzw_bit_count > 0:
		_lzw_stream.append(_lzw_bit_buffer & 0xff)

	var result := PackedByteArray()
	result.append_array(_lzw_stream)
	_lzw_stream = PackedByteArray()
	return result


func _lzw_write_code(code: int) -> void:
	_lzw_bit_buffer = _lzw_bit_buffer | (code << _lzw_bit_count)
	_lzw_bit_count += LZW_CODE_SIZE

	while _lzw_bit_count >= 8:
		_lzw_stream.append(_lzw_bit_buffer & 0xff)
		_lzw_bit_buffer = _lzw_bit_buffer >> 8
		_lzw_bit_count -= 8


func _append_u16(value: int) -> void:
	var safe_value := value & 0xffff
	_data.append(safe_value & 0xff)
	_data.append((safe_value >> 8) & 0xff)


func _append_bytes(values: Array) -> void:
	for value in values:
		_data.append(int(value) & 0xff)
