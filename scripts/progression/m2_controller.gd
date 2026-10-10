extends RefCounted
## M2 interaction and presentation. Durable state belongs to Expedition/SaveStore.
const Map = preload("res://data/biomes/world_map.gd")
const Items = preload("res://data/items/item_catalog.gd")
const Upgrades = preload("res://data/upgrades/upgrade_catalog.gd")
const Pickup = preload("res://scripts/interaction/pickup.gd")
const STATUS := {"world": "未回収", "carried": "携行中・未保存", "stored": "ポッド保管済み", "installed": "組込済み"}
var game
var drop_sources: Dictionary = {}
var journal_species := "opabinia"

func setup(owner_game) -> void:
	game = owner_game
	for id in Items.PART_IDS:
		add_pickup(id, Map.point(id, game.world), "part:" + id)
	add_pickup("metal", Map.point("mineral_cache", game.world), "graveyard:mineral")

func add_pickup(kind: String, at: Vector3, source_id: String) -> Node3D:
	var pickup := Pickup.new()
	pickup.kind = kind
	pickup.title = Items.item_name(kind)
	pickup.source_id = source_id
	pickup.renewable = false
	pickup.position = at
	game.add_child(pickup)
	game.pickups.append(pickup)
	return pickup

func drop_resource(kind: String, at: Vector3, source_id: String) -> void:
	if not kind in Items.RESOURCE_IDS or drop_sources.has(source_id):
		return
	drop_sources[source_id] = true
	add_pickup(kind, at, "ecology:" + source_id)

func reset_expedition() -> void:
	for i in range(game.pickups.size() - 1, -1, -1):
		var pickup = game.pickups[i]
		if pickup.source_id.begins_with("ecology:"):
			game.pickups.remove_at(i)
			pickup.queue_free()
		else:
			pickup.being_carried = false
			pickup.position = pickup.home
			pickup.set_available(true)
	drop_sources.clear()
	sync_parts()

func sync_parts() -> void:
	game.nav_unit.set_available(game.state.nav == "wreck")
	for pickup in game.pickups:
		if Items.PARTS.has(pickup.kind):
			pickup.set_available(game.state.parts[pickup.kind] == "world")

func relay_position() -> Vector3:
	return Map.point("relay", game.world)

func target_part() -> String:
	var selected: String = game.state.tracked_part
	if game.state.parts.get(selected) == "world":
		return selected
	if "carried" in game.state.parts.values():
		return ""
	for id in Items.PART_IDS:
		if game.state.parts[id] == "world":
			return id
	return ""

func near_relay() -> bool:
	return not game.player.in_pod and game.player.global_position.distance_to(relay_position()) <= 4.0 and game.visible_to_player(relay_position(), 0.6)

func open_relay() -> bool:
	if game.mode != "play" or game.state.dead or not near_relay():
		return false
	game._stop_play()
	var unlocked: bool = game.state.nav == "repaired" and game.checkpoint.get("nav") == "repaired"
	var text := "海底の固定補給ステーション。\n酸素とスーツを補給します。携行品は保管されません。\n誘餌・パルスの補充は救命ポッドで行ってください。\n再開地点は最後に保存した救命ポッドです。"
	if not unlocked:
		text += "\n\n航法装置を修理し、ポッドへの登録を完了すると利用できます。"
	game.hud.show_panel("relay", "中継補給点", text, [["酸素とスーツを補給", "relay_refill", not unlocked], ["海へ戻る", "resume"]])
	return true

func refill_at_relay() -> bool:
	if game.mode != "play" or game.state.dead or not near_relay() or game.state.nav != "repaired" or game.checkpoint.get("nav") != "repaired":
		return false
	if not game.state.relay_refill():
		return false
	game.resume_game()
	game.sound.play_effect("pickup")
	game.notify("酸素・スーツを補給しました。携行中の部品と資材は、ポッドへの帰投で保管されます。", 8)
	return true

func inventory_text() -> String:
	var text := ""
	for id in Items.RESOURCE_IDS:
		text += "%s  携行 %d / %d・保管 %d　" % [Items.item_name(id), game.state.carried_amount(id), Items.RESOURCES[id].carried_limit, game.state.stored_amount(id)]
	text += "\n誘餌 %d / 6　パルス %d / 1　ブイ %d / 6\n" % [game.state.bait, game.state.pulse, game.state.buoys.size()]
	for id in Items.PART_IDS:
		text += "%s：%s\n" % [Items.item_name(id), STATUS[game.state.parts[id]]]
	return text

func tracking_buttons() -> Array:
	var buttons: Array = []
	if game.state.nav == "repaired" and not game.state.stabilized:
		for id in Items.PART_IDS:
			buttons.append([("追跡中：" if game.state.tracked_part == id else "追跡する：") + Items.item_name(id) + " / " + STATUS[game.state.parts[id]], "track:" + id])
	return buttons

func show_pod() -> void:
	var state = game.state
	var stability: Dictionary = state.stabilization_status()
	var text := "帰還装置　①航法 %s　②安定化 %s　③帰還コア 未実装（M3）\n" % ["復旧済み" if state.nav == "repaired" else "未復旧", "完了" if state.stabilized else "未復旧"]
	text += inventory_text()
	text += "\n航法修理：航法ユニット 1・保管金属片 2。\n装置安定化：航法復旧後、制振フレームと位相調整器をポッドへ保管。追加素材は不要。\n"
	text += ("安定化部品 組込済み 2 / 2\n" if state.stabilized else "安定化部品の保管 %d / %d　%s\n" % [stability.stored_count, stability.required_count, "組み込み可能" if stability.allowed else stability.reason])
	text += "中継点は白濁の平原の奥。補給してから殻の墓場へ進めます。改良は任意です。\n"
	var buttons: Array = [["海へ出発（保管して保存）", "depart"], ["航法装置を修理", "repair", state.nav != "stored" or state.stored_metal < 2], ["装置を安定化", "stabilize", not stability.allowed]]
	for id in Upgrades.RECIPES:
		var info: Dictionary = state.upgrade_status(id)
		var costs: Array[String] = []
		for resource in info.costs:
			costs.append("%s %d" % [Items.item_name(resource), info.costs[resource]])
		text += "%s：%s / %s\n" % [info.name, info.effect, "利用可" if info.allowed else info.reason]
		buttons.append([info.name + " / " + "・".join(costs), "equipment:" + id, not info.allowed])
	buttons.append_array(tracking_buttons())
	buttons.append_array([["図鑑・持ち物", "journal"], ["端末を閉じる", "resume"]])
	game.hud.show_panel("pod", "救命ポッド / 整備端末", text, buttons)

func show_journal() -> void:
	var catalog: Dictionary = game.ecology.get_species_data()
	var text := "Tab / Esc で閉じる。ホイールで全14種の一覧をスクロール。\n" + inventory_text()
	text += "航法ユニット：" + {"wreck": "未回収", "carried": "携行中・未保存", "stored": "保管済み", "repaired": "組込済み"}[game.state.nav] + "\n\n"
	var data: Dictionary = catalog.get(journal_species, {})
	var known: Array = game.observations.get(journal_species, [])
	text += "── %s ──\n" % data.get("name", journal_species)
	if not "identified" in known:
		text += "未観察。海で見つけて、観察器の左クリックを約2秒間押し続けてください。\n"
	else:
		text += "%s / %s / %s\n%s\n" % [data.get("origin", ""), data.get("habitat", ""), str(data.get("size", "")), data.get("description", "")]
		for event in data.get("events", {}):
			text += ("確認済：" + str(data.events[event]) if event in known else "未確認の行動") + "\n"
	text += "\n行動記録は近くで実際に見た場合だけ追記されます。携行品は帰投するまで保存されません。\n"
	var buttons := tracking_buttons()
	buttons.append(["閉じる（Tab）", "resume"])
	for id in catalog:
		var events: Array = game.observations.get(id, [])
		var status := "未観察" if not "identified" in events else ("行動確認済み" if events.size() > 1 else "識別済み")
		buttons.append(["%s  /  %s" % [catalog[id].name, status], "species:" + id])
	game.hud.show_panel("journal", "観察記録 / 14種", text, buttons)
