extends RefCounted

const Items = preload("res://data/items/item_catalog.gd")
const Upgrades = preload("res://data/upgrades/upgrade_catalog.gd")
const BASE_OXYGEN := 480.0
const ANOXIA_GRACE := 8.0
const REPAIR_METAL := 2
const CARRIED_METAL_LIMIT := Items.RESOURCES["metal"]["carried_limit"]
const MAX_STORED := Items.MAX_STORED
const MAX_STORED_METAL := MAX_STORED
const MAX_BUOYS := Items.MAX_BUOYS
const PART_IDS := Items.PART_IDS
const RUNTIME_FIELDS := ["oxygen", "suit", "anoxia", "invulnerability", "carried_metal", "stored_metal", "carried_fiber", "stored_fiber", "carried_shell", "stored_shell", "bait", "pulse", "tank_level", "cutter_upgraded", "nav", "dead", "warned_35", "warned_15", "stabilized", "tracked_part"]
var oxygen := BASE_OXYGEN
var suit := 100.0
var anoxia := 0.0
var invulnerability := 0.0
var carried_metal := 0
var stored_metal := 0
var carried_fiber := 0
var stored_fiber := 0
var carried_shell := 0
var stored_shell := 0
var bait := 3
var pulse := 1
var tank_level := 0
# M1 compatibility is a view of the actual tank stage, never a second authority.
var tank_upgraded: bool:
	get: return tank_level > 0
	set(value): tank_level = maxi(1, tank_level) if value else 0
var cutter_upgraded := false
var nav := "wreck"
var dead := false
var parts: Dictionary = {"damping_frame": "world", "phase_regulator": "world"}
var stabilized := false
var tracked_part := "damping_frame"
var buoys: Array = []
var warned_35 := false
var warned_15 := false

func capacity() -> float:
	return Upgrades.TANK_CAPACITIES[clampi(tank_level, 0, 2)]

func cutter_seconds() -> float:
	return Upgrades.CUTTER_SECONDS[1 if cutter_upgraded else 0]

func tick(delta: float, underwater: bool, sprinting: bool) -> String:
	if dead:
		return ""
	invulnerability = maxf(0, invulnerability - delta)
	if underwater:
		var rate := 1.25 if sprinting else 1.0
		var supplied_seconds := minf(delta, oxygen / rate)
		oxygen = maxf(0, oxygen - delta * rate)
		if oxygen <= 0:
			anoxia += delta - supplied_seconds
			if anoxia >= ANOXIA_GRACE:
				dead = true
				return "酸素が尽きました。水面で外気呼吸するか、早めにポッドへ帰りましょう。"
	else:
		anoxia = 0
	return ""

func damage(amount: float) -> bool:
	if dead or invulnerability > 0:
		return false
	suit = maxf(0, suit - amount)
	invulnerability = 2.0
	dead = suit <= 0
	return true

func relay_refill() -> bool:
	# Relay is not respawn, storage or a checkpoint. Consumables and cargo stay.
	if dead:
		return false
	oxygen = capacity()
	suit = 100
	anoxia = 0
	warned_35 = false
	warned_15 = false
	return true

func refill() -> void:
	# Existing pod/restore API includes restarting an expedition and basic tools.
	dead = false
	relay_refill()
	invulnerability = 0
	pulse = 1
	bait = maxi(bait, 3)

func collect_nav() -> bool:
	if nav != "wreck" or dead:
		return false
	nav = "carried"
	return true

func collect_part(id: String) -> bool:
	if dead or not Items.PARTS.has(id) or parts.get(id) != "world":
		return false
	parts[id] = "carried"
	return true

func carried_amount(id: String) -> int:
	return int(get(Items.RESOURCES[id].carried_field)) if Items.RESOURCES.has(id) else 0

func stored_amount(id: String) -> int:
	return int(get(Items.RESOURCES[id].stored_field)) if Items.RESOURCES.has(id) else 0

func can_collect_resource(id: String, amount: int = 1) -> bool:
	if dead or not Items.RESOURCES.has(id) or amount <= 0:
		return false
	return carried_amount(id) + amount <= Items.RESOURCES[id].carried_limit and stored_amount(id) + carried_amount(id) + amount <= MAX_STORED

func collect_resource(id: String, amount: int = 1) -> bool:
	if not can_collect_resource(id, amount):
		return false
	set(Items.RESOURCES[id].carried_field, carried_amount(id) + amount)
	return true

func anoxia_remaining() -> float:
	return maxf(0.0, ANOXIA_GRACE - anoxia)

static func valid_metal_amount(value: Variant) -> bool:
	return Items.valid_amount(value)

func deposit() -> bool:
	if dead:
		return false
	# Validate everything first. Even defensive overflow never partially banks
	# one material or important item while silently losing another.
	for id in Items.RESOURCE_IDS:
		if not Items.valid_amount(stored_amount(id)) or carried_amount(id) < 0 or not Items.valid_amount(stored_amount(id) + carried_amount(id)):
			return false
	for id in Items.RESOURCE_IDS:
		set(Items.RESOURCES[id].stored_field, stored_amount(id) + carried_amount(id))
		set(Items.RESOURCES[id].carried_field, 0)
	if nav == "carried":
		nav = "stored"
	for id in PART_IDS:
		if parts[id] == "carried":
			parts[id] = "stored"
	refill()
	return true

func repair() -> bool:
	if dead or nav != "stored" or stored_metal < REPAIR_METAL:
		return false
	stored_metal -= REPAIR_METAL
	nav = "repaired"
	return true

func upgrade_status(id: String) -> Dictionary:
	if not Upgrades.RECIPES.has(id):
		return {"allowed": false, "reason": "この改良はありません。", "costs": {}, "owned": false}
	var recipe: Dictionary = Upgrades.RECIPES[id]
	var owned := cutter_upgraded if id == "cutter" else tank_level >= int(recipe.tank_result)
	var reason := ""
	if dead:
		reason = "再出発後にポッドで整備してください。"
	elif owned:
		reason = "改良済みです。"
	elif recipe.nav_required and nav != "repaired":
		reason = "航法機能の復旧が必要です。"
	elif tank_level < int(recipe.tank_required):
		reason = "先にタンクIを改良してください。"
	else:
		for resource_id in recipe.costs:
			var required: int = recipe.costs[resource_id]
			if id == "tank_i" and resource_id == "metal" and nav != "repaired":
				required += REPAIR_METAL
			if stored_amount(resource_id) < required:
				reason = "保管済みの%sが不足しています。" % Items.item_name(resource_id)
				if id == "tank_i" and nav != "repaired":
					reason += "航法修理用の金属片2個は残します。"
				break
	return {"allowed": reason.is_empty(), "reason": reason, "costs": recipe.costs.duplicate(), "owned": owned, "name": recipe.name, "effect": recipe.effect}

func can_upgrade(id: String) -> bool:
	return upgrade_status(id).allowed

func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var recipe: Dictionary = Upgrades.RECIPES[id]
	for resource_id in recipe.costs:
		set(Items.RESOURCES[resource_id].stored_field, stored_amount(resource_id) - int(recipe.costs[resource_id]))
	if id == "cutter":
		cutter_upgraded = true
	else:
		tank_level = recipe.tank_result
	refill()
	return true

func upgrade_tank() -> bool:
	return upgrade("tank_i")

func stabilization_status() -> Dictionary:
	var missing: Array[String] = []
	var held := 0
	for id in PART_IDS:
		if parts[id] == "stored" or (stabilized and parts[id] == "installed"):
			held += 1
		else:
			missing.append(Items.item_name(id))
	var reason := ""
	if dead:
		reason = "再出発後にポッドで整備してください。"
	elif stabilized:
		reason = "装置安定化は完了しています。"
	elif nav != "repaired":
		reason = "航法機能の復旧が必要です。"
	elif not missing.is_empty():
		reason = "救命ポッドへの保管が必要です：" + "・".join(missing)
	return {"allowed": reason.is_empty(), "reason": reason, "stored_count": held, "required_count": PART_IDS.size(), "missing": missing, "parts": parts.duplicate()}

func can_stabilize() -> bool:
	return stabilization_status().allowed

func stabilize() -> bool:
	if not can_stabilize():
		return false
	for id in PART_IDS:
		parts[id] = "installed"
	stabilized = true
	return true

func clone_runtime():
	# A checkpoint intentionally drops unbanked cargo; transaction candidates must
	# instead preserve every live field and own their mutable collections.
	var copy = get_script().new()
	for field in RUNTIME_FIELDS:
		copy.set(field, get(field))
	copy.parts = parts.duplicate(true)
	copy.buoys = buoys.duplicate(true)
	return copy

func checkpoint() -> Dictionary:
	var banked_parts := parts.duplicate(true)
	for id in PART_IDS:
		if banked_parts[id] == "carried":
			banked_parts[id] = "world"
	return {"schema_version": 2, "nav": nav if nav != "carried" else "wreck", "parts": banked_parts, "stabilized": stabilized, "stored_metal": stored_metal, "stored_fiber": stored_fiber, "stored_shell": stored_shell, "tank_level": tank_level, "cutter_upgraded": cutter_upgraded, "tracked_part": tracked_part, "buoys": buoys.duplicate(true)}

func restore(data: Dictionary) -> void:
	nav = data.get("nav", "wreck")
	stored_metal = data.get("stored_metal", 0)
	stored_fiber = data.get("stored_fiber", 0)
	stored_shell = data.get("stored_shell", 0)
	tank_level = data.get("tank_level", 1 if data.get("tank_upgraded", false) else 0)
	cutter_upgraded = data.get("cutter_upgraded", false)
	parts = data.get("parts", {"damping_frame": "world", "phase_regulator": "world"}).duplicate(true)
	stabilized = data.get("stabilized", false)
	tracked_part = data.get("tracked_part", "damping_frame")
	buoys = data.get("buoys", []).duplicate(true)
	carried_metal = 0
	carried_fiber = 0
	carried_shell = 0
	bait = 3
	refill()

func objective() -> String:
	if nav != "repaired":
		if nav == "carried":
			return "航法ユニットをポッドへ持ち帰る"
		if stored_metal + carried_metal < REPAIR_METAL:
			return "浅瀬で修理用の金属片を集める（%d / %d）" % [stored_metal + carried_metal, REPAIR_METAL]
		if nav == "stored":
			return "ポッドの端末で航法装置を修理する"
		return "艇の残骸から航法ユニットを回収する"
	if stabilized:
		return "装置安定化編 完了 — 海の観察を続ける"
	if can_stabilize():
		return "ポッドの端末で装置を安定化する"
	var selected: String = tracked_part if Items.PARTS.has(tracked_part) else "damping_frame"
	if parts[selected] == "world":
		return "%sで%sを探す" % [Items.PARTS[selected].biome, Items.item_name(selected)]
	if "carried" in parts.values():
		return "回収した部品を救命ポッドへ持ち帰る"
	for id in PART_IDS:
		if parts[id] == "world":
			return "%sで%sを探す" % [Items.PARTS[id].biome, Items.item_name(id)]
	return "回収した部品を救命ポッドへ持ち帰る"
