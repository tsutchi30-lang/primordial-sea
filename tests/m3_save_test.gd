extends SceneTree
const State = preload("res://scripts/progression/expedition.gd")
const Store = preload("res://scripts/save/save_store.gd")
var checks := 0
var failures: Array[String] = []
var directory := ""
func _initialize() -> void:
	directory = "user://automated-tests/m3-save-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("M3_SAVE_FAIL ",message)
func store_at(folder: String):
	var store = Store.new()
	store.directory = directory.path_join(folder)
	return store
func bytes(store) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(store.path("checkpoint"))
func run() -> void:
	for complete in [false,true]:
		var old = State.new()
		old.nav = "repaired"
		old.tank_level = 2
		old.cutter_upgraded = true
		old.stored_metal = 1000000
		old.stored_fiber = 700
		old.stored_shell = 999
		old.tracked_part = "phase_regulator"
		old.buoys = [[0,-2,-5],[18,-35,-120],[0,-70,-205],[15,-110,-280],[0,-160,-350],[20,-210,-410]]
		old.parts = {"damping_frame":"stored","phase_regulator":"stored"}
		if complete: old.stabilize()
		var raw: Dictionary = old.checkpoint()
		raw.schema_version = 2
		raw.erase("return_core")
		raw.erase("game_completed")
		var store = store_at("schema2-%s" % complete)
		check(store.write_json("checkpoint",raw),"write isolated schema2 fixture")
		var original := bytes(store)
		var migrated: Dictionary = store.load_checkpoint()
		check(store.loaded_schema_version == 2 and store.migration_pending and bytes(store) == original,"schema2 load is read-only")
		check(migrated.get("schema_version") == 3 and migrated.get("return_core") == "world" and migrated.get("game_completed") == false,"M2 complete never guesses final completion")
		for field in raw:
			if field != "schema_version": check(migrated.get(field) == JSON.parse_string(JSON.stringify(raw))[field],"preserves schema2 field " + field)
		var blocker: String = store.path(Store.SCHEMA2_BACKUP)+".tmp"
		DirAccess.make_dir_recursive_absolute(blocker)
		check(not store.save_checkpoint(migrated) and bytes(store) == original,"schema2 backup failure preserves original")
		DirAccess.remove_absolute(blocker)
		blocker = store.path("checkpoint")+".tmp"
		DirAccess.make_dir_recursive_absolute(blocker)
		check(not store.save_checkpoint(migrated) and bytes(store) == original,"migration write failure preserves original")
		check(FileAccess.get_file_as_bytes(store.path(Store.SCHEMA2_BACKUP)) == original,"schema2 backup is exact bytes")
		DirAccess.remove_absolute(blocker)
		check(store.save_checkpoint(migrated) and not store.migration_pending,"retry commits schema3 once")
		check(store.write_json("checkpoint",raw),"second isolated old checkpoint")
		store.write_json(Store.SCHEMA2_BACKUP,{"different":"older backup"})
		var prior := FileAccess.get_file_as_bytes(store.path(Store.SCHEMA2_BACKUP))
		check(store.save_checkpoint(store.load_checkpoint()),"conflicting backup uses a different name")
		check(FileAccess.get_file_as_bytes(store.path(Store.SCHEMA2_BACKUP)) == prior,"existing schema2 backup stays unchanged")
		var files := DirAccess.get_files_at(store.directory)
		var variants := 0
		for file in files:
			if file.begins_with("checkpoint.schema2.backup.") and FileAccess.get_file_as_bytes(store.directory.path_join(file)) == original: variants += 1
		check(variants == 1,"one distinct exact original is retained")
	var state = State.new()
	check(state.collect_core() and state.return_core == "carried" and state.parts.size() == 2,"core is a separate early collectible")
	check(state.clone_runtime().return_core == "carried" and state.checkpoint().return_core == "world","only checkpoint normalization drops carried core")
	check(state.deposit() and state.return_core == "stored" and not state.return_status().allowed,"early deposit keeps old prerequisites")
	state.nav = "stored"
	state.stored_metal = 2
	state.parts = {"damping_frame":"stored","phase_regulator":"stored"}
	check(state.repair() and state.stabilize() and state.return_core == "stored","M1 and M2 preserve early core")
	check(state.complete_return() and state.game_completed and state.return_core == "installed" and not state.complete_return(),"completion consumes core exactly once")
	var good: Dictionary = state.checkpoint()
	var store = store_at("validation")
	check(store.save_checkpoint(good),"valid completion can save")
	var original := bytes(store)
	var invalid: Array[Dictionary] = []
	for key in ["return_core","game_completed"]:
		var bad := good.duplicate(true)
		bad.erase(key)
		invalid.append(bad)
	for core in ["world","stored","carried","unknown",1,true,null]:
		var bad := good.duplicate(true)
		bad.return_core = core
		invalid.append(bad)
	for completed in [false,1,"true",null]:
		var bad := good.duplicate(true)
		bad.game_completed = completed
		invalid.append(bad)
	var broken := good.duplicate(true)
	broken.stabilized = false
	broken.parts = {"damping_frame":"stored","phase_regulator":"stored"}
	invalid.append(broken)
	broken = good.duplicate(true)
	broken.nav = "stored"
	invalid.append(broken)
	for bad in invalid:
		check(not store.save_checkpoint(bad) and bytes(store) == original,"invalid schema3 cannot replace valid completion")
	check(store.load_checkpoint().game_completed,"valid completion still reloads")
	for core in ["world","stored"]:
		var early = State.new()
		early.return_core = core
		check(store_at("early-"+core).save_checkpoint(early.checkpoint()),"early core state allowed before M1 and M2")
	var future = store_at("future")
	future.write_json("checkpoint",{"schema_version":4,"keep":"opaque"})
	var future_bytes := bytes(future)
	check(future.load_checkpoint().is_empty() and not future.save_checkpoint(good) and bytes(future) == future_bytes,"future schema4 remains untouched")
	print("M3_SAVE_%s checks=%d saves=%s" % ["OK" if failures.is_empty() else "FAILED",checks,directory])
	quit(0 if failures.is_empty() else 1)
