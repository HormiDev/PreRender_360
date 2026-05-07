extends Node

const LANGUAGE_CODES := ["en", "es", "fr", "zh", "hi", "de", "ja", "pt", "it", "ru", "uk", "ar", "id"]
const LANGUAGE_LABELS := {
	"en": "En",
	"es": "Es",
	"fr": "Fr",
	"zh": "中文",
	"hi": "हिन्दी",
	"de": "De",
	"ja": "日本語",
	"pt": "Pt",
	"it": "It",
	"ru": "Рус",
	"uk": "Укр",
	"ar": "عربى",
	"id": "Id",
}
const UI_TEXTS := {
	"en": {
		"language_label": "Language",
		"render_button": "Render",
		"render_width": "Render Width",
		"render_height": "Render Height",
		"n_frames": "N Frames",
		"n_views": "N Views",
		"image_format": "Format image",
		"atlas_mode": "Atlas mode",
		"import_button": "Import model .glb",
		"file_dialog_title": "Open a File",
		"file_dialog_ok": "Open",
		"atlas_error_title": "Atlas mode error",
		"scale_model": "Scale Model",
		"light_rotation": "Light Rotation",
		"light_intensity": "Light Intensity",
		"light_color": "Light Color",
		"save_name": "Save Name",
		"x_position": "X Position",
		"y_position": "Y Position",
		"z_position": "Z Position",
		"model_rotation": "Model Rotation",
		"atlas_disabled_prefix": "Atlas mode disabled: the resulting image would be too large.",
		"atlas_calculated_size": "Calculated size",
		"atlas_allowed_limit": "Allowed limit",
		"atlas_reduce_instruction": "Reduce Render Width, N Views or N Frames, or re-render without Atlas Mode.",
		"reset_button_tooltip": "Reset to original value"
	},
	"es": {
		"language_label": "Idioma",
		"render_button": "Renderizar",
		"render_width": "Ancho de render",
		"render_height": "Alto de render",
		"n_frames": "N. de frames",
		"n_views": "N. de vistas",
		"image_format": "Formato de imagen",
		"atlas_mode": "Modo atlas",
		"import_button": "Importar modelo .glb",
		"file_dialog_title": "Abrir un archivo",
		"file_dialog_ok": "Abrir",
		"atlas_error_title": "Error del modo atlas",
		"scale_model": "Escala del modelo",
		"light_rotation": "Rotación de la luz",
		"light_intensity": "Intensidad de la luz",
		"light_color": "Color de la luz",
		"save_name": "Nombre de guardado",
		"x_position": "Posición X",
		"y_position": "Posición Y",
		"z_position": "Posición Z",
		"model_rotation": "Rotación del modelo",
		"atlas_disabled_prefix": "El modo atlas se ha desactivado porque la imagen resultante sería demasiado grande.",
		"atlas_calculated_size": "Tamaño calculado",
		"atlas_allowed_limit": "Límite permitido",
		"atlas_reduce_instruction": "Reduce el ancho de render, el número de vistas o el número de frames, o vuelve a renderizar sin modo atlas.",
		"reset_button_tooltip": "Restablecer al valor original"
	},
	"fr": {
		"language_label": "Langue",
		"render_button": "Rendre",
		"render_width": "Largeur de rendu",
		"render_height": "Hauteur de rendu",
		"n_frames": "N. de frames",
		"n_views": "N. de vues",
		"image_format": "Format d'image",
		"atlas_mode": "Mode atlas",
		"import_button": "Importer le modèle .glb",
		"file_dialog_title": "Ouvrir un fichier",
		"file_dialog_ok": "Ouvrir",
		"atlas_error_title": "Erreur du mode atlas",
		"scale_model": "Échelle du modèle",
		"light_rotation": "Rotation de la lumière",
		"light_intensity": "Intensité de la lumière",
		"light_color": "Couleur de la lumière",
		"save_name": "Nom de sauvegarde",
		"x_position": "Position X",
		"y_position": "Position Y",
		"z_position": "Position Z",
		"model_rotation": "Rotation du modèle",
		"atlas_disabled_prefix": "Le mode atlas a été désactivé car l'image résultante serait trop grande.",
		"atlas_calculated_size": "Taille calculée",
		"atlas_allowed_limit": "Limite autorisée",
		"atlas_reduce_instruction": "Réduisez la largeur de rendu, le nombre de vues ou le nombre de frames, ou relancez le rendu sans le mode atlas.",
		"reset_button_tooltip": "Réinitialiser à la valeur d'origine"
	},
	"zh": {
		"language_label": "语言",
		"render_button": "渲染",
		"render_width": "渲染宽度",
		"render_height": "渲染高度",
		"n_frames": "帧数",
		"n_views": "视图数",
		"image_format": "图像格式",
		"atlas_mode": "图集模式",
		"import_button": "导入 .glb 模型",
		"file_dialog_title": "打开文件",
		"file_dialog_ok": "打开",
		"atlas_error_title": "图集模式错误",
		"scale_model": "模型缩放",
		"light_rotation": "光照旋转",
		"light_intensity": "光照强度",
		"light_color": "光照颜色",
		"save_name": "保存名称",
		"x_position": "X 位置",
		"y_position": "Y 位置",
		"z_position": "Z 位置",
		"model_rotation": "模型旋转",
		"atlas_disabled_prefix": "图集模式已禁用：生成的图像将会过大。",
		"atlas_calculated_size": "计算尺寸",
		"atlas_allowed_limit": "允许上限",
		"atlas_reduce_instruction": "请减小渲染宽度、视图数或帧数，或在不使用图集模式下重新渲染。",
		"reset_button_tooltip": "重置为原始值"
	},
	"hi": {
		"language_label": "भाषा",
		"render_button": "रेंडर",
		"render_width": "रेंडर चौड़ाई",
		"render_height": "रेंडर ऊँचाई",
		"n_frames": "फ्रेम संख्या",
		"n_views": "व्यू संख्या",
		"image_format": "इमेज फ़ॉर्मेट",
		"atlas_mode": "एटलस मोड",
		"import_button": ".glb मॉडल आयात करें",
		"file_dialog_title": "फ़ाइल खोलें",
		"file_dialog_ok": "खोलें",
		"atlas_error_title": "एटलस मोड त्रुटि",
		"scale_model": "मॉडल स्केल",
		"light_rotation": "लाइट रोटेशन",
		"light_intensity": "लाइट तीव्रता",
		"light_color": "लाइट रंग",
		"save_name": "सहेजने का नाम",
		"x_position": "X स्थिति",
		"y_position": "Y स्थिति",
		"z_position": "Z स्थिति",
		"model_rotation": "मॉडल रोटेशन",
		"atlas_disabled_prefix": "एटलस मोड बंद किया गया: परिणामस्वरूप छवि बहुत बड़ी होगी।",
		"atlas_calculated_size": "गणना किया गया आकार",
		"atlas_allowed_limit": "अनुमत सीमा",
		"atlas_reduce_instruction": "रेंडर चौड़ाई, व्यू संख्या या फ्रेम संख्या कम करें, या एटलस मोड के बिना फिर से रेंडर करें।",
		"reset_button_tooltip": "मूल मान पर रीसेट करें"
	},
	"de": {
		"language_label": "Sprache",
		"render_button": "Rendern",
		"render_width": "Render-Breite",
		"render_height": "Render-Höhe",
		"n_frames": "Anzahl Frames",
		"n_views": "Anzahl Ansichten",
		"image_format": "Bildformat",
		"atlas_mode": "Atlas-Modus",
		"import_button": ".glb-Modell importieren",
		"file_dialog_title": "Datei öffnen",
		"file_dialog_ok": "Öffnen",
		"atlas_error_title": "Atlas-Modus-Fehler",
		"scale_model": "Modell skalieren",
		"light_rotation": "Lichtrotation",
		"light_intensity": "Lichtintensität",
		"light_color": "Lichtfarbe",
		"save_name": "Speichername",
		"x_position": "X-Position",
		"y_position": "Y-Position",
		"z_position": "Z-Position",
		"model_rotation": "Modellrotation",
		"atlas_disabled_prefix": "Atlas-Modus deaktiviert: Das resultierende Bild wäre zu groß.",
		"atlas_calculated_size": "Berechnete Größe",
		"atlas_allowed_limit": "Erlaubtes Limit",
		"atlas_reduce_instruction": "Verringere Render-Breite, Ansichten oder Frames, oder rendere ohne Atlas-Modus erneut.",
		"reset_button_tooltip": "Auf den ursprünglichen Wert zurücksetzen"
	},
	"ja": {
		"language_label": "言語",
		"render_button": "レンダー",
		"render_width": "レンダー幅",
		"render_height": "レンダー高さ",
		"n_frames": "フレーム数",
		"n_views": "ビュー数",
		"image_format": "画像形式",
		"atlas_mode": "アトラスモード",
		"import_button": ".glb モデルを読み込む",
		"file_dialog_title": "ファイルを開く",
		"file_dialog_ok": "開く",
		"atlas_error_title": "アトラスモードエラー",
		"scale_model": "モデルのスケール",
		"light_rotation": "ライト回転",
		"light_intensity": "ライト強度",
		"light_color": "ライトカラー",
		"save_name": "保存名",
		"x_position": "X 位置",
		"y_position": "Y 位置",
		"z_position": "Z 位置",
		"model_rotation": "モデル回転",
		"atlas_disabled_prefix": "アトラスモードは無効化されました。生成される画像サイズが大きすぎます。",
		"atlas_calculated_size": "計算サイズ",
		"atlas_allowed_limit": "許容上限",
		"atlas_reduce_instruction": "レンダー幅、ビュー数、またはフレーム数を減らすか、アトラスモードなしで再レンダーしてください。",
		"reset_button_tooltip": "元の値に戻す"
	},
	"pt": {
		"language_label": "Idioma",
		"render_button": "Renderizar",
		"render_width": "Largura de render",
		"render_height": "Altura de render",
		"n_frames": "Nº de frames",
		"n_views": "Nº de vistas",
		"image_format": "Formato de imagem",
		"atlas_mode": "Modo atlas",
		"import_button": "Importar modelo .glb",
		"file_dialog_title": "Abrir arquivo",
		"file_dialog_ok": "Abrir",
		"atlas_error_title": "Erro do modo atlas",
		"scale_model": "Escala do modelo",
		"light_rotation": "Rotação da luz",
		"light_intensity": "Intensidade da luz",
		"light_color": "Cor da luz",
		"save_name": "Nome para salvar",
		"x_position": "Posição X",
		"y_position": "Posição Y",
		"z_position": "Posição Z",
		"model_rotation": "Rotação do modelo",
		"atlas_disabled_prefix": "Modo atlas desativado: a imagem resultante seria muito grande.",
		"atlas_calculated_size": "Tamanho calculado",
		"atlas_allowed_limit": "Limite permitido",
		"atlas_reduce_instruction": "Reduza a largura de render, o número de vistas ou frames, ou renderize novamente sem o modo atlas.",
		"reset_button_tooltip": "Redefinir para o valor original"
	},
	"it": {
		"language_label": "Lingua",
		"render_button": "Renderizza",
		"render_width": "Larghezza render",
		"render_height": "Altezza render",
		"n_frames": "N. frame",
		"n_views": "N. viste",
		"image_format": "Formato immagine",
		"atlas_mode": "Modalità atlas",
		"import_button": "Importa modello .glb",
		"file_dialog_title": "Apri file",
		"file_dialog_ok": "Apri",
		"atlas_error_title": "Errore modalità atlas",
		"scale_model": "Scala modello",
		"light_rotation": "Rotazione luce",
		"light_intensity": "Intensità luce",
		"light_color": "Colore luce",
		"save_name": "Nome salvataggio",
		"x_position": "Posizione X",
		"y_position": "Posizione Y",
		"z_position": "Posizione Z",
		"model_rotation": "Rotazione modello",
		"atlas_disabled_prefix": "Modalità atlas disattivata: l'immagine risultante sarebbe troppo grande.",
		"atlas_calculated_size": "Dimensione calcolata",
		"atlas_allowed_limit": "Limite consentito",
		"atlas_reduce_instruction": "Riduci la larghezza di render, il numero di viste o di frame, oppure renderizza di nuovo senza modalità atlas.",
		"reset_button_tooltip": "Ripristina al valore originale"
	},
	"ru": {
		"language_label": "Язык",
		"render_button": "Рендер",
		"render_width": "Ширина рендера",
		"render_height": "Высота рендера",
		"n_frames": "Кол-во кадров",
		"n_views": "Кол-во видов",
		"image_format": "Формат изображения",
		"atlas_mode": "Режим атласа",
		"import_button": "Импортировать модель .glb",
		"file_dialog_title": "Открыть файл",
		"file_dialog_ok": "Открыть",
		"atlas_error_title": "Ошибка режима атласа",
		"scale_model": "Масштаб модели",
		"light_rotation": "Поворот света",
		"light_intensity": "Интенсивность света",
		"light_color": "Цвет света",
		"save_name": "Имя сохранения",
		"x_position": "Позиция X",
		"y_position": "Позиция Y",
		"z_position": "Позиция Z",
		"model_rotation": "Поворот модели",
		"atlas_disabled_prefix": "Режим атласа отключен: итоговое изображение будет слишком большим.",
		"atlas_calculated_size": "Рассчитанный размер",
		"atlas_allowed_limit": "Допустимый предел",
		"atlas_reduce_instruction": "Уменьшите ширину рендера, количество видов или кадров, либо выполните рендер без режима атласа.",
		"reset_button_tooltip": "Сбросить к исходному значению"
	},
	"uk": {
		"language_label": "Мова",
		"render_button": "Рендер",
		"render_width": "Ширина рендеру",
		"render_height": "Висота рендеру",
		"n_frames": "К-сть кадрів",
		"n_views": "К-сть ракурсів",
		"image_format": "Формат зображення",
		"atlas_mode": "Режим атласу",
		"import_button": "Імпортувати модель .glb",
		"file_dialog_title": "Відкрити файл",
		"file_dialog_ok": "Відкрити",
		"atlas_error_title": "Помилка режиму атласу",
		"scale_model": "Масштаб моделі",
		"light_rotation": "Обертання світла",
		"light_intensity": "Інтенсивність світла",
		"light_color": "Колір світла",
		"save_name": "Назва збереження",
		"x_position": "Позиція X",
		"y_position": "Позиція Y",
		"z_position": "Позиція Z",
		"model_rotation": "Обертання моделі",
		"atlas_disabled_prefix": "Режим атласу вимкнено: підсумкове зображення буде занадто великим.",
		"atlas_calculated_size": "Розрахований розмір",
		"atlas_allowed_limit": "Дозволена межа",
		"atlas_reduce_instruction": "Зменште ширину рендеру, кількість ракурсів або кадрів, або перерендерте без режиму атласу.",
		"reset_button_tooltip": "Скинути до початкового значення"
	},
	"ar": {
		"language_label": "اللغة",
		"render_button": "تصيير",
		"render_width": "عرض التصيير",
		"render_height": "ارتفاع التصيير",
		"n_frames": "عدد الإطارات",
		"n_views": "عدد الزوايا",
		"image_format": "صيغة الصورة",
		"atlas_mode": "وضع الأطلس",
		"import_button": "استيراد نموذج .glb",
		"file_dialog_title": "فتح ملف",
		"file_dialog_ok": "فتح",
		"atlas_error_title": "خطأ وضع الأطلس",
		"scale_model": "مقياس النموذج",
		"light_rotation": "دوران الإضاءة",
		"light_intensity": "شدة الإضاءة",
		"light_color": "لون الإضاءة",
		"save_name": "اسم الحفظ",
		"x_position": "الموضع X",
		"y_position": "الموضع Y",
		"z_position": "الموضع Z",
		"model_rotation": "دوران النموذج",
		"atlas_disabled_prefix": "تم تعطيل وضع الأطلس: الصورة الناتجة ستكون كبيرة جدا.",
		"atlas_calculated_size": "الحجم المحسوب",
		"atlas_allowed_limit": "الحد المسموح",
		"atlas_reduce_instruction": "خفّض عرض التصيير أو عدد الزوايا أو عدد الإطارات، أو أعد التصيير بدون وضع الأطلس.",
		"reset_button_tooltip": "إعادة الضبط إلى القيمة الأصلية"
	},
	"id": {
		"language_label": "Bahasa",
		"render_button": "Render",
		"render_width": "Lebar render",
		"render_height": "Tinggi render",
		"n_frames": "Jumlah frame",
		"n_views": "Jumlah sudut",
		"image_format": "Format gambar",
		"atlas_mode": "Mode atlas",
		"import_button": "Impor model .glb",
		"file_dialog_title": "Buka file",
		"file_dialog_ok": "Buka",
		"atlas_error_title": "Kesalahan mode atlas",
		"scale_model": "Skala model",
		"light_rotation": "Rotasi cahaya",
		"light_intensity": "Intensitas cahaya",
		"light_color": "Warna cahaya",
		"save_name": "Nama simpan",
		"x_position": "Posisi X",
		"y_position": "Posisi Y",
		"z_position": "Posisi Z",
		"model_rotation": "Rotasi model",
		"atlas_disabled_prefix": "Mode atlas dinonaktifkan: gambar hasil akan terlalu besar.",
		"atlas_calculated_size": "Ukuran terhitung",
		"atlas_allowed_limit": "Batas yang diizinkan",
		"atlas_reduce_instruction": "Kurangi lebar render, jumlah sudut, atau jumlah frame, atau render ulang tanpa mode atlas.",
		"reset_button_tooltip": "Setel ulang ke nilai asli"
	},
}

var _control: Control
var _language_option: OptionButton
var _format_option: OptionButton
var _current_language := "en"


# Description: Initializes language selector references, populates options and applies default language.
# Args: none
# Returns: void
func _ready() -> void:
	_control = get_parent() as Control
	if _control == null:
		return

	_language_option = _control.get_node_or_null("LanguageOptionButton") as OptionButton
	_format_option = _control.get_node_or_null("ImageFormat") as OptionButton
	_populate_language_options()
	_apply_language("en")

	if _language_option != null and not _language_option.item_selected.is_connected(_on_language_selected):
		_language_option.item_selected.connect(_on_language_selected)


# Description: Applies a language code externally.
# Args: language_code (String) — language code to apply
# Returns: void
func set_language(language_code: String) -> void:
	_apply_language(language_code)


# Description: Returns the currently active language code.
# Args: none
# Returns: String — active language code
func get_current_language() -> String:
	return _current_language


# Description: Returns a localized text for a key with fallback to English.
# Args: key (String) — translation key
# Returns: String — localized text or key if not found
func get_text(key: String) -> String:
	var texts: Dictionary = UI_TEXTS.get(_current_language, UI_TEXTS["en"])
	if texts.has(key):
		return str(texts[key])

	var english_texts: Dictionary = UI_TEXTS["en"]
	if english_texts.has(key):
		return str(english_texts[key])

	return key


# Description: Fills the language option button with all available language labels.
# Args: none
# Returns: void
func _populate_language_options() -> void:
	if _language_option == null:
		return

	_language_option.clear()
	for language_code in LANGUAGE_CODES:
		_language_option.add_item(LANGUAGE_LABELS[language_code])


# Description: Handles language option selection changes.
# Args: index (int) — selected option index
# Returns: void
func _on_language_selected(index: int) -> void:
	if index < 0 or index >= LANGUAGE_CODES.size():
		return

	_apply_language(LANGUAGE_CODES[index])


# Description: Applies all UI texts for the provided language code.
# Args: language_code (String) — requested language code
# Returns: void
func _apply_language(language_code: String) -> void:
	if not UI_TEXTS.has(language_code):
		language_code = "en"

	_current_language = language_code
	var texts: Dictionary = UI_TEXTS[language_code]

	_set_text("Language_text", "text", texts["language_label"])
	_set_text("Button", "text", texts["render_button"])
	_set_text("RenderWidth_text", "text", texts["render_width"])
	_set_text("RenderHeigth_text", "text", texts["render_height"])
	_set_text("NFrames_text", "text", texts["n_frames"])
	_set_text("NViews_text", "text", texts["n_views"])
	_set_text("ImageFormat_text", "text", texts["image_format"])
	_set_text("AtlasModeCheck", "text", texts["atlas_mode"])
	_set_text("ImportButton", "text", texts["import_button"])
	_set_text("AtlasErrorDialog", "title", texts["atlas_error_title"])
	_set_text("Scale", "text", texts["scale_model"])
	_set_text("LigthRotaton_text", "text", texts["light_rotation"])
	_set_text("Ligthintensity_text", "text", texts["light_intensity"])
	_set_text("LigthColor_text", "text", texts["light_color"])
	_set_text("FilePrefixInput", "placeholder_text", texts["save_name"])
	_set_text("XPosition_text", "text", texts["x_position"])
	_set_text("YPosition_text", "text", texts["y_position"])
	_set_text("ZPosition_text", "text", texts["z_position"])
	_set_text("ModelRotaton_text", "text", texts["model_rotation"])
	_set_text("FileDialog", "title", texts["file_dialog_title"])
	_set_text("FileDialog", "ok_button_text", texts["file_dialog_ok"])
	_translate_format_options()

	if _language_option != null:
		var selected_index := LANGUAGE_CODES.find(language_code)
		if selected_index < 0:
			selected_index = 0
		_language_option.set_block_signals(true)
		_language_option.select(selected_index)
		_language_option.set_block_signals(false)


# Description: Updates image format option labels.
# Args: none
# Returns: void
func _translate_format_options() -> void:
	if _format_option == null or _format_option.item_count < 5:
		return

	_format_option.set_item_text(0, "PNG")
	_format_option.set_item_text(1, "JPG")
	_format_option.set_item_text(2, "WEBP")
	_format_option.set_item_text(3, "XPM")
	_format_option.set_item_text(4, "XPM_ARGB")


# Description: Sets a property on a UI node when that node exists.
# Args: node_name (String) — target node name under control root
#       property_name (String) — property to modify
#       value (Variant) — value to assign
# Returns: void
func _set_text(node_name: String, property_name: String, value) -> void:
	if _control == null:
		return

	var node := _control.get_node_or_null(node_name)
	if node == null:
		return

	node.set(property_name, value)
