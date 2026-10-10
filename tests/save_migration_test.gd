extends SceneTree
## Production state and file I/O only. All writes use a unique isolated directory.
const Expedition = preload("res://scripts/progression/expedition.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const Items = preload("res://data/items/item_catalog.gd")
var failures: Array[String] = []
var checks := 0
var directory := ""
var current_case := "startup"

func _initialize() -> void:
	directory = "user://automated-tests/migration-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(current_case + ": " + message)
		printerr("SAVE_MIGRATION_FAIL ", current_case, ": ", message)

func section(name: String) -> void:
	current_case = name
	print("MIGRATION_CASE ", name)

func store_for(name: String):
	var store = SaveStore.new()
	store.directory = directory.path_join(name)
	return store

func schema1(nav := "repaired", upgraded := true) -> Dictionary:
	return {"schema_version": 1, "nav": nav, "stored_metal": 1000, "tank_upgraded": upgraded, "buoys": [[12.0, -10.0, -20.0], [-8.0, -30.0, -100.0], [18.0, -40.0, -140.0]]}

func raw_fixture(store, data: Dictionary) -> void:
	# Deliberate fixture creation bypasses the checked production checkpoint API.
	check(store.write_json("checkpoint", data), "isolated raw checkpoint fixture is writable")

func read_bytes(store, name := "checkpoint") -> PackedByteArray:
	return FileAccess.get_file_as_bytes(store.path(name))

func run() -> void:
	migration_keeps_old_state()
	migration_failure_and_retry()
	future_version_protection()
	runtime_and_relay()
	new_resource_and_recipe_limits()
	schema2_validation()
	if failures.is_empty():
		print("SAVE_MIGRATION_OK checks=%d directory=%s" % [checks, directory])
		quit(0)
	else:
		printerr("SAVE_MIGRATION_FAIL failures=%d checks=%d" % [failures.size(), checks])
		quit(1)

func migration_keeps_old_state() -> void:
	section("schema1 incomplete and complete / independent records / first backup")
	for entry in [["wreck", false], ["stored", false], ["repaired", true]]:
		var store = store_for("migrate-" + entry[0])
		var old := schema1(entry[0], entry[1])
		old.stored_metal = Expedition.MAX_STORED
		raw_fixture(store, old)
		store.write_json("observations", {"opabinia": ["identified", "feeding"], "hogara": ["identified"]})
		store.write_json("settings", {"fov": 93.0, "master": 0.25, "invert_y": true})
		var old_bytes := read_bytes(store)
		var observations := read_bytes(store, "observations")
		var settings := read_bytes(store, "settings")
		var loaded: Dictionary = store.load_checkpoint()
		check(loaded.get("schema_version") == 2 and store.loaded_schema_version == 1 and store.migration_pending, "load distinguishes migrated memory from original on-disk schema")
		check(read_bytes(store) == old_bytes and not FileAccess.file_exists(store.path(SaveStore.SCHEMA1_BACKUP)), "loading neither rewrites nor backs up the original file")
		var state = Expedition.new()
		state.restore(loaded)
		check(state.nav == old.nav and state.stored_metal == old.stored_metal and state.buoys == old.buoys and state.tank_level == (1 if old.tank_upgraded else 0), "old navigation, million metal, tank stage and all buoys survive")
		check(state.parts.values().count("world") == 2 and not state.stabilized and not state.cutter_upgraded and state.stored_fiber == 0 and state.stored_shell == 0, "only new M2 fields start empty")
		check(store.save_checkpoint(state.checkpoint()), "first new checkpoint can commit migration")
		check(read_bytes(store, SaveStore.SCHEMA1_BACKUP) == old_bytes and store.read_json("checkpoint").schema_version == 2, "migration backup preserves exact original bytes before schema2 replacement")
		state.stored_metal -= 1
		check(store.save_checkpoint(state.checkpoint()) and read_bytes(store, SaveStore.SCHEMA1_BACKUP) == old_bytes and not store.migration_pending, "subsequent saves do not overwrite the one original backup")
		check(read_bytes(store, "observations") == observations and read_bytes(store, "settings") == settings and store.load_settings().invert_y and store.load_observations().has("hogara"), "migration leaves settings and observations byte-for-byte independent")

func migration_failure_and_retry() -> void:
	section("deterministic backup/write failures preserve old bytes and retry")
	var store = store_for("failure")
	raw_fixture(store, schema1())
	var original := read_bytes(store)
	var candidate: Dictionary = store.load_checkpoint()
	candidate.stored_fiber = 2
	# A directory cannot be opened as a file even when this test runs as root.
	var backup_blocker: String = store.path(SaveStore.SCHEMA1_BACKUP) + ".tmp"
	check(DirAccess.make_dir_recursive_absolute(backup_blocker) == OK, "backup failure is injected in this run's directory")
	check(not store.save_checkpoint(candidate) and store.migration_pending and not store.last_error.is_empty(), "failed backup cannot report successful migration")
	check(read_bytes(store) == original and not FileAccess.file_exists(store.path(SaveStore.SCHEMA1_BACKUP)), "failed backup leaves the original complete checkpoint untouched")
	check(DirAccess.remove_absolute(backup_blocker) == OK, "backup failure can be removed for retry")
	var write_blocker: String = store.path("checkpoint") + ".tmp"
	check(DirAccess.make_dir_recursive_absolute(write_blocker) == OK, "checkpoint write failure is injected after the backup stage")
	check(not store.save_checkpoint(candidate) and read_bytes(store) == original and read_bytes(store, SaveStore.SCHEMA1_BACKUP) == original, "failed migration write preserves both original and exact backup")
	check(store.load_checkpoint().get("stored_fiber") == 0 and store.migration_pending, "failed candidate never becomes loaded progress")
	check(DirAccess.remove_absolute(write_blocker) == OK and store.save_checkpoint(candidate), "same pending migration succeeds after storage recovers")
	check(store.load_checkpoint().get("stored_fiber") == 2 and not store.migration_pending and read_bytes(store, SaveStore.SCHEMA1_BACKUP) == original, "successful retry commits once and keeps the first backup")
	var conflict = store_for("backup-conflict")
	raw_fixture(conflict, schema1())
	conflict.write_json(SaveStore.SCHEMA1_BACKUP, schema1("wreck", false))
	var conflict_bytes := read_bytes(conflict)
	var old_backup := read_bytes(conflict, SaveStore.SCHEMA1_BACKUP)
	check(not conflict.save_checkpoint(conflict.load_checkpoint()) and read_bytes(conflict) == conflict_bytes and read_bytes(conflict, SaveStore.SCHEMA1_BACKUP) == old_backup, "a different existing backup is never silently overwritten")

func future_version_protection() -> void:
	section("future schema stays intact even through explicit new-game save")
	var store = store_for("future")
	var future := {"schema_version": 3, "future_field": "keep exactly"}
	raw_fixture(store, future)
	var original := read_bytes(store)
	check(store.load_checkpoint().is_empty() and not store.last_error.is_empty(), "unknown future schema is rejected clearly")
	check(not store.save_checkpoint(Expedition.new().checkpoint()) and read_bytes(store) == original, "fresh new-game candidate cannot overwrite a future checkpoint")
	check(not FileAccess.file_exists(store.path(SaveStore.SCHEMA1_BACKUP)), "unknown schema is not mislabeled as an M1 backup")

func runtime_and_relay() -> void:
	section("full live clone versus checkpoint / relay is not storage or resurrection")
	var state = Expedition.new()
	state.nav = "repaired"
	state.parts.damping_frame = "stored"
	state.collect_part("phase_regulator")
	state.collect_resource("metal", 2)
	state.collect_resource("repair_fiber", 3)
	state.collect_resource("shell_plate", 4)
	state.oxygen = 0
	state.suit = 27
	state.anoxia = 3.5
	state.bait = 0
	state.pulse = 0
	state.warned_35 = true
	state.warned_15 = true
	state.invulnerability = 0.7
	state.buoys = [[18.0, -45.0, -130.0]]
	var snapshot: Dictionary = state.checkpoint()
	var candidate = state.clone_runtime()
	check(candidate.parts.phase_regulator == "carried" and candidate.carried_fiber == 3 and candidate.carried_shell == 4 and candidate.anoxia == 3.5 and candidate.bait == 0 and candidate.invulnerability == state.invulnerability, "transaction clone retains live cargo, oxygen grace and consumables")
	candidate.parts.damping_frame = "world"
	candidate.buoys[0][0] = 24.0
	check(state.parts.damping_frame == "stored" and state.buoys[0][0] == 18, "candidate dictionaries and nested buoy arrays do not alias live state")
	var retry = Expedition.new()
	retry.restore(snapshot)
	check(retry.parts.damping_frame == "stored" and retry.parts.phase_regulator == "world" and retry.carried_metal == 0 and retry.carried_fiber == 0 and retry.carried_shell == 0, "checkpoint keeps only banked parts and drops every carried resource")
	check(state.relay_refill() and state.oxygen == state.capacity() and state.suit == 100 and state.anoxia == 0 and not state.warned_35 and not state.warned_15, "relay clears hypoxia and warning thresholds while restoring oxygen and suit")
	check(state.checkpoint() == snapshot and state.parts.phase_regulator == "carried" and state.carried_fiber == 3 and state.bait == 0 and state.pulse == 0 and state.invulnerability == 0.7, "relay cannot bank cargo, refill tools, or replace the pod checkpoint")
	state.dead = true
	state.suit = 0
	state.oxygen = 0
	check(not state.relay_refill() and state.dead and state.suit == 0 and state.oxygen == 0, "relay cannot resurrect a dead expedition")

func new_resource_and_recipe_limits() -> void:
	section("shared collection limits / atomic deposit / optional upgrade prerequisites")
	var state = Expedition.new()
	for id in Items.RESOURCE_IDS:
		var limit: int = Items.RESOURCES[id].carried_limit
		check(state.collect_resource(id, limit) and not state.collect_resource(id) and state.carried_amount(id) == limit, "material-specific carry limit is enforced: " + id)
	check(state.collect_part("damping_frame") and state.collect_part("phase_regulator") and not state.collect_part("damping_frame"), "both unique parts fit with every ordinary inventory full")
	state.stored_fiber = Items.MAX_STORED - 1
	check(not state.deposit() and state.carried_metal == 12 and state.carried_fiber == 8 and state.parts.phase_regulator == "carried", "overflow of one material cannot partially consume or bank the other cargo")
	state.stored_fiber = Items.MAX_STORED - 8
	check(state.deposit() and state.stored_fiber == Items.MAX_STORED and state.parts.values().count("stored") == 2, "exact-cap deposit banks every resource and both independent parts together")
	check(not state.can_stabilize() and not state.can_upgrade("tank_ii") and not state.can_upgrade("cutter"), "M2 modifications require restored navigation")
	state.nav = "repaired"
	check(not state.upgrade("tank_ii") and state.upgrade_tank() and state.tank_upgraded and state.tank_level == 1, "tank II requires preserved M1 tank I")
	check(state.upgrade("tank_ii") and state.capacity() == 780 and not state.upgrade("tank_ii"), "tank II installs once with the shared recipe")
	check(state.upgrade("cutter") and state.cutter_seconds() == 0.6 and not state.upgrade("cutter"), "cutter improvement installs once and shortens the actual cut duration")
	check(state.stabilize() and state.parts.values().count("installed") == 2 and not state.stabilize(), "stabilization installs both parts once without another resource recipe")
	check("装置安定化編 完了" in state.objective(), "completion names the implemented chapter, not final return")

func schema2_validation() -> void:
	section("schema2 combinations / invalid materials / six shared-world buoys")
	var store = store_for("validation")
	var state = Expedition.new()
	state.nav = "repaired"
	state.stored_fiber = Expedition.MAX_STORED
	state.stored_shell = Expedition.MAX_STORED
	state.buoys = [[0, -3, -7], [18, -35, -120], [0, -75, -205], [15, -110, -280], [0, -160, -350], [20, -210, -410]]
	check(store.save_checkpoint(state.checkpoint()) and store.load_checkpoint().get("buoys", []).size() == 6, "all six buoys including deep new-sea positions round trip")
	var good: Dictionary = state.checkpoint()
	var good_bytes := read_bytes(store)
	var invalid: Array[Dictionary] = []
	for field in ["stored_metal", "stored_fiber", "stored_shell"]:
		for amount in [-1, 0.5, INF, NAN, Expedition.MAX_STORED + 1]:
			var data := good.duplicate(true)
			data[field] = amount
			invalid.append(data)
	for part_state in ["carried", "unknown"]:
		var data := good.duplicate(true)
		data.parts.damping_frame = part_state
		invalid.append(data)
	var bad := good.duplicate(true)
	bad.parts["unknown_part"] = "world"
	invalid.append(bad)
	bad = good.duplicate(true)
	bad.parts.erase("phase_regulator")
	invalid.append(bad)
	bad = good.duplicate(true)
	bad.stabilized = true
	invalid.append(bad)
	bad = good.duplicate(true)
	bad.parts.damping_frame = "installed"
	invalid.append(bad)
	bad = good.duplicate(true)
	bad.nav = "stored"
	bad.cutter_upgraded = true
	invalid.append(bad)
	bad = good.duplicate(true)
	bad.nav = "wreck"
	bad.tank_level = 2
	invalid.append(bad)
	for tank in [-1, 1.5, 3]:
		bad = good.duplicate(true)
		bad.tank_level = tank
		invalid.append(bad)
	bad = good.duplicate(true)
	bad.tracked_part = "unknown_part"
	invalid.append(bad)
	bad = good.duplicate(true)
	bad.buoys.append([0, -20, -50])
	invalid.append(bad)
	for point in [[0, -261, -300], [151, -70, -210], [0, -50, -461], [0, INF, 0], [0, "invalid", 0]]:
		bad = good.duplicate(true)
		bad.buoys = [point]
		invalid.append(bad)
	var all_rejected := true
	var all_preserved := true
	for data in invalid:
		all_rejected = not store.save_checkpoint(data) and not store.last_error.is_empty() and all_rejected
		all_preserved = read_bytes(store) == good_bytes and all_preserved
	check(all_rejected and all_preserved, "invalid IDs, carried checkpoints, impossible progress, bad numbers and out-of-world buoys all preserve the good file")
	# Loading validates too; direct fixture I/O cannot bypass this boundary.
	bad = good.duplicate(true)
	bad.parts.phase_regulator = "carried"
	raw_fixture(store, bad)
	check(store.load_checkpoint().is_empty(), "malformed existing schema2 cannot become runtime progress")
	var old := schema1()
	old.buoys = [[499, 0, 0]]
	raw_fixture(store, old)
	var old_bytes := read_bytes(store)
	check(store.load_checkpoint().is_empty() and read_bytes(store) == old_bytes, "out-of-world legacy buoy yields an explicit error without deleting or clamping it")
