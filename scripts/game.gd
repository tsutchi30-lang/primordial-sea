extends Node3D

const Expedition = preload("res://scripts/progression/expedition.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const Controls = preload("res://scripts/player/controls.gd")
const Diver = preload("res://scripts/player/diver.gd")
const Interface = preload("res://scripts/ui/interface.gd")
const Pickup = preload("res://scripts/interaction/pickup.gd")
const Soundscape = preload("res://scripts/audio/soundscape.gd")
const M3Controller = preload("res://scripts/progression/m3_controller.gd")
const Query = preload("res://scripts/interaction/interaction_query.gd")
const M2Controller = preload("res://scripts/progression/m2_controller.gd")
const WorldMap = preload("res://data/biomes/world_map.gd")
const Items = preload("res://data/items/item_catalog.gd")
const POD := Vector3(0, 1.6, 0)
const EXIT := Vector3(0, -2, -7)
const ENTRY := Vector3(0, -2, -5)
const NAV_POSITION := Vector3(0, -36, -130)

var state = Expedition.new()
var saves = SaveStore.new()
var settings: Dictionary = {}
var observations: Dictionary = {}
var checkpoint: Dictionary = {}
var player
var world
var ecology
var hud
var sound
var pickups: Array = []
var nav_unit
var buoy_nodes: Array = []
var mode := "title"
var test_mode := false
var selected_tool := 0
var tool_names := ["生物観察器", "採集カッター", "誘餌ポッド", "緊急防御パルス", "目印ブイ"]
var toast_text := ""
var toast_remaining := 0.0
var observe_time := 0.0
var observation_target: Node3D
var use_lock := 0.0
var tutorial_flags: Dictionary = {}
var previous_settings_page := "pause"
var death_reason := ""
var buoy_material: StandardMaterial3D
var shake_time := 0.0
var quitting := false
var pending_checkpoint_action := ""
var checkpoint_error := ""
var m2 = M2Controller.new()
var cut_progress := 0.0
var cut_label := "粘糸"
var toast_priority := 0
var m3 = M3Controller.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	Controls.install()
	settings = saves.load_settings()
	observations = saves.load_observations()
	world = load("res://scripts/world/sea_world.gd").new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = Diver.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.relocate(POD, true)
	player.apply_settings(settings)
	ecology = load("res://scripts/ecology/ecosystem.gd").new()
	ecology.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ecology)
	ecology.setup(player, world)
	ecology.player_hit.connect(_on_hit)
	ecology.hint.connect(func(message): notify(message,5,0))
	if ecology.has_signal("observed_event"):
		ecology.observed_event.connect(_on_observed_event)
	sound = Soundscape.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	sound.apply_settings(settings)
	ecology.footfall.connect(func(at: Vector3, strength: float): sound.play_footfall(at, strength))
	_build_pickups()
	m2.setup(self)
	m3.setup(self)
	ecology.resource_drop.connect(m2.drop_resource)
	ecology.resonance.connect(func(at: Vector3, strength: float): sound.play_resonance(at, strength))
	ecology.defense_rattle.connect(func(at: Vector3): sound.play_resonance(at, 0.35, 1.7))
	ecology.behavior_observed.connect(_on_behavior_observed)
	hud = Interface.new()
	add_child(hud)
	hud.action_requested.connect(_on_action)
	hud.setting_changed.connect(_on_setting)
	apply_settings()
	show_title()

func _build_pickups() -> void:
	for point in [Vector2(-4,-19), Vector2(4,-24), Vector2(10,-34), Vector2(-9,-40), Vector2(13,-47), Vector2(-12,-30)]:
		var node = Pickup.new()
		node.kind = "metal"
		node.title = "金属片"
		node.position = Vector3(point.x, world.floor_height(point.x, point.y) + 0.65, point.y)
		add_child(node)
		pickups.append(node)
	for point in [Vector2(7,-20), Vector2(-6,-31), Vector2(16,-53)]:
		var node = Pickup.new()
		node.kind = "bait"
		node.title = "微生物膜（誘餌を補充）"
		node.position = Vector3(point.x, world.floor_height(point.x, point.y) + 0.65, point.y)
		add_child(node)
		pickups.append(node)
	nav_unit = Pickup.new()
	nav_unit.kind = "nav"
	nav_unit.title = "航法ユニット"
	nav_unit.position = NAV_POSITION
	add_child(nav_unit)
	pickups.append(nav_unit)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if mode == "return":
		if event.is_action_pressed("pause"):
			m3.sequence.finish()
		elif event.is_action_pressed("interact"):
			m3.sequence.set_suspended(not m3.sequence.suspended)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fullscreen"):
		_on_setting("fullscreen", not settings.fullscreen)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if mode == "play":
			if get_tree().paused:
				if hud.page == "settings":
					_on_action("settings_back")
				else:
					resume_game()
			else:
				pause_game()
		elif mode == "title" and hud.page != "title":
			show_title()
		return
	if event.is_action_pressed("journal") and mode == "play":
		get_viewport().set_input_as_handled()
		if get_tree().paused and hud.page == "journal":
			resume_game()
		else:
			pause_game("journal")
		return
	if mode != "play" or get_tree().paused or use_lock > 0:
		return
	if event.is_action_pressed("light"):
		player.toggle_light()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("pulse"):
		use_pulse()
	elif event.is_action_pressed("use_tool") and selected_tool != 0:
		use_tool()
	elif event.is_action_pressed("tool_next"):
		select_tool((selected_tool + 1) % 5)
	elif event.is_action_pressed("tool_previous"):
		select_tool((selected_tool + 4) % 5)
	for i in 5:
		if event.is_action_pressed("tool_%d" % (i + 1)):
			select_tool(i)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		if mode == "play":
			pause_game()
		elif mode == "return":
			m3.sequence.set_suspended(true)
		else:
			player.clear_input()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_request_quit()

func _process(_delta: float) -> void:
	if is_instance_valid(hud):
		hud.update_game(self)

func _physics_process(delta: float) -> void:
	if mode != "play" or get_tree().paused:
		return
	use_lock = maxf(0, use_lock - delta)
	toast_remaining = maxf(0, toast_remaining - delta)
	var reason: String = state.tick(delta, not player.in_pod and not player.breathing_air, player.sprinting)
	if not reason.is_empty():
		die(reason)
		return
	ecology.tick(delta)
	for pickup in pickups:
		pickup.tick(delta)
	_update_observation(delta)
	_update_cutter(delta)
	_check_guidance()
	if state.oxygen <= state.capacity() * 0.35 and not state.warned_35:
		state.warned_35 = true
		notify("酸素 35% — ポッドまでの道を確認してください。水面では消費が止まります。", 7,3)
		sound.play_effect("warning")
	if state.oxygen <= state.capacity() * 0.15 and not state.warned_15:
		state.warned_15 = true
		notify("酸素 15% — 帰投または浮上を。水面ではタンクは充填されません。", 7,3)
		sound.play_effect("warning")
	if shake_time > 0:
		shake_time = maxf(0, shake_time - delta)
		player.camera.h_offset = sin(shake_time * 56) * shake_time * 0.045 * player.camera_shake
	else:
		player.camera.h_offset = 0

func start_new_game() -> void:
	var fresh = Expedition.new()
	if not _save_checkpoint(fresh.checkpoint()):
		show_title(saves.last_error)
		return
	state = fresh
	observations = {}
	tutorial_flags = {}
	saves.write_json("observations", {})
	_begin_at_pod()
	notify("転移事故で調査艇を喪失。まず浅瀬の金属片 2 個と、艇の航法ユニットを回収してください。", 13)

func _begin_at_pod() -> void:
	pending_checkpoint_action = ""
	checkpoint_error = ""
	mode = "play"
	player.relocate(POD, true)
	ecology.reset()
	m2.reset_expedition()
	m3.sync_core(true)
	world.set_stabilized(state.stabilized)
	sound.set_stabilized(state.stabilized)
	_rebuild_buoys()
	resume_game()
	sound.ambience(true, true)

func load_game() -> bool:
	var data: Dictionary = saves.load_checkpoint()
	if data.is_empty():
		show_title(saves.last_error if not saves.last_error.is_empty() else "保存された航海はありません。新しく始められます。")
		return false
	checkpoint = data.duplicate(true)
	state.restore(data)
	observations = saves.load_observations()
	_begin_at_pod()
	notify("帰還達成済み。帰還直前の海で調査を続けます。" if state.game_completed else "ポッドの保存点から再開しました。補給・修復は完了しています。",8,2)
	return true

func _save_checkpoint(candidate: Dictionary = {}) -> bool:
	var data: Dictionary = state.checkpoint() if candidate.is_empty() else candidate
	if saves.save_checkpoint(data):
		checkpoint = data.duplicate(true)
		return true
	notify(saves.last_error, 12,4)
	return false

func depart_pod() -> bool:
	if not player.in_pod or mode != "play":
		return false
	if not pending_checkpoint_action.is_empty() and pending_checkpoint_action != "depart":
		_show_save_failure(pending_checkpoint_action, checkpoint_error)
		return false
	if not _commit_deposit("depart"):
		return false
	player.relocate(EXIT, false)
	resume_game()
	sound.ambience(false, true)
	notify("%s　%s\n%sで観察器を選び、左クリックを押し続けて拡大観察。" % ["WASD 泳ぐ / Space 上昇 / C 下降", "ポッドの光が帰路の目印です。", Controls.label("tool_1")], 11)
	return true

func return_to_pod() -> bool:
	if mode != "play" or player.in_pod or player.global_position.distance_to(ENTRY) > 7.0:
		return false
	# Enter safety and supply breathing/repairs even when storage is unavailable.
	# Cargo remains carried until the complete candidate checkpoint is durable.
	player.relocate(POD, true)
	state.refill()
	sound.ambience(true, true)
	return _finish_return()

func _finish_return() -> bool:
	var cargo: Array[String] = []
	if state.nav == "carried": cargo.append("航法ユニット")
	for id in Items.PART_IDS:
		if state.parts[id] == "carried": cargo.append(Items.item_name(id))
	if state.return_core == "carried": cargo.append("帰還コア")
	if not _commit_deposit("return"):
		return false
	m2.sync_parts()
	m3.sync_core()
	resume_game()
	sound.play_effect("pickup")
	notify(("保管・保存完了：" + "・".join(cargo) if not cargo.is_empty() else "帰投完了。資材を保管し補給しました。") + "\n次：" + state.objective(),10,2)
	return true

func repair_navigation() -> bool:
	if mode != "play" or not player.in_pod:
		return false
	if not pending_checkpoint_action.is_empty() and pending_checkpoint_action != "repair":
		_show_save_failure(pending_checkpoint_action, checkpoint_error)
		return false
	var candidate = state.clone_runtime()
	if not candidate.repair():
		notify("航法ユニット 1 個と、保管済みの金属片 2 個が必要です。")
		return false
	if not _save_checkpoint(candidate.checkpoint()):
		_show_save_failure("repair", saves.last_error)
		return false
	state = candidate
	pending_checkpoint_action = ""
	checkpoint_error = ""
	sound.play_effect("success")
	pause_game("complete")
	return true

func _commit_deposit(action: String) -> bool:
	var candidate = state.clone_runtime()
	if not candidate.deposit():
		_show_save_failure(action, "素材の保管上限は各 %d 個です。携行品は保持しています。" % Expedition.MAX_STORED_METAL)
		return false
	if not _save_checkpoint(candidate.checkpoint()):
		_show_save_failure(action, saves.last_error)
		return false
	state = candidate
	m2.sync_parts()
	m3.sync_core()
	pending_checkpoint_action = ""
	checkpoint_error = ""
	return true

func upgrade_tank() -> bool:
	return upgrade_equipment("tank_i")

func upgrade_equipment(id: String) -> bool:
	if mode != "play" or not player.in_pod or state.dead:
		return false
	var action := "upgrade" if id == "tank_i" else "upgrade:" + id
	if not pending_checkpoint_action.is_empty() and pending_checkpoint_action != action:
		_show_save_failure(pending_checkpoint_action, checkpoint_error)
		return false
	var candidate = state.clone_runtime()
	if not candidate.upgrade(id):
		notify(candidate.upgrade_status(id).reason)
		return false
	if not _save_checkpoint(candidate.checkpoint()):
		_show_save_failure(action, saves.last_error)
		return false
	state = candidate
	pending_checkpoint_action = ""
	checkpoint_error = ""
	_stop_play()
	_show_pod()
	return true

func stabilize_device() -> bool:
	if mode != "play" or not player.in_pod or state.dead:
		return false
	if not pending_checkpoint_action.is_empty() and pending_checkpoint_action != "stabilize":
		_show_save_failure(pending_checkpoint_action, checkpoint_error)
		return false
	var candidate = state.clone_runtime()
	if not candidate.stabilize():
		notify(candidate.stabilization_status().reason)
		return false
	if not _save_checkpoint(candidate.checkpoint()):
		_show_save_failure("stabilize", saves.last_error)
		return false
	state = candidate
	pending_checkpoint_action = ""
	checkpoint_error = ""
	m2.sync_parts()
	m3.sync_core()
	sound.play_effect("success")
	world.set_stabilized(true)
	sound.set_stabilized(true)
	pause_game("stabilized")
	return true

func open_relay() -> bool:
	return m2.open_relay()

func refill_at_relay() -> bool:
	return m2.refill_at_relay()

func _show_save_failure(action: String, message: String) -> void:
	pending_checkpoint_action = action
	checkpoint_error = message
	_stop_play()
	var detail := "ポッド内は安全です。保管は未確定で、携行資材と航法ユニットを保持しています。"
	if action == "repair":
		detail = "航法修理は未確定です。金属片と航法ユニットは消費していません。"
	elif action.begins_with("upgrade"):
		detail = "装備改良は未確定です。素材は消費していません。"
	elif action == "final_return":
		detail = "帰還は未確定です。帰還コアは保管済みのままです。演出は開始していません。"
	elif action == "stabilize":
		detail = "装置安定化は未確定です。保管済みの部品は保持しています。"
	hud.show_panel("save_failed", "保存できませんでした", message + "\n\n" + detail + "\n以前の正常な保存点は保持されています。保存先を確認してから再試行してください。\nタイトルへ戻ると、未保存の進行は失われます。", [["保存を再試行", "retry_save"], ["タイトルへ（前の保存点から再開）", "title"]])

func retry_checkpoint() -> bool:
	match pending_checkpoint_action:
		"return": return _finish_return()
		"depart": return depart_pod()
		"repair": return repair_navigation()
		"upgrade": return upgrade_tank()
		"stabilize": return stabilize_device()
		"final_return": return m3.activate_return()
	if pending_checkpoint_action.begins_with("upgrade:"):
		return upgrade_equipment(pending_checkpoint_action.trim_prefix("upgrade:"))
	return false

func die(reason: String) -> void:
	if mode != "play":
		return
	mode = "dead"
	death_reason = reason
	state.dead = true
	_stop_play()
	sound.ambience(false, false)
	hud.show_panel("dead", "救難信号を受信", reason + "\n持ち帰っていない資材は失われます。未保管の航法ユニットと重要部品は元の場所へ戻ります。\n観察記録は保持されます。", [["最後のポッド保存点から再出発", "retry"], ["タイトルへ", "title"]])

func show_title(message := "") -> void:
	if is_instance_valid(m3.sequence): m3.sequence.restore_scene()
	pending_checkpoint_action = ""
	checkpoint_error = ""
	mode = "title"
	_stop_play()
	sound.ambience(true, false)
	player.relocate(POD, true)
	var intro := "五億年前に似た、もうひとつの海。\n生き物の暮らしを読み、失われた装置を持ち帰り、元の時代へ。\n\n一人称の海洋探索サバイバル — 帰還と、その先の調査"
	if not message.is_empty():
		intro += "\n\n" + message
	hud.show_panel("title", "原初の海", intro, [["新しく始める", "new"], ["続きから（ポッドの保存点）", "continue", not saves.exists()], ["設定", "settings"], ["終了", "quit"]])

func _stop_play() -> void:
	cut_progress = 0.0
	m3.cancel_cut()
	if is_instance_valid(ecology) and is_instance_valid(ecology.plains):
		ecology.plains.cancel_cut()
	player.active = false
	player.clear_input()
	observation_target = null
	observe_time = 0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func pause_game(page := "pause") -> void:
	if mode != "play":
		return
	if not pending_checkpoint_action.is_empty():
		_show_save_failure(pending_checkpoint_action, checkpoint_error)
		return
	_stop_play()
	if page == "journal":
		_show_journal()
	elif page == "pod":
		_show_pod()
	elif page == "complete":
		hud.show_panel("complete", "航法復旧編 完了", "艇の記録が戻り、この海の座標が分かりました。\n白濁の平原と殻の墓場から二つの部品を持ち帰り、装置を安定化しましょう。\n\n白濁の平原の奥にある中継補給点が利用できるようになりました。", [["装置安定化編へ", "resume"], ["整備端末", "pod"], ["調査記録を見る", "journal"]])
	elif page == "stabilized":
		hud.show_panel("stabilized", "装置安定化編 完了", "二つの部品を組み込み、帰還装置の振動が静まりました。\n沈没調査艇の信号を解析。殻の墓場の奥、環状の裂け目へ。\n中継で補給し、艇の固定具をカッターで外して帰還コアを持ち帰りましょう。", [["帰還コアを探す", "resume"], ["調査記録を見る", "journal"], ["タイトルへ", "title"]])
	else:
		hud.show_panel("pause", "潜水を一時停止", "酸素・生物・道具の時間は停止しています。\n水中で終了した場合は最後のポッド保存点から再開します。\n\n" + Controls.help_text(), [["潜水を再開", "resume"], ["図鑑・持ち物", "journal"], ["設定", "settings"], ["タイトルへ（最後の保存点を保持）", "title"]])

func resume_game() -> void:
	if mode != "play":
		return
	if not pending_checkpoint_action.is_empty():
		_show_save_failure(pending_checkpoint_action, checkpoint_error)
		return
	player.clear_input()
	use_lock = 0.25
	hud.hide_panel()
	get_tree().paused = false
	player.active = true
	if not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_pod() -> void:
	m2.show_pod()

func _show_journal() -> void:
	m2.show_journal()

func _on_action(action: String) -> void:
	if action != "quit":
		sound.play_effect("ui")
	match action:
		"new":
			if saves.exists():
				hud.show_panel("confirm_new", "新しい航海を始めますか", "現在のポッド保存点と観察記録を上書きします。設定は保持します。", [["上書きして始める", "confirm_new"], ["戻る", "title"]])
			else:
				start_new_game()
		"confirm_new": start_new_game()
		"continue", "retry": load_game()
		"retry_save": retry_checkpoint()
		"resume": resume_game()
		"title": show_title()
		"depart": depart_pod()
		"repair": repair_navigation()
		"upgrade": upgrade_tank()
		"pod": pause_game("pod")
		"stabilize": stabilize_device()
		"final_return": m3.activate_return()
		"research": m3.continue_research()
		"equipment_menu":
			if player.in_pod and pending_checkpoint_action.is_empty():
				_stop_play()
				m2.show_equipment()
		"relay_refill": refill_at_relay()
		"journal": pause_game("journal")
		"settings":
			previous_settings_page = hud.page
			hud.show_settings(settings)
		"settings_back":
			saves.write_json("settings", settings)
			if mode == "title": show_title()
			else: pause_game(previous_settings_page)
		"quit":
			_request_quit()
		_:
			if action.begins_with("equipment:"):
				upgrade_equipment(action.trim_prefix("equipment:"))
			elif action.begins_with("track:"):
				var part := action.trim_prefix("track:")
				if Items.PARTS.has(part):
					state.tracked_part = part
					if hud.page == "pod": _show_pod()
					else: _show_journal()
			elif action.begins_with("species:"):
				m2.journal_species = action.trim_prefix("species:")
				_show_journal()

func _request_quit() -> void:
	if quitting:
		return
	quitting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.clear_input()
	player.active = false
	sound.stop_all()
	# Give the audio mixer time to release playback resources on every platform.
	await get_tree().create_timer(0.12, true).timeout
	get_tree().quit()

func _on_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	if not saves.write_json("settings", settings):
		notify(saves.last_error, 8)

func apply_settings() -> void:
	player.apply_settings(settings)
	sound.apply_settings(settings)
	if not test_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if world.has_method("set_low_particles"):
		world.set_low_particles(settings.low_particles)
	if ecology.has_method("set_low_particles"):
		ecology.set_low_particles(settings.low_particles)

func notify(message: String, seconds := 5.0, priority := 1) -> void:
	if toast_remaining > 0 and priority < toast_priority: return
	toast_priority = priority
	toast_text = message
	toast_remaining = seconds

func target_score(pickup: Node3D) -> float:
	if not pickup.available: return -1.0
	return Query.score(player.camera,pickup.global_position,4.0,0.80)

func current_target():
	var best = null
	var best_score := -1.0
	for pickup in pickups:
		var score := target_score(pickup)
		if score > best_score:
			best = pickup
			best_score = score
	return best

func visible_to_player(point: Vector3, cosine := 0.8) -> bool:
	var offset: Vector3 = point - player.camera.global_position
	if offset.length() < 0.02:
		return true
	if -player.camera.global_basis.z.dot(offset.normalized()) < cosine:
		return false
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, point, 1 | 8)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func interaction_hint() -> String:
	if player.in_pod:
		return "%s  整備端末 / 海へ出発" % Controls.label("interact")
	if player.global_position.distance_to(ENTRY) < 7:
		return "%s  ポッドへ帰還・保管・補給" % Controls.label("interact")
	if m2.near_relay():
		return m2.relay_hint()
	var target = current_target()
	if target:
		if target.kind == "return_core" and not m3.mount.unlocked:
			return "2 カッターを選択 / 左クリック長押しで固定具を切断" if selected_tool != 1 else "左クリック長押し / 固定具を切断（3 m以内）"
		if Items.RESOURCES.has(target.kind) and not state.can_collect_resource(target.kind):
			return "%s：携行枠または保管数が上限です" % target.title
		return "%s  %sを回収" % [Controls.label("interact"), target.title]
	for buoy in buoy_nodes:
		if player.global_position.distance_to(buoy.global_position) < 2.5:
			return "%s  目印ブイを回収" % Controls.label("interact")
	if selected_tool == 0 and observation_target:
		return "左クリックを押し続けて観察 / 視点を動かすと対象を変更"
	return ""

func interact() -> void:
	if mode != "play" or get_tree().paused:
		return
	if player.in_pod:
		pause_game("pod")
		return
	if player.global_position.distance_to(ENTRY) <= 7.0:
		return_to_pod()
		return
	if m2.near_relay():
		open_relay()
		return
	var target = current_target()
	if target:
		collect_target(target)
		return
	for i in buoy_nodes.size():
		if player.global_position.distance_to(buoy_nodes[i].global_position) < 2.5:
			state.buoys.remove_at(i)
			_rebuild_buoys()
			notify("目印ブイを回収しました。")
			return

func collect_target(target) -> bool:
	if mode != "play" or state.dead or player.in_pod or not target in pickups or not target.available:
		return false
	if target != current_target():
		return false
	match target.kind:
		"return_core":
			if not m3.mount.unlocked or not state.collect_core(): return false
			m3.mount.hide()
			notify("帰還コアを回収。携行中・ポッド未保管です。中継で補給して持ち帰りましょう。",10,2)
		"damping_frame", "phase_regulator":
			if not state.collect_part(target.kind): return false
			notify("%sを回収。救命ポッドへ持ち帰って保管してください。中継点では保管されません。" % target.title, 8,2)
		"repair_fiber", "shell_plate":
			if not state.collect_resource(target.kind):
				notify("%sの携行枠または保管上限です。この素材は残しておきます。" % target.title)
				return false
			notify("%sを回収。ポッドへ帰ると保管されます。" % target.title)
		"nav":
			if not state.collect_nav(): return false
			notify("航法ユニットを回収。ポッドへ持ち帰って保管してください。", 8,2)
		"metal":
			if state.carried_metal >= Expedition.CARRIED_METAL_LIMIT:
				notify("一般素材の携行枠がいっぱいです。ポッドへ保管しましょう。")
				return false
			if state.stored_metal + state.carried_metal >= Expedition.MAX_STORED_METAL:
				notify("金属片の保管上限は %d 個です。修理や整備で使うと回収できます。この素材は残しておきます。" % Expedition.MAX_STORED_METAL, 8)
				return false
			state.carried_metal += 1
			notify("金属片を回収（携行 %d）。ポッドに戻ると保管されます。" % state.carried_metal)
		"bait":
			if state.bait >= 6:
				notify("誘餌は最大 6 個です。")
				return false
			state.bait = mini(6, state.bait + 2)
			notify("微生物膜から誘餌を補充しました。")
		_: return false
	target.take()
	sound.play_effect("pickup")
	return true

func select_tool(index: int) -> void:
	m3.cancel_cut()
	ecology.plains.cancel_cut()
	cut_progress = 0.0
	selected_tool = clampi(index, 0, 4)
	observe_time = 0
	observation_target = null
	player.zoom_fov = player.base_fov

func use_tool() -> void:
	if mode != "play" or get_tree().paused or use_lock > 0:
		return
	match selected_tool:
		1:
			var target = current_target()
			if target and target.kind != "return_core" and not Items.PARTS.has(target.kind):
				collect_target(target)
		2:
			if player.in_pod:
				notify("誘餌は海中で使います。")
			elif state.bait <= 0:
				notify("誘餌がありません。浅瀬の微生物膜かポッドで補給できます。")
			else:
				var destination: Vector3 = player.position - player.camera.global_basis.z * 6
				var query := PhysicsRayQueryParameters3D.create(player.position, destination, 1 | 8)
				var hit := get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty(): destination = hit.position + hit.normal * 0.6
				if ecology.use_bait(destination):
					state.bait -= 1
					use_lock = 0.5
					notify("誘餌を放出。45 秒間、近くの群れの動きを観察できます。")
				else:
					notify("誘餌はまだ持続中です。群れの動きを観察してください。")
		3: use_pulse()
		4:
			if player.in_pod:
				notify("目印ブイは海中で設置します。")
			elif state.buoys.size() >= Expedition.MAX_BUOYS:
				notify("目印は 6 個まで。近づいて E で回収できます。")
			else:
				var at: Vector3 = player.position
				if not WorldMap.is_valid_buoy(at):
					notify("この外縁にはブイを固定できません。海域内へ戻ってください。")
					return
				state.buoys.append([at.x, at.y, at.z])
				_rebuild_buoys()
				use_lock = 0.5
				notify("目印を設置。ポッドへの帰還時に位置も保存されます。")

func use_pulse() -> bool:
	if mode != "play" or get_tree().paused or use_lock > 0 or player.in_pod:
		return false
	if state.pulse <= 0:
		notify("パルスは空です。ポッドで再充填できます。")
		return false
	state.pulse -= 1
	use_lock = 0.5
	var count: int = ecology.pulse(player.global_position)
	sound.play_effect("pulse")
	notify("パルス命中。今のうちに距離を取りましょう。" if count > 0 else "パルス放出。4 m 以内に反応する生物はいませんでした。")
	return true

func _update_observation(delta: float) -> void:
	if selected_tool != 0 or player.in_pod:
		return
	var target: Node3D = ecology.get_observation_target(player.camera)
	if target != observation_target:
		observe_time = 0
		observation_target = target
	if not Input.is_action_pressed("use_tool") or use_lock > 0:
		observe_time = 0
		player.zoom_fov = player.base_fov
		return
	# Magnification is available even before a target is found; no automatic
	# detection of a hidden creature behind terrain.
	player.zoom_fov = 16.0
	if not target:
		return
	var id: String = target.species_id
	player.zoom_fov = 38.0 if id in ["hogara", "windoweater", "kangaku"] else 12.0
	observe_time += delta
	if observe_time >= 2.3:
		record_observation(id, "identified")
		if not target.behavior_event.is_empty():
			record_observation(id, target.behavior_event)

func record_observation(species_id: String, event: String) -> void:
	var catalog: Dictionary = ecology.get_species_data()
	if not catalog.has(species_id):
		return
	if not observations.has(species_id):
		observations[species_id] = []
	if event in observations[species_id]:
		return
	observations[species_id].append(event)
	saves.write_json("observations", observations)
	notify("観察記録を追加：%s（Tab で確認）" % catalog[species_id].get("name", species_id), 4)
	sound.play_effect("pickup")

func _on_observed_event(species_id: String, event: String) -> void:
	if mode != "play" or get_tree().paused:
		return
	if is_instance_valid(sound):
		if species_id == "windoweater" and event in ["windup", "feed"]:
			for predator in ecology.predators:
				if player.global_position.distance_to(predator.global_position) < 18:
					sound.play_effect("membrane")
		elif species_id == "hogara" and event == "rest_warning" and player.global_position.distance_to(ecology.hogara.global_position) < 15:
			sound.play_effect("hogara")
	if not observations.has(species_id):
		return
	var target: Node3D = ecology.get_observation_target(player.camera)
	if target and target.species_id == species_id and target.behavior_event == event:
		record_observation(species_id, event)

func _on_hit(amount: float) -> void:
	if mode != "play" or player.in_pod or not state.damage(amount):
		return
	shake_time = 0.45
	sound.play_effect("membrane")
	notify("スーツ損傷。横や上下へ泳いで、岩陰へ離脱してください。", 5,3)
	if state.dead:
		die("スーツが損傷しました。予兆が見えたら横へ避け、岩陰へ離脱しましょう。")

func _rebuild_buoys() -> void:
	for node in buoy_nodes:
		node.queue_free()
	buoy_nodes.clear()
	if not buoy_material:
		buoy_material = StandardMaterial3D.new()
		buoy_material.albedo_color = Color("ffd18b")
		buoy_material.emission_enabled = true
		buoy_material.emission = Color("ffd18b")
	for xyz in state.buoys:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		mesh.mesh = sphere
		mesh.material_override = buoy_material
		mesh.position = Vector3(xyz[0], xyz[1], xyz[2])
		add_child(mesh)
		buoy_nodes.append(mesh)

func _check_guidance() -> void:
	if player.in_pod or (toast_remaining > 0 and toast_priority >= 2):
		return
	var z: float = player.position.z
	if z < -15 and z >= -53 and not tutorial_flags.has("shallow"):
		tutorial_flags.shallow = true
		notify("浅瀬の発見：白い底の金属片は E で回収。小さな生物は観察器で拡大できます。", 10,0)
	elif z < -53 and z >= -69 and not tutorial_flags.has("hogara"):
		tutorial_flags.hogara = true
		notify("大きな帆の影が動いています。距離を保ち、腹側へ集まる小生物を観察しましょう。", 9,0)
	elif z < -69 and z >= -86 and not tutorial_flags.has("silt"):
		tutorial_flags.silt = true
		notify("砂底の螺旋状の生物は、大きな動きに反応します。3 m 以内で Shift 加速を試せます。", 10,0)
	elif z < -86 and z >= -178 and not tutorial_flags.has("routes"):
		tutorial_flags.routes = true
		notify("艇の信号は奥へ。東側の岩陰にも回り道があります。ライトは F、緊急パルスは Q。", 10,0)
	elif z < -178 and z >= -300 and not tutorial_flags.has("plain"):
		tutorial_flags.plain = true
		notify("白濁の平原。" + ("中継は航法修理と保存後に利用可能です。" if state.nav != "repaired" else "中継で補給できます。岩の間の糸と、刃葉虫の動きを観察しましょう。"),10,0)
	elif z < -300 and z >= -430 and not tutorial_flags.has("graveyard"):
		tutorial_flags.graveyard = true
		notify("殻の墓場。壺の膜が音の予兆です。大きな空殻には前の入口と、東の破れ目・奥の出口があります。", 11,0)
	elif z < -430 and not tutorial_flags.has("rift"):
		tutorial_flags.rift = true
		notify("環状の裂け目。岩柱の下に艇の灯りが見えます。棚で一度、周囲を観察できます。",10,0)
	if WorldMap.is_near_boundary(player.position):
		if toast_remaining <= 0:
			notify("外洋から強い流れ。岩の盆地へ戻りましょう。", 4)

func _update_cutter(delta: float) -> void:
	cut_progress = 0.0
	if selected_tool == 1 and not player.in_pod and Input.is_action_pressed("use_tool") and use_lock <= 0.0:
		if m3.cut_available():
			ecology.plains.cancel_cut()
			m3.cut(delta)
			return
		m3.cancel_cut()
		cut_label = "粘糸"
		var result: Dictionary = ecology.plains.cut_target(player.camera, delta, state.cutter_seconds())
		cut_progress = float(result.get("progress", 0.0))
		if result.get("completed", false):
			sound.play_effect("pickup")
	else:
		ecology.plains.cancel_cut()
		m3.cancel_cut()

func _on_behavior_observed(creature: Node3D, event: String) -> void:
	if mode != "play" or get_tree().paused or not observations.has(creature.species_id):
		return
	if ecology.get_observation_target(player.camera) == creature:
		record_observation(creature.species_id, event)
