extends RefCounted

const BASE_OXYGEN := 480.0
const ANOXIA_GRACE := 8.0
const REPAIR_METAL := 2
const CARRIED_METAL_LIMIT := 12
# One shared range for collection, deposit, checkpoint writes and old/new reads.
const MAX_STORED_METAL := 1000000
var oxygen := BASE_OXYGEN
var suit := 100.0
var anoxia := 0.0
var invulnerability := 0.0
var carried_metal := 0
var stored_metal := 0
var bait := 3
var pulse := 1
var tank_upgraded := false
var nav := "wreck"
var dead := false
var buoys: Array = []
var warned_35 := false
var warned_15 := false

func capacity() -> float:
	return 600.0 if tank_upgraded else BASE_OXYGEN

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

func refill() -> void:
	oxygen = capacity()
	suit = 100
	anoxia = 0
	invulnerability = 0
	dead = false
	pulse = 1
	bait = maxi(bait, 3)
	warned_35 = false
	warned_15 = false

func collect_nav() -> bool:
	if nav != "wreck" or dead:
		return false
	nav = "carried"
	return true

func anoxia_remaining() -> float:
	return maxf(0.0, ANOXIA_GRACE - anoxia)

static func valid_metal_amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= MAX_STORED_METAL and floor(value) == value

func deposit() -> bool:
	# The collection limit prevents this in ordinary play. A defensive rejection
	# keeps every carried item intact instead of silently clamping away overflow.
	if not valid_metal_amount(stored_metal) or carried_metal < 0 or not valid_metal_amount(stored_metal + carried_metal):
		return false
	stored_metal += carried_metal
	carried_metal = 0
	if nav == "carried":
		nav = "stored"
	refill()
	return true

func repair() -> bool:
	if nav != "stored" or stored_metal < REPAIR_METAL:
		return false
	stored_metal -= REPAIR_METAL
	nav = "repaired"
	return true

func upgrade_tank() -> bool:
	# Reserve the required metal for navigation until it has been repaired.
	var reserve := 0 if nav == "repaired" else REPAIR_METAL
	if tank_upgraded or stored_metal < 2 + reserve:
		return false
	stored_metal -= 2
	tank_upgraded = true
	refill()
	return true

func checkpoint() -> Dictionary:
	return {"schema_version": 1, "nav": nav if nav != "carried" else "wreck", "stored_metal": stored_metal, "tank_upgraded": tank_upgraded, "buoys": buoys.duplicate(true)}

func restore(data: Dictionary) -> void:
	nav = data.get("nav", "wreck")
	stored_metal = data.get("stored_metal", 0)
	tank_upgraded = data.get("tank_upgraded", false)
	buoys = data.get("buoys", []).duplicate(true)
	carried_metal = 0
	refill()

func objective() -> String:
	if nav == "repaired":
		return "航法復旧編 完了 — 海の観察を続ける"
	if nav == "carried":
		return "航法ユニットをポッドへ持ち帰る"
	if stored_metal + carried_metal < REPAIR_METAL:
		return "浅瀬で修理用の金属片を集める（%d / %d）" % [stored_metal + carried_metal, REPAIR_METAL]
	if nav == "stored":
		return "ポッドの端末で航法装置を修理する"
	return "艇の残骸から航法ユニットを回収する"
