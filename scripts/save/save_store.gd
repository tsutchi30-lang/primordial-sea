extends RefCounted

const Expedition = preload("res://scripts/progression/expedition.gd")
const Items = preload("res://data/items/item_catalog.gd")
const WorldMap = preload("res://data/biomes/world_map.gd")
const SCHEMA_VERSION := 3
const SCHEMA1_BACKUP := "checkpoint.schema1.backup"
const SCHEMA2_BACKUP := "checkpoint.schema2.backup"
var directory := "user://"
var last_error := ""
var loaded_schema_version := 0
var migration_pending := false
var _read_io_failed := false
const DEFAULT_SETTINGS = {"sensitivity": 0.0025, "invert_y": false, "fov": 80.0, "shake": 0.25, "master": 0.75, "bgm": 0.5, "sfx": 0.7, "ui": 0.6, "low_particles": false, "fullscreen": false}

func path(name: String) -> String:
	return directory.path_join(name + ".json")

func exists() -> bool:
	return FileAccess.file_exists(path("checkpoint"))

func write_json(name: String, value: Dictionary) -> bool:
	# Generic independent settings/notebook writer. Production progression must
	# use save_checkpoint so validation, migration and future-version guards run.
	last_error = ""
	return _write_bytes_atomic(path(name), JSON.stringify(value, "\t").to_utf8_buffer())

func _write_bytes_atomic(target: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "保存先を作成できません。空き容量とアクセス権を確認してください。"
		return false
	var temp := target + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file:
		last_error = "保存先へ書き込めません。空き容量とアクセス権を確認してください。"
		return false
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "保存データの書き込みに失敗しました。以前の保存を保持しています。"
		return false
	if FileAccess.get_file_as_bytes(temp) != bytes:
		last_error = "一時保存の検証に失敗しました。以前の保存を保持しています。"
		return false
	if DirAccess.rename_absolute(temp, target) != OK:
		last_error = "保存の置換に失敗しました。以前の保存を保持しています。再度保存してください。"
		return false
	return true

func read_json(name: String) -> Dictionary:
	last_error = ""
	_read_io_failed = false
	if not FileAccess.file_exists(path(name)):
		return {}
	var file := FileAccess.open(path(name), FileAccess.READ)
	if not file or file.get_length() > 1024 * 1024:
		_read_io_failed = true
		last_error = "保存ファイルを読み込めません。元のファイルは変更していません。"
		return {}
	var source := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		_read_io_failed = true
		last_error = "保存ファイルの読み込みに失敗しました。元のファイルは変更していません。"
		return {}
	var parser := JSON.new()
	if parser.parse(source) != OK or not parser.data is Dictionary:
		last_error = "保存ファイルが破損しています。新規開始で作り直せます。"
		return {}
	return parser.data

func load_checkpoint() -> Dictionary:
	loaded_schema_version = 0
	migration_pending = false
	var data := read_json("checkpoint")
	if data.is_empty():
		return {}
	last_error = _checkpoint_error(data)
	if not last_error.is_empty():
		return {}
	loaded_schema_version = int(data.schema_version)
	migration_pending = loaded_schema_version < SCHEMA_VERSION
	# Loading never writes either a checkpoint or its backup.
	return _migrate(data)

func save_checkpoint(data: Dictionary) -> bool:
	last_error = _checkpoint_error(data)
	if not last_error.is_empty():
		return false
	var candidate := _migrate(data)
	last_error = _checkpoint_error(candidate)
	if not last_error.is_empty():
		return false
	if exists():
		var previous := read_json("checkpoint")
		if _read_io_failed:
			return false
		if not previous.is_empty():
			# Even an explicit New Game cannot silently replace a future version.
			if not _supported_schema(previous.get("schema_version")):
				last_error = "未知の保存形式です。この版では上書きしません。対応する版で開いてください。"
				return false
			if previous.schema_version < SCHEMA_VERSION:
				last_error = _checkpoint_error(previous)
				if not last_error.is_empty():
					return false
				migration_pending = true
				if not _backup_original(int(previous.schema_version)):
					return false
	last_error = ""
	if not _write_bytes_atomic(path("checkpoint"), JSON.stringify(candidate, "\t").to_utf8_buffer()):
		return false
	loaded_schema_version = SCHEMA_VERSION
	migration_pending = false
	return true

func _backup_original(schema: int) -> bool:
	var original := FileAccess.get_file_as_bytes(path("checkpoint"))
	if original.is_empty():
		last_error = "移行前の保存を読み取れないため、移行を中止しました。元の保存を保持しています。"
		return false
	var backup := path("checkpoint.schema%d.backup" % schema)
	# Preserve distinct old saves under separate deterministic names. Retrying the
	# same source reuses its exact backup, never overwrites an earlier original.
	if FileAccess.file_exists(backup) and FileAccess.get_file_as_bytes(backup) != original:
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(original)
		backup = path("checkpoint.schema%d.backup.%s" % [schema, digest.finish().hex_encode()])
	if FileAccess.file_exists(backup):
		if FileAccess.get_file_as_bytes(backup) == original:
			return true
		last_error = "退避先の内容が一致しません。元の保存を保持しています。"
		return false
	if not _write_bytes_atomic(backup, original):
		last_error = "旧保存の退避に失敗しました。移行は未確定です。" + last_error
		return false
	if FileAccess.get_file_as_bytes(backup) != original:
		last_error = "退避した旧保存を確認できません。元の保存を保持しています。"
		return false
	return true

func _migrate(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	if result.schema_version == 1:
		result = _migrate_schema1(result)
	if result.schema_version == 2:
		result.schema_version = 3
		result.return_core = "world"
		result.game_completed = false
	return result

func _migrate_schema1(data: Dictionary) -> Dictionary:
	return {"schema_version": 2, "nav": data.nav, "parts": {"damping_frame": "world", "phase_regulator": "world"}, "stabilized": false, "stored_metal": data.stored_metal, "stored_fiber": 0, "stored_shell": 0, "tank_level": 1 if data.tank_upgraded else 0, "cutter_upgraded": false, "tracked_part": "damping_frame", "buoys": data.buoys.duplicate(true)}

func _checkpoint_error(data: Dictionary) -> String:
	var schema = data.get("schema_version")
	if not _supported_schema(schema):
		return "未知の保存形式です。この版では読み込み・上書きしません。"
	if data.get("nav") not in ["wreck", "stored", "repaired"] or not Items.valid_amount(data.get("stored_metal")):
		return "航法状態または金属片の保存データが不正です。元のファイルは変更していません。"
	var maximum_buoys := 3 if schema == 1 else Items.MAX_BUOYS
	if not data.get("buoys") is Array or data.buoys.size() > maximum_buoys:
		return "目印の保存数が不正です。元のファイルは変更していません。"
	for point in data.buoys:
		if not point is Array or point.size() != 3:
			return "目印の保存データが不正です。"
		for coordinate in point:
			if not (coordinate is float or coordinate is int) or not is_finite(coordinate):
				return "目印の保存座標が不正です。"
		if not WorldMap.is_valid_buoy(Vector3(point[0], point[1], point[2])):
			return "目印が対応する海域の範囲外です。元の保存を保持して読み込みを中止しました。"
	if schema == 1:
		return "" if data.get("tank_upgraded") is bool else "旧タンクの保存データが不正です。"
	if not Items.valid_amount(data.get("stored_fiber")) or not Items.valid_amount(data.get("stored_shell")):
		return "新素材の保存データが不正です。"
	if not Items.valid_amount(data.get("tank_level"), 2) or not data.get("cutter_upgraded") is bool or not data.get("stabilized") is bool:
		return "装備または安定化の保存データが不正です。"
	if data.get("tracked_part") not in Items.PART_IDS:
		return "追跡する部品のIDが不明です。"
	if not data.get("parts") is Dictionary or data.parts.size() != Items.PART_IDS.size():
		return "精密部品の保存データが不正です。"
	for id in Items.PART_IDS:
		if data.parts.get(id) not in ["world", "stored", "installed"]:
			return "精密部品のIDまたは所在が不正です。携行中の部品は保存できません。"
		if (data.parts[id] == "installed") != bool(data.stabilized):
			return "安定化と精密部品の組込状態が一致しません。"
	if (data.stabilized or data.tank_level == 2 or data.cutter_upgraded) and data.nav != "repaired":
		return "航法未復旧の状態と装備・安定化の進行が一致しません。"
	if schema == 3:
		if data.get("return_core") not in ["world", "stored", "installed"] or not data.get("game_completed") is bool:
			return "帰還コアまたは帰還記録が不正です。携行中のコアは保存できません。"
		if (data.return_core == "installed") != data.game_completed:
			return "コアの組込状態と帰還達成が一致しません。"
		if data.game_completed and (not data.stabilized or data.nav != "repaired"):
			return "帰還達成に必要な整備が未完了です。"
	return ""

func _supported_schema(value: Variant) -> bool:
	# JSON numbers are floats. Validate the whole numeric value before comparing
	# versions; Array.has uses strict types and would reject a parsed 1.0 or 2.0.
	return Items.valid_amount(value, SCHEMA_VERSION) and value >= 1

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
