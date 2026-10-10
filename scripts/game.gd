extends Node3D

const Expedition = preload("res://scripts/progression/expedition.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const Controls = preload("res://scripts/player/controls.gd")
const Diver = preload("res://scripts/player/diver.gd")
const Interface = preload("res://scripts/ui/interface.gd")
const Pickup = preload("res://scripts/interaction/pickup.gd")
const Soundscape = preload("res://scripts/audio/soundscape.gd")
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
	ecology.hint.connect(func(message): notify(message))
	if ecology.has_signal("observed_event"):
		ecology.observed_event.connect(_on_observed_event)
	sound = Soundscape.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	sound.apply_settings(settings)
	_build_pickups()
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
	_check_guidance()
	if state.oxygen <= state.capacity() * 0.35 and not state.warned_35:
		state.warned_35 = true
		notify("酸素 35% — ポッドまでの道を確認してください。水面では消費が止まります。", 7)
		sound.play_effect("warning")
	if state.oxygen <= state.capacity() * 0.15 and not state.warned_15:
		state.warned_15 = true
		notify("酸素 15% — 帰投または浮上を。水面ではタンクは充填されません。", 7)
		sound.play_effect("warning")
	if state.oxygen <= 0 and not player.breathing_air:
		hud.observation_label.text = "酸素切れ — 浮上してください！ 残り %.1f 秒" % maxf(0, 8 - state.anoxia)
	if shake_time > 0:
		shake_time = maxf(0, shake_time - delta)
		player.camera.h_offset = sin(shake_time * 56) * shake_time * 0.045 * player.camera_shake
	else:
		player.camera.h_offset = 0

func start_new_game() -> void:
	state = Expedition.new()
	observations = {}
	tutorial_flags = {}
	saves.write_json("observations", {})
	state.deposit()
	_save_checkpoint()
	_begin_at_pod()
	notify("転移事故で調査艇を喪失。まず浅瀬の金属片 2 個と、艇の航法ユニットを回収してください。", 13)

func _begin_at_pod() -> void:
	mode = "play"
	player.relocate(POD, true)
	ecology.reset()
	for pickup in pickups:
		pickup.set_available(pickup.kind != "nav" or state.nav == "wreck")
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
	notify("ポッドの保存点から再開しました。補給・修復は完了しています。")
	return true

func _save_checkpoint() -> bool:
	var data: Dictionary = state.checkpoint()
	if saves.write_json("checkpoint", data):
		checkpoint = data.duplicate(true)
		return true
	notify(saves.last_error, 12)
	return false

func depart_pod() -> bool:
	if not player.in_pod or mode != "play":
		return false
	state.deposit()
	if not _save_checkpoint():
		return false
	player.relocate(EXIT, false)
	resume_game()
	sound.ambience(false, true)
	notify("%s　%s\n%sで観察器を選び、左クリックを押し続けて拡大観察。" % ["WASD 泳ぐ / Space 上昇 / C 下降", "ポッドの光が帰路の目印です。", Controls.label("tool_1")], 11)
	return true

func return_to_pod() -> bool:
	if mode != "play" or player.in_pod or player.global_position.distance_to(ENTRY) > 7.0:
		return false
	# Deposit, objective transition and checkpoint form one transaction.
	state.deposit()
	player.relocate(POD, true)
	_save_checkpoint()
	nav_unit.set_available(state.nav == "wreck")
	sound.ambience(true, true)
	sound.play_effect("pickup")
	notify("帰投完了。資材を保管し、酸素・スーツ・道具を補給しました。", 8)
	return true

func repair_navigation() -> bool:
	if mode != "play" or not player.in_pod or not state.repair():
		notify("航法ユニット 1 個と、保管済みの金属片 2 個が必要です。")
		return false
	_save_checkpoint()
	sound.play_effect("success")
	pause_game("complete")
	return true

func die(reason: String) -> void:
	if mode != "play":
		return
	mode = "dead"
	death_reason = reason
	state.dead = true
	_stop_play()
	sound.ambience(false, false)
	hud.show_panel("dead", "救難信号を受信", reason + "\n持ち帰っていない資材は失われます。未保管の航法ユニットは艇へ戻ります。\n観察記録は保持されます。", [["最後のポッド保存点から再出発", "retry"], ["タイトルへ", "title"]])

func show_title(message := "") -> void:
	mode = "title"
	_stop_play()
	sound.ambience(true, false)
	player.relocate(POD, true)
	var intro := "五億年前に似た、もうひとつの海。\n生き物の暮らしを読み、失われた航法装置を持ち帰る。\n\n航法復旧編 — 一人称の海洋探索サバイバル"
	if not message.is_empty():
		intro += "\n\n" + message
	hud.show_panel("title", "原初の海", intro, [["新しく始める", "new"], ["続きから（ポッドの保存点）", "continue", not saves.exists()], ["設定", "settings"], ["終了", "quit"]])

func _stop_play() -> void:
	player.active = false
	player.clear_input()
	observation_target = null
	observe_time = 0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func pause_game(page := "pause") -> void:
	if mode != "play":
		return
	_stop_play()
	if page == "journal":
		_show_journal()
	elif page == "pod":
		_show_pod()
	elif page == "complete":
		hud.show_panel("complete", "航法復旧編 完了", "艇の記録が戻り、この海の座標が分かりました。\n帰還には装置の安定化と帰還コアが必要です。その探索は次の物語へ。\n\nこの開発版の目標を達成しました。引き続き海の生態を調査できます。", [["観察を続ける", "resume"], ["調査記録を見る", "journal"], ["タイトルへ", "title"]])
	else:
		hud.show_panel("pause", "潜水を一時停止", "酸素・生物・道具の時間は停止しています。\n水中で終了した場合は最後のポッド保存点から再開します。\n\n" + Controls.help_text(), [["潜水を再開", "resume"], ["図鑑・持ち物", "journal"], ["設定", "settings"], ["タイトルへ（最後の保存点を保持）", "title"]])

func resume_game() -> void:
	if mode != "play":
		return
	player.clear_input()
	use_lock = 0.25
	hud.hide_panel()
	get_tree().paused = false
	player.active = true
	if not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_pod() -> void:
	var status := "復旧済み" if state.nav == "repaired" else "未復旧"
	var text := "帰還装置   ① 航法 %s   ② 安定化 未復旧   ③ 帰還コア 未回収\n\n" % status
	text += "航法修理：航法ユニット %d / 1　金属片 %d / 2（保管済み）\n" % [1 if state.nav in ["stored", "repaired"] else 0, state.stored_metal]
	text += "補給食・酸素・スーツ整備済み。基本道具は再充填できます。\n"
	text += "浅瀬に金属片と微生物膜。艇の信号は回廊の奥、深度 36 m。\n直進する回廊と、東の欠け岩を回る道があります。"
	hud.show_panel("pod", "救命ポッド / 整備端末", text, [["海へ出発（保管して保存）", "depart"], ["航法装置を修理", "repair", state.nav != "stored" or state.stored_metal < 2], ["タンク改良 480 → 600 秒 / 金属片 2（航法用 2 個は残す）", "upgrade", state.tank_upgraded or state.stored_metal < (2 if state.nav == "repaired" else 4)], ["図鑑・持ち物", "journal"], ["端末を閉じる", "resume"]])

func _show_journal() -> void:
	var text := "%s / %s で閉じる　・　ホイールで記録をスクロール\n\n" % [Controls.label("journal"), Controls.label("pause")]
	text += "携行 金属片 %d　｜　保管 金属片 %d　｜　誘餌 %d　｜　パルス %d\n航法ユニット：%s\n\n" % [state.carried_metal, state.stored_metal, state.bait, state.pulse, {"wreck":"未回収", "carried":"携行中・未保存", "stored":"保管済み", "repaired":"装置へ組込済み"}[state.nav]]
	var catalog: Dictionary = ecology.get_species_data()
	if observations.is_empty():
		text += "観察記録はまだありません。観察器を生物に向け、左クリックで約 2 秒拡大します。\n形を記録したあとも観察すると、実際に見た行動を追記します。\n"
	for species in catalog:
		if not observations.has(species):
			continue
		var data: Dictionary = catalog[species]
		text += "── %s ──\n%s / %s\n%s\n" % [data.get("name", species), data.get("origin", ""), data.get("habitat", ""), data.get("description", "")]
		var events: Dictionary = data.get("events", {})
		for event in observations[species]:
			if events.has(event):
				text += "・" + str(events[event]) + "\n"
		text += "まだ観察していない行動は未確認。\n\n"
	text += "形態は古生物を参考にしていますが、生態と配色は創作です。\n観察記録は随時保存。携行品はポッドへ帰るまで保存されません。\n\n" + Controls.help_text()
	hud.show_panel("journal", "観察記録 / 持ち物", text, [["閉じる（Tab）", "resume"]])

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
		"resume": resume_game()
		"title": show_title()
		"depart": depart_pod()
		"repair": repair_navigation()
		"upgrade":
			if state.upgrade_tank():
				_save_checkpoint()
			_show_pod()
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

func notify(message: String, seconds := 5.0) -> void:
	toast_text = message
	toast_remaining = seconds

func current_target():
	var best = null
	var best_distance := 4.0
	for pickup in pickups:
		if not pickup.available:
			continue
		var distance: float = player.global_position.distance_to(pickup.global_position)
		if distance < best_distance and visible_to_player(pickup.global_position, 0.80):
			best = pickup
			best_distance = distance
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
	var target = current_target()
	if target:
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
	if return_to_pod():
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
	if player.global_position.distance_to(target.global_position) > 4 or not visible_to_player(target.global_position, 0.75):
		return false
	match target.kind:
		"nav":
			if not state.collect_nav(): return false
			notify("航法ユニットを回収。ポッドへ持ち帰って保管してください。", 8)
		"metal":
			if state.carried_metal >= 12:
				notify("一般素材の携行枠がいっぱいです。ポッドへ保管しましょう。")
				return false
			state.carried_metal += 1
			notify("金属片を回収（携行 %d）。ポッドに戻ると保管されます。" % state.carried_metal)
		"bait":
			if state.bait >= 6:
				notify("誘餌は最大 6 個です。")
				return false
			state.bait = mini(6, state.bait + 2)
			notify("微生物膜から誘餌を補充しました。")
	target.take()
	sound.play_effect("pickup")
	return true

func select_tool(index: int) -> void:
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
			if not target or not collect_target(target):
				notify("採集できる素材に近づき、照準を合わせてください。")
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
			elif state.buoys.size() >= 3:
				notify("目印は 3 個まで。近づいて E で回収できます。")
			else:
				var at: Vector3 = player.position
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
	player.zoom_fov = 38.0 if id in ["hogara", "windoweater"] else 12.0
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
	notify("スーツ損傷。横へ泳いで遮蔽物へ！ Q の緊急パルスも使えます。", 5)
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
	if player.in_pod:
		return
	var z: float = player.position.z
	if z < -15 and not tutorial_flags.has("shallow"):
		tutorial_flags.shallow = true
		notify("浅瀬の発見：白い底の金属片は E で回収。小さな生物は観察器で拡大できます。", 10)
	elif z < -53 and not tutorial_flags.has("hogara"):
		tutorial_flags.hogara = true
		notify("大きな帆の影が動いています。距離を保ち、腹側へ集まる小生物を観察しましょう。", 9)
	elif z < -69 and not tutorial_flags.has("silt"):
		tutorial_flags.silt = true
		notify("砂底の螺旋状の生物は、大きな動きに反応します。3 m 以内で Shift 加速を試せます。", 10)
	elif z < -86 and not tutorial_flags.has("routes"):
		tutorial_flags.routes = true
		notify("艇の信号は奥へ。東側の岩陰にも回り道があります。ライトは F、緊急パルスは Q。", 10)
	if absf(player.position.x) > 105 or player.position.z < -166 or player.position.z > 30:
		if toast_remaining <= 0:
			notify("外洋から強い流れ。岩の盆地へ戻りましょう。", 4)
