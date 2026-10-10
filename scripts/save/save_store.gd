extends RefCounted

var directory := "user://"
var last_error := ""
const DEFAULT_SETTINGS = {"sensitivity": 0.0025, "invert_y": false, "fov": 80.0, "shake": 0.25, "master": 0.75, "bgm": 0.5, "sfx": 0.7, "ui": 0.6, "low_particles": false, "fullscreen": false}

func path(name: String) -> String:
	return directory.path_join(name + ".json")

func exists() -> bool:
	return FileAccess.file_exists(path("checkpoint"))

func write_json(name: String, value: Dictionary) -> bool:
	last_error = ""
	DirAccess.make_dir_recursive_absolute(directory)
	var target := path(name)
	var temp := target + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file:
		last_error = "保存先へ書き込めません。空き容量とアクセス権を確認してください。"
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "保存データの書き込みに失敗しました。以前の保存を保持しています。"
		return false
	# Godot rename performs a same-filesystem replacement; the old file remains
	# intact if writing the temporary file failed.
	var result := DirAccess.rename_absolute(temp, target)
	if result != OK:
		last_error = "保存の置換に失敗しました。ゲームを終了せず再度保存してください。"
		return false
	return true

func read_json(name: String) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path(name)):
		return {}
	var file := FileAccess.open(path(name), FileAccess.READ)
	if not file or file.get_length() > 1024 * 1024:
		last_error = "保存ファイルを読み込めません。新規開始で作り直せます。"
		return {}
	var parser := JSON.new()
	var result := parser.parse(file.get_as_text())
	file.close()
	if result != OK or not parser.data is Dictionary:
		last_error = "保存ファイルが破損しています。新規開始で作り直せます。"
		return {}
	return parser.data

func load_checkpoint() -> Dictionary:
	var data := read_json("checkpoint")
	if data.is_empty():
		return {}
	if data.get("schema_version") != 1 or not data.get("nav") in ["wreck", "stored", "repaired"]:
		last_error = "この保存形式は読み込めません。新規開始を選ぶと上書きできます。"
		return {}
	var metal = data.get("stored_metal")
	if not (metal is float or metal is int) or metal < 0 or metal > 999 or floor(metal) != metal or not data.get("tank_upgraded") is bool or not data.get("buoys") is Array or data.buoys.size() > 3:
		last_error = "保存データの内容が不正です。既存ファイルは変更していません。"
		return {}
	for point in data.buoys:
		if not point is Array or point.size() != 3:
			last_error = "目印の保存データが不正です。"
			return {}
		for coordinate in point:
			if not (coordinate is float or coordinate is int) or not is_finite(coordinate) or absf(coordinate) > 500:
				last_error = "目印の保存座標が不正です。"
				return {}
	return data

func load_settings() -> Dictionary:
	var saved := read_json("settings")
	var result := DEFAULT_SETTINGS.duplicate()
	for key in ["sensitivity", "fov", "shake", "master", "bgm", "sfx", "ui"]:
		var value = saved.get(key)
		if (value is float or value is int) and is_finite(value):
			if key == "sensitivity":
				result[key] = clampf(value, 0.0005, 0.008)
			elif key == "fov":
				result[key] = clampf(value, 60, 105)
			else:
				result[key] = clampf(value, 0, 1)
	for key in ["invert_y", "low_particles", "fullscreen"]:
		if saved.get(key) is bool:
			result[key] = saved[key]
	return result

func load_observations() -> Dictionary:
	var saved := read_json("observations")
	var result := {}
	for species in saved:
		if saved[species] is Array:
			var events: Array = []
			for event in saved[species]:
				if event is String and event.length() < 80:
					events.append(event)
			result[species] = events
	return result
